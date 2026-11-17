#!/usr/bin/env sh
set -eu

repo_root="$(CDPATH= cd "$(dirname "$0")/.." && pwd)"
aiops="$repo_root/bin/aiops"
tmpdir="$(mktemp -d /tmp/aiops-e2e-core-guard.XXXXXX)"
trap 'chmod -R u+w "$tmpdir" 2>/dev/null || true; rm -rf "$tmpdir"' EXIT INT TERM

fail() {
  printf '%s\n' "$1" >&2
  exit 1
}

# --- pre-tool-use decisions (Claude Code and Codex payload shapes) ---
project="$tmpdir/project"
mkdir -p "$project/src" "$project/.ai_project"
ln -s "$repo_root" "$project/.ai"

expect() {
  expected="$1"
  label="$2"
  payload="$3"
  set +e
  printf '%s' "$payload" | (cd "$project" && "$aiops" guard pre-tool-use >/dev/null 2>"$tmpdir/guard.err")
  status=$?
  set -e
  [ "$status" -eq "$expected" ] || {
    cat "$tmpdir/guard.err" >&2
    fail "guard $label: expected exit $expected, got $status"
  }
}

bash_payload() {
  printf '{"tool_name":"Bash","cwd":"%s","tool_input":{"command":"%s"}}' "$project" "$1"
}

expect 2 "claude edit .ai" "{\"tool_name\":\"Edit\",\"cwd\":\"$project\",\"tool_input\":{\"file_path\":\"$project/.ai/core/constitution.md\"}}"
expect 2 "claude write core realpath" "{\"tool_name\":\"Write\",\"cwd\":\"$project\",\"tool_input\":{\"file_path\":\"$repo_root/core/constitution.md\"}}"
expect 0 "claude write src" "{\"tool_name\":\"Write\",\"cwd\":\"$project\",\"tool_input\":{\"file_path\":\"$project/src/app.js\"}}"
expect 0 "claude write .ai_project" "{\"tool_name\":\"Write\",\"cwd\":\"$project\",\"tool_input\":{\"file_path\":\".ai_project/tasks/T-1.md\"}}"
expect 2 "codex patch .ai" "{\"tool_name\":\"apply_patch\",\"cwd\":\"$project\",\"tool_input\":{\"command\":\"*** Begin Patch\\n*** Update File: .ai/README.md\\n@@\\n-a\\n+b\\n*** End Patch\"}}"
expect 2 "codex patch move into .ai" "{\"tool_name\":\"apply_patch\",\"cwd\":\"$project\",\"tool_input\":{\"command\":\"*** Begin Patch\\n*** Update File: src/a.js\\n*** Move to: .ai/a.js\\n*** End Patch\"}}"
expect 0 "codex patch src" "{\"tool_name\":\"apply_patch\",\"cwd\":\"$project\",\"tool_input\":{\"command\":\"*** Begin Patch\\n*** Add File: src/b.js\\n+x\\n*** End Patch\"}}"
expect 2 "rm .ai" "$(bash_payload 'rm -rf .ai')"
expect 2 "redirect into .ai" "$(bash_payload 'echo x > .ai/x.md')"
expect 2 "sed -i .ai" "$(bash_payload 'sed -i \"\" s/a/b/ .ai/README.md')"
expect 2 "cp into .ai" "$(bash_payload 'cp src/app.js .ai/app.js')"
expect 2 "git -C .ai commit" "$(bash_payload 'git -C .ai commit -am x')"
expect 2 "git checkout .ai path" "$(bash_payload 'git checkout -- .ai/README.md')"
expect 2 "interpreter on .ai" "$(bash_payload 'python3 -c \"open('.ai/x','w')\"')"
expect 2 "aiops update" "$(bash_payload 'aiops update')"
expect 2 "aiops seed --force" "$(bash_payload '.ai/bin/aiops seed --force --adapter both')"
expect 2 "override env" "$(bash_payload 'AIOPS_ALLOW_CORE_COMMIT=1 git commit -m x')"
expect 0 "read .ai" "$(bash_payload 'cat .ai/README.md | head -5')"
expect 0 "copy from .ai" "$(bash_payload 'cp .ai/templates/tasks/task.md .ai_project/task.md')"
expect 0 "aiops lifecycle" "$(bash_payload '.ai/bin/aiops task advance T-1 --check')"
expect 0 "aiops update check" "$(bash_payload 'aiops update --check')"
expect 0 "normal command" "$(bash_payload 'npm test && git status')"
expect 0 "no core" "{\"tool_name\":\"Write\",\"cwd\":\"$tmpdir\",\"tool_input\":{\"file_path\":\"$tmpdir/.ai/x\"}}"

grep -q 'AI Ops 차단' "$tmpdir/guard.err" 2>/dev/null || true

"$aiops" guard check-path --target "$project" .ai/README.md >/dev/null 2>&1 && fail "check-path allowed .ai/README.md"
"$aiops" guard check-path --target "$project" src/app.js >/dev/null || fail "check-path blocked src/app.js"

# --- copy mode: read-only core, digest, and integrity ---
copy="$tmpdir/copy"
mkdir -p "$copy"
git -C "$copy" init -q
"$aiops" seed --target "$copy" --adapter codex --mode copy --core "$repo_root" >/dev/null
[ -f "$copy/.ai/.aiops_core_digest" ] || fail "copy seed did not record core digest"
[ ! -w "$copy/.ai/README.md" ] || fail "copy seed left core files writable"
[ ! -e "$copy/.ai/DEVELOPMENT.md" ] || fail "copy seed copied contributor guide into .ai/"
"$aiops" guard verify-core --target "$copy" | grep -q 'core_integrity: ok' || fail "fresh copy core not ok"

chmod u+w "$copy/.ai/README.md"
printf 'tamper\n' >> "$copy/.ai/README.md"
if "$aiops" guard verify-core --target "$copy" >/dev/null; then
  fail "verify-core did not detect modified core"
fi
if "$aiops" doctor --target "$copy" > "$tmpdir/doctor.out" 2>&1; then
  fail "doctor passed with modified core"
fi
grep -q 'error: .ai core modified' "$tmpdir/doctor.out" || fail "doctor did not report modified core"

# Later doctor checks must not reset the core failure (POSIX sh shares the "failed" variable).
cp -R "$repo_root/templates/ai_project/fast_track" "$copy/.ai_project"
mkdir -p "$copy/.ai_project/tasks/active" "$copy/.ai_project/tasks/backlog" "$copy/.ai_project/tasks/archive" "$copy/.ai_project/handoffs"
if "$aiops" doctor --target "$copy" > "$tmpdir/doctor-project.out" 2>&1; then
  fail "doctor passed with modified core when .ai_project exists"
fi
rm -rf "$copy/.ai_project"

"$aiops" seed --target "$copy" --adapter codex --mode copy --core "$repo_root" --force >/dev/null
"$aiops" guard verify-core --target "$copy" | grep -q 'core_integrity: ok' || fail "reseed did not restore core integrity"

# --- git pre-commit guard ---
[ -x "$copy/.git/hooks/pre-commit" ] || fail "seed did not install pre-commit guard"
git -C "$copy" add -f .ai/README.md
if git -C "$copy" -c user.name=t -c user.email=t@example.com commit -qm core >/dev/null 2>"$tmpdir/commit.err"; then
  fail "pre-commit allowed staged .ai/ changes"
fi
grep -q 'AI Ops 차단' "$tmpdir/commit.err" || fail "pre-commit did not explain the block"
AIOPS_ALLOW_CORE_COMMIT=1 git -C "$copy" -c user.name=t -c user.email=t@example.com commit -qm core >/dev/null 2>&1 || fail "Owner override did not allow core commit"

printf 'app\n' > "$copy/app.txt"
git -C "$copy" add app.txt
git -C "$copy" -c user.name=t -c user.email=t@example.com commit -qm app >/dev/null || fail "pre-commit blocked a normal commit"

# Existing user pre-commit hooks are never replaced.
custom="$tmpdir/custom"
mkdir -p "$custom"
git -C "$custom" init -q
printf '#!/bin/sh\necho custom\n' > "$custom/.git/hooks/pre-commit"
chmod +x "$custom/.git/hooks/pre-commit"
"$aiops" seed --target "$custom" --adapter claude --core "$repo_root" > "$tmpdir/custom.out"
grep -q 'needs_user_decision: existing pre-commit hook' "$tmpdir/custom.out" || fail "seed did not report existing pre-commit hook"
grep -q 'echo custom' "$custom/.git/hooks/pre-commit" || fail "seed replaced an existing pre-commit hook"

printf '%s\n' "ok: core guard"

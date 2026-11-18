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

# --- Agent Registry (Operator Role holders), receipts, git hooks ---
mkdir -p "$project/.ai_project/reports" "$project/scripts"
git -C "$project" init -q
expect 0 "bootstrap creates registry" "{\"tool_name\":\"Write\",\"cwd\":\"$project\",\"tool_input\":{\"file_path\":\".ai_project/agent_registry.md\"}}"
cat > "$project/.ai_project/agent_registry.md" <<'MD'
---
agents:
  - agent: Lead
    status: enabled
    team: core
    roles: [Lead Role, Operator Role]
  - agent: Builder
    status: enabled
    team: core
    roles: [Execution Role]
---

# Agent Registry
MD
printf '# Operating Model\n' > "$project/.ai_project/operating_model.md"

# Builds a hook payload with Ruby so file contents are JSON-escaped.
tool_payload() {
  ruby -rjson -e 'puts JSON.generate("tool_name" => ARGV[0], "cwd" => ARGV[1], "tool_input" => JSON.parse(ARGV[2]))' -- "$1" "$project" "$2"
}
edit_payload() {
  ruby -rjson -e 'puts JSON.generate("tool_name" => "Edit", "cwd" => ARGV[0], "tool_input" => { "file_path" => ".ai_project/agent_registry.md", "old_string" => ARGV[1], "new_string" => ARGV[2] })' -- "$project" "$1" "$2"
}
patch_payload() {
  ruby -rjson -e 'puts JSON.generate("tool_name" => "apply_patch", "cwd" => ARGV[0], "tool_input" => { "command" => ARGV[1] })' -- "$project" "$1"
}
registry_text="$(cat "$project/.ai_project/agent_registry.md")"
new_agent='  - agent: Reviewer
    status: enabled
    team: qa
    roles: [Verification Role]
---'

expect 0 "edit registry adds agent" "$(edit_payload '---

# Agent Registry' "$new_agent

# Agent Registry")"
expect 0 "edit registry changes team" "$(edit_payload 'team: core
    roles: [Execution Role]' 'team: mobile
    roles: [Execution Role]')"
expect 2 "edit registry removes Operator Role" "$(edit_payload 'roles: [Lead Role, Operator Role]' 'roles: [Lead Role]')"
expect 2 "edit registry grants Operator Role" "$(edit_payload 'roles: [Execution Role]' 'roles: [Execution Role, Operator Role]')"
expect 2 "edit registry disables operator" "$(edit_payload 'agent: Lead
    status: enabled' 'agent: Lead
    status: disabled')"
expect 2 "edit registry renames operator" "$(edit_payload 'agent: Lead' 'agent: Boss')"
expect 2 "edit registry breaks yaml" "$(edit_payload 'roles: [Execution Role]' 'roles: [Execution Role')"
expect 2 "edit registry missing old string" "$(edit_payload 'no such text' 'x')"
expect 0 "write registry keeps operator" "$(tool_payload Write "$(ruby -rjson -e 'puts JSON.generate("file_path" => ".ai_project/agent_registry.md", "content" => ARGV[0].sub("team: core\n    roles: [Execution Role]", "team: web\n    roles: [Execution Role]"))' -- "$registry_text
")")"
expect 2 "write registry drops operator" "$(tool_payload Write "$(ruby -rjson -e 'puts JSON.generate("file_path" => ".ai_project/agent_registry.md", "content" => "---\nagents: []\n---\n")')")"
expect 2 "multiedit registry grants operator" "$(tool_payload MultiEdit '{"file_path":".ai_project/agent_registry.md","edits":[{"old_string":"team: core\n    roles: [Execution Role]","new_string":"team: x\n    roles: [Execution Role]"},{"old_string":"[Execution Role]","new_string":"[Execution Role, Operator Role]"}]}')"
expect 2 "case variant registry drops operator" "$(tool_payload Write '{"file_path":".ai_project/Agent_Registry.md","content":"---\nagents: []\n---\n"}')"
expect 2 "notebook edit registry" "$(tool_payload NotebookEdit '{"notebook_path":".ai_project/agent_registry.md"}')"
expect 0 "patch registry adds agent" "$(patch_payload '*** Begin Patch
*** Update File: .ai_project/agent_registry.md
@@
     roles: [Execution Role]
+  - agent: Reviewer
+    status: enabled
+    roles: [Verification Role]
 ---
*** End Patch')"
expect 2 "patch registry removes Operator Role" "$(patch_payload '*** Begin Patch
*** Update File: .ai_project/agent_registry.md
@@
-    roles: [Lead Role, Operator Role]
+    roles: [Lead Role]
*** End Patch')"
expect 2 "patch registry unmatched hunk" "$(patch_payload '*** Begin Patch
*** Update File: .ai_project/agent_registry.md
@@
-a
+b
*** End Patch')"
expect 2 "patch deletes registry" "$(patch_payload '*** Begin Patch
*** Delete File: .ai_project/agent_registry.md
*** End Patch')"
expect 2 "patch moves registry" "$(patch_payload '*** Begin Patch
*** Update File: .ai_project/agent_registry.md
*** Move to: .ai_project/old_registry.md
*** End Patch')"
expect 2 "patch moves file onto registry" "$(patch_payload '*** Begin Patch
*** Update File: src/a.md
*** Move to: .ai_project/agent_registry.md
*** End Patch')"
expect 0 "write operating model" "{\"tool_name\":\"Write\",\"cwd\":\"$project\",\"tool_input\":{\"file_path\":\".ai_project/operating_model.md\"}}"
expect 0 "shell edits operating model" "$(bash_payload 'echo x >> .ai_project/operating_model.md')"
expect 2 "sed registry" "$(bash_payload 'sed -i \"\" s/a/b/ .ai_project/agent_registry.md')"
expect 2 "redirect registry" "$(bash_payload 'echo x >> .ai_project/agent_registry.md')"
expect 2 "forge receipt" "$(bash_payload 'echo {} > .ai_project/reports/T-1_scoped_to_approved_1-transition-receipt.json')"
expect 2 "write git hook" "{\"tool_name\":\"Write\",\"cwd\":\"$project\",\"tool_input\":{\"file_path\":\".git/hooks/pre-commit\"}}"
expect 0 "write task file" "{\"tool_name\":\"Write\",\"cwd\":\"$project\",\"tool_input\":{\"file_path\":\".ai_project/tasks/active/T-2.md\"}}"
expect 0 "write task report" "$(bash_payload 'echo ok > .ai_project/reports/T-1_task-report.md')"
expect 0 "read registry" "$(bash_payload 'cat .ai_project/agent_registry.md')"
expect 2 "write git aiops state" "$(bash_payload 'echo 9999999999 > .git/aiops/structure_edit_until')"
expect 2 "write runtime unlock" "$(bash_payload 'echo 9999999999 > .ai_project/.runtime/structure_edit_until')"
expect 2 "agent unlocks structure" "$(bash_payload 'aiops guard allow-structure-edit --minutes 60')"

# The Owner can unlock Operator Role changes for a while, then lock them again.
"$aiops" guard allow-structure-edit --target "$project" --minutes 5 >/dev/null || fail "Owner unlock failed"
expect 0 "remove Operator Role while unlocked" "$(edit_payload 'roles: [Lead Role, Operator Role]' 'roles: [Lead Role]')"
expect 0 "sed registry while unlocked" "$(bash_payload 'sed -i \"\" s/a/b/ .ai_project/agent_registry.md')"
"$aiops" guard lock-structure --target "$project" >/dev/null || fail "lock-structure failed"
expect 2 "remove Operator Role after lock" "$(edit_payload 'roles: [Lead Role, Operator Role]' 'roles: [Lead Role]')"
printf '1\n' > "$project/.git/aiops/structure_edit_until"
expect 2 "expired unlock" "$(edit_payload 'roles: [Lead Role, Operator Role]' 'roles: [Lead Role]')"
rm -f "$project/.git/aiops/structure_edit_until"

# Outside git the unlock lives in .ai_project/.runtime/.
plain="$tmpdir/plain"
mkdir -p "$plain/.ai_project"
ln -s "$repo_root" "$plain/.ai"
cp "$project/.ai_project/agent_registry.md" "$plain/.ai_project/agent_registry.md"
plain_payload="$(ruby -rjson -e 'puts JSON.generate("tool_name" => "Edit", "cwd" => ARGV[0], "tool_input" => { "file_path" => ".ai_project/agent_registry.md", "old_string" => "roles: [Lead Role, Operator Role]", "new_string" => "roles: [Lead Role]" })' -- "$plain")"
plain_expect() {
  set +e
  printf '%s' "$plain_payload" | (cd "$plain" && "$aiops" guard pre-tool-use --target "$plain" >/dev/null 2>"$tmpdir/guard.err")
  status=$?
  set -e
  [ "$status" -eq "$1" ] || { cat "$tmpdir/guard.err" >&2; fail "guard $2: expected exit $1, got $status"; }
}
plain_expect 2 "non-git operator change locked"
"$aiops" guard allow-structure-edit --target "$plain" --minutes 5 >/dev/null || fail "non-git Owner unlock failed"
[ -f "$plain/.ai_project/.runtime/structure_edit_until" ] || fail "non-git unlock file missing"
plain_expect 0 "non-git operator change unlocked"
"$aiops" guard lock-structure --target "$plain" >/dev/null || fail "non-git lock failed"
plain_expect 2 "non-git operator change relocked"

# --- Owner-only commands ---
expect 2 "owner approval flag" "$(bash_payload '.ai/bin/aiops task advance T-1 --dispatched-by Lead --owner-approved')"
expect 2 "owner approval via sh -c" "$(bash_payload 'sh -c \"aiops task advance T-1 --owner-approved\"')"
expect 0 "grep owner flag" "$(bash_payload 'grep -rn -- --owner-approved .ai/templates')"
expect 2 "commit --no-verify" "$(bash_payload 'git commit --no-verify -m x')"
expect 2 "commit -n cluster" "$(bash_payload 'git commit -anm x')"
expect 2 "commit abbreviated no-verify" "$(bash_payload 'git commit --no-veri -m x')"
expect 0 "commit -m with n in message flag" "$(bash_payload 'git commit -m nope')"
expect 2 "git -c hooksPath" "$(bash_payload 'git -c core.hooksPath=/dev/null commit -m x')"
expect 2 "git config hooksPath" "$(bash_payload 'git config core.hooksPath /tmp/none')"
expect 2 "git config unset hooksPath" "$(bash_payload 'git config --unset core.hooksPath')"
expect 2 "env hooksPath" "$(bash_payload 'GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=core.hooksPath GIT_CONFIG_VALUE_0=/x git commit -m x')"
expect 0 "read hooksPath" "$(bash_payload 'git config --get core.hooksPath')"
expect 2 "agent rename apply" "$(bash_payload 'aiops agent rename dev --to Boss --apply')"
expect 0 "agent rename check" "$(bash_payload 'aiops agent rename dev --to Boss --check --json')"
expect 2 "re-sign core digest" "$(bash_payload 'aiops guard write-core-digest --core .ai')"

# --- shell bypass patterns ---
expect 2 "cd then rm" "$(bash_payload 'cd .ai && rm README.md')"
expect 2 "subshell cd then write" "$(bash_payload '(cd .ai; echo x > a.md)')"
expect 0 "cd elsewhere then rm" "$(bash_payload 'cd src && rm -f app.js')"
expect 2 "find -delete" "$(bash_payload 'find .ai -name x -delete')"
expect 2 "find -exec rm" "$(bash_payload 'find .ai/templates -type f -exec rm {} +')"
expect 0 "find read" "$(bash_payload 'find .ai -name README.md')"
expect 2 "rm -rf project root" "$(bash_payload 'rm -rf .')"
expect 2 "command substitution" "$(bash_payload 'echo $(rm -rf .ai/core)')"
expect 2 "backticks" "$(bash_payload 'echo `touch .ai/x`')"
expect 2 "tar extract into .ai" "$(bash_payload 'tar -xzf a.tgz -C .ai')"
expect 2 "unzip into .ai" "$(bash_payload 'unzip a.zip -d .ai/templates')"
expect 2 "eval" "$(bash_payload 'eval \"rm .ai/README.md\"')"
expect 0 "interpreter on .ai_project" "$(bash_payload 'python3 -c \"open(\\\".ai_project/tasks/x\\\",\\\"w\\\")\"')"
printf '#!/bin/sh\nrm -rf .ai/core\n' > "$project/scripts/evil.sh"
printf '#!/bin/sh\necho ok\n' > "$project/scripts/fine.sh"
printf 'import os\nos.remove(".ai/README.md")\n' > "$project/scripts/evil.py"
expect 2 "shell script file" "$(bash_payload 'sh scripts/evil.sh')"
expect 2 "direct script file" "$(bash_payload './scripts/evil.sh')"
expect 2 "python script file" "$(bash_payload 'python3 scripts/evil.py')"
expect 0 "harmless script" "$(bash_payload 'sh scripts/fine.sh')"

# --- fail closed on unreadable payloads ---
expect 2 "malformed payload" '{"tool_name": "Bash", '
expect 2 "empty payload" ''
expect 2 "non-object payload" '[1, 2]'

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

# A custom core.hooksPath (husky and similar, usually tracked) is never written into.
husky="$tmpdir/husky"
mkdir -p "$husky/.husky"
git -C "$husky" init -q
git -C "$husky" config core.hooksPath .husky
"$aiops" seed --target "$husky" --adapter codex --core "$repo_root" > "$tmpdir/husky.out"
grep -q 'needs_user_decision: core.hooksPath is set' "$tmpdir/husky.out" || fail "seed did not report core.hooksPath"
[ ! -e "$husky/.husky/pre-commit" ] || fail "seed wrote into the tracked core.hooksPath directory"
printf '#!/bin/sh\n"$(git rev-parse --show-toplevel)/.ai/bin/aiops" guard staged || exit 1\n' > "$husky/.husky/pre-commit"
"$aiops" guard install-git-hook --target "$husky" --check | grep -q 'ok: pre-commit guard present' || fail "guard line in core.hooksPath hook not recognized"

printf '%s\n' "ok: core guard"

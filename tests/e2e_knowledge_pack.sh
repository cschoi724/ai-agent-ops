#!/usr/bin/env sh
set -eu

repo_root="$(CDPATH= cd "$(dirname "$0")/.." && pwd)"
tmpdir="$(mktemp -d /tmp/aiops-e2e-knowledge-pack.XXXXXX)"
trap 'rm -rf "$tmpdir"' EXIT INT TERM

"$repo_root/bin/aiops" knowledge init --target "$tmpdir" --mode minimal >/tmp/aiops-e2e-knowledge-pack-init.out

[ -d "$tmpdir/.ai_knowledge/context_packs" ] || {
  printf '%s\n' "knowledge init did not create context_packs" >&2
  exit 1
}

"$repo_root/bin/aiops" knowledge pack ios_login \
  --target "$tmpdir" \
  --create \
  --task T-20260727-030 \
  --source .ai_project/source_of_truth.md \
  --purpose "iOS 로그인 작업에 필요한 최소 지식" \
  >/tmp/aiops-e2e-knowledge-pack-create.out

grep -q 'created: .ai_knowledge/context_packs/ios_login.md' /tmp/aiops-e2e-knowledge-pack-create.out || {
  printf '%s\n' "knowledge pack create did not report created file" >&2
  exit 1
}

grep -q 'T-20260727-030' "$tmpdir/.ai_knowledge/context_packs/ios_login.md" || {
  printf '%s\n' "knowledge pack did not include task id" >&2
  exit 1
}

"$repo_root/bin/aiops" knowledge pack ios_login --target "$tmpdir" >/tmp/aiops-e2e-knowledge-pack-show.out

grep -q 'Context Pack: ios_login' /tmp/aiops-e2e-knowledge-pack-show.out || {
  printf '%s\n' "knowledge pack show did not print pack content" >&2
  exit 1
}

"$repo_root/bin/aiops" knowledge status --target "$tmpdir" >/tmp/aiops-e2e-knowledge-pack-status.out
grep -q 'context_packs/ios_login.md' /tmp/aiops-e2e-knowledge-pack-status.out || {
  printf '%s\n' "knowledge status did not list context pack" >&2
  exit 1
}

"$repo_root/bin/aiops" knowledge lint --target "$tmpdir" >/tmp/aiops-e2e-knowledge-pack-lint.out
grep -q 'ok: .ai_knowledge/context_packs' /tmp/aiops-e2e-knowledge-pack-lint.out || {
  printf '%s\n' "knowledge lint did not report context_packs" >&2
  exit 1
}

if "$repo_root/bin/aiops" knowledge pack missing_topic --target "$tmpdir" >/tmp/aiops-e2e-knowledge-pack-missing.out 2>&1; then
  printf '%s\n' "missing knowledge pack should fail" >&2
  exit 1
fi

grep -q 'context pack not found: missing_topic; use --create' /tmp/aiops-e2e-knowledge-pack-missing.out || {
  printf '%s\n' "missing knowledge pack did not report create hint" >&2
  exit 1
}

printf '%s\n' "ok: knowledge pack"

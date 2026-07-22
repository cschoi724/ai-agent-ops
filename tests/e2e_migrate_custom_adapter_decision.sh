#!/usr/bin/env sh
set -eu

repo_root="$(CDPATH= cd "$(dirname "$0")/.." && pwd)"
tmpdir="$(mktemp -d /tmp/aiops-e2e-migrate-adapter.XXXXXX)"
trap 'rm -rf "$tmpdir"' EXIT INT TERM

current_version="$(cat "$repo_root/VERSION")"

ln -s "$repo_root" "$tmpdir/.ai"
cp -R "$repo_root/templates/ai_project/fast_track" "$tmpdir/.ai_project"
cp "$repo_root/templates/tool_adapters/codex/AGENTS.md" "$tmpdir/AGENTS.md"
printf '\ncustom project instruction\n' >> "$tmpdir/AGENTS.md"

"$repo_root/bin/aiops" migrate --target "$tmpdir" --plan >/tmp/aiops-e2e-migrate-adapter-plan.out

grep -q 'AGENTS.md adapter update' /tmp/aiops-e2e-migrate-adapter-plan.out || {
  printf '%s\n' "migrate plan did not surface custom AGENTS.md as user decision" >&2
  exit 1
}

before="$(cksum "$tmpdir/AGENTS.md")"
"$repo_root/bin/aiops" migrate --target "$tmpdir" --apply >/tmp/aiops-e2e-migrate-adapter-apply.out
after="$(cksum "$tmpdir/AGENTS.md")"

[ "$before" = "$after" ] || {
  printf '%s\n' "migrate apply modified custom AGENTS.md" >&2
  exit 1
}

grep -q "| core_version | $current_version |" "$tmpdir/.ai_project/operating_model.md" || {
  printf '%s\n' "migrate apply did not update core version with custom adapter" >&2
  exit 1
}

grep -q 'needs_user_decision: AGENTS.md adapter update' /tmp/aiops-e2e-migrate-adapter-apply.out || {
  printf '%s\n' "migrate verify did not keep adapter drift as user decision" >&2
  exit 1
}

grep -q 'verification: passed' /tmp/aiops-e2e-migrate-adapter-apply.out || {
  printf '%s\n' "migrate apply should pass with custom adapter drift" >&2
  exit 1
}

printf '%s\n' "ok: migrate custom adapter decision"

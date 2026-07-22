#!/usr/bin/env sh
set -eu

repo_root="$(CDPATH= cd "$(dirname "$0")/.." && pwd)"
tmpdir="$(mktemp -d /tmp/aiops-e2e-migrate-conflict.XXXXXX)"
trap 'rm -rf "$tmpdir"' EXIT INT TERM

ln -s "$repo_root" "$tmpdir/.ai"
cp -R "$repo_root/templates/ai_project/fast_track" "$tmpdir/.ai_project"

if "$repo_root/bin/aiops" migrate --target "$tmpdir" --plan --apply >/tmp/aiops-e2e-migrate-conflict.out 2>&1; then
  printf '%s\n' "migrate should fail when --plan and --apply are combined" >&2
  exit 1
fi

grep -q 'only one of --plan or --apply' /tmp/aiops-e2e-migrate-conflict.out || {
  printf '%s\n' "migrate conflict error was not clear" >&2
  exit 1
}

[ ! -d "$tmpdir/.ai_knowledge" ] || {
  printf '%s\n' "migrate option conflict should not apply changes" >&2
  exit 1
}

printf '%s\n' "ok: migrate option conflict"

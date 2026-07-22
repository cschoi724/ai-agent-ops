#!/usr/bin/env sh
set -eu

repo_root="$(CDPATH= cd "$(dirname "$0")/.." && pwd)"
tmpdir="$(mktemp -d /tmp/aiops-e2e-migrate-verify-fail.XXXXXX)"
trap 'rm -rf "$tmpdir"' EXIT INT TERM

ln -s "$repo_root" "$tmpdir/.ai"
cp -R "$repo_root/templates/ai_project/fast_track" "$tmpdir/.ai_project"
mkdir -p "$tmpdir/.ai_project/tasks"
printf '%s\n' 'legacy task missing metadata' > "$tmpdir/.ai_project/tasks/T-bad.md"

if "$repo_root/bin/aiops" migrate --target "$tmpdir" --apply >/tmp/aiops-e2e-migrate-verify-fail.out 2>&1; then
  printf '%s\n' "migrate apply should fail when post-apply verification fails" >&2
  exit 1
fi

grep -q 'Verifying migration state' /tmp/aiops-e2e-migrate-verify-fail.out || {
  printf '%s\n' "migrate apply did not reach verification" >&2
  exit 1
}

grep -q 'warn: task missing status' /tmp/aiops-e2e-migrate-verify-fail.out || {
  printf '%s\n' "migrate apply did not surface doctor verification failure" >&2
  exit 1
}

printf '%s\n' "ok: migrate apply verification failure"

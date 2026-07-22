#!/usr/bin/env sh
set -eu

repo_root="$(CDPATH= cd "$(dirname "$0")/.." && pwd)"
tmpdir="$(mktemp -d /tmp/aiops-e2e-migrate-mismatch.XXXXXX)"
trap 'rm -rf "$tmpdir"' EXIT INT TERM

ln -s "$repo_root" "$tmpdir/.ai"
cp -R "$repo_root/templates/ai_project/fast_track" "$tmpdir/.ai_project"
mkdir -p \
  "$tmpdir/.ai_project/tasks/active" \
  "$tmpdir/.ai_project/tasks/backlog" \
  "$tmpdir/.ai_project/tasks/archive"

awk '{ gsub(/\{\{CORE_VERSION\}\}/, "0.0.0"); print }' \
  "$tmpdir/.ai_project/operating_model.md" > "$tmpdir/.ai_project/operating_model.tmp"
mv "$tmpdir/.ai_project/operating_model.tmp" "$tmpdir/.ai_project/operating_model.md"

"$repo_root/bin/aiops" migrate --target "$tmpdir" --plan >/tmp/aiops-e2e-migrate-mismatch.out

grep -q 'mode: plan' /tmp/aiops-e2e-migrate-mismatch.out || {
  printf '%s\n' "migrate did not report plan mode" >&2
  exit 1
}

grep -q 'migration_status: migration_needed' /tmp/aiops-e2e-migrate-mismatch.out || {
  printf '%s\n' "migrate did not report migration_needed" >&2
  exit 1
}

grep -q 'operating_model.md core_version/core_source record' /tmp/aiops-e2e-migrate-mismatch.out || {
  printf '%s\n' "migrate plan did not include core_version safe fix" >&2
  exit 1
}

printf '%s\n' "ok: migrate version mismatch"

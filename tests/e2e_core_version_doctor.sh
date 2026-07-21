#!/usr/bin/env sh
set -eu

repo_root="$(CDPATH= cd "$(dirname "$0")/.." && pwd)"
tmpdir="$(mktemp -d /tmp/aiops-e2e-version.XXXXXX)"
trap 'rm -rf "$tmpdir"' EXIT INT TERM

ln -s "$repo_root" "$tmpdir/.ai"
cp -R "$repo_root/templates/ai_project/fast_track" "$tmpdir/.ai_project"
mkdir -p \
  "$tmpdir/.ai_project/tasks/active" \
  "$tmpdir/.ai_project/tasks/backlog" \
  "$tmpdir/.ai_project/tasks/archive" \
  "$tmpdir/.ai_project/reports" \
  "$tmpdir/.ai_project/qa"

perl -0pi -e 's/\{\{CORE_VERSION\}\}/0.0.0/g' "$tmpdir/.ai_project/operating_model.md"

if "$repo_root/bin/aiops" doctor --target "$tmpdir" --strict >/tmp/aiops-e2e-version-doctor.out 2>&1; then
  printf '%s\n' "doctor --strict should fail when recorded core_version differs" >&2
  exit 1
fi

grep -q 'warn: .ai_project core_version 0.0.0 differs from current core' /tmp/aiops-e2e-version-doctor.out || {
  printf '%s\n' "doctor did not report core_version mismatch" >&2
  exit 1
}

printf '%s\n' "ok: core version mismatch fails strict"

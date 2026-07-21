#!/usr/bin/env sh
set -eu

repo_root="$(CDPATH= cd "$(dirname "$0")/.." && pwd)"
tmpdir="$(mktemp -d /tmp/aiops-e2e-invalid.XXXXXX)"
trap 'rm -rf "$tmpdir"' EXIT INT TERM

ln -s "$repo_root" "$tmpdir/.ai"
cp -R "$repo_root/templates/ai_project/fast_track" "$tmpdir/.ai_project"
mkdir -p \
  "$tmpdir/.ai_project/tasks/active" \
  "$tmpdir/.ai_project/tasks/backlog" \
  "$tmpdir/.ai_project/tasks/archive" \
  "$tmpdir/.ai_project/reports" \
  "$tmpdir/.ai_project/qa"

{
  printf '%s\n' "# Bad Task"
  printf '%s\n' "status: verification_ready"
} > "$tmpdir/.ai_project/tasks/active/T-bad.md"

if "$repo_root/bin/aiops" doctor --target "$tmpdir" --strict >/tmp/aiops-e2e-invalid-doctor.out 2>&1; then
  printf '%s\n' "doctor --strict should fail for invalid task metadata" >&2
  exit 1
fi

grep -q 'warn: task missing target_role:' /tmp/aiops-e2e-invalid-doctor.out || {
  printf '%s\n' "doctor did not report missing target_role" >&2
  exit 1
}

grep -q 'warn: verification_ready task missing qa_to:' /tmp/aiops-e2e-invalid-doctor.out || {
  printf '%s\n' "doctor did not report missing qa_to" >&2
  exit 1
}

grep -q 'warnings: 2' /tmp/aiops-e2e-invalid-doctor.out || {
  printf '%s\n' "doctor did not count task warnings" >&2
  exit 1
}

printf '%s\n' "ok: invalid task fails strict"

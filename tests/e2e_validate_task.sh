#!/usr/bin/env sh
set -eu

repo_root="$(CDPATH= cd "$(dirname "$0")/.." && pwd)"
tmpdir="$(mktemp -d /tmp/aiops-e2e-validate.XXXXXX)"
trap 'rm -rf "$tmpdir"' EXIT INT TERM

valid_task="$tmpdir/T-valid.md"
invalid_task="$tmpdir/T-invalid.md"

{
  printf '%s\n' "id: T-20260721-001"
  printf '%s\n' "title: Validate task metadata"
  printf '%s\n' "status: approved"
  printf '%s\n' "workflow: feature"
  printf '%s\n' "target_role: Execution Role"
  printf '%s\n' "required_capabilities:"
  printf '%s\n' "- implementation"
  printf '%s\n' "allowed_paths:"
  printf '%s\n' "- bin/aiops"
  printf '%s\n' "source_of_truth:"
  printf '%s\n' "- runtime/task_queue.md"
  printf '%s\n' "report_to: .ai_project/reports/T-20260721-001_task-report.md"
} > "$valid_task"

"$repo_root/bin/aiops" validate task "$valid_task" >/tmp/aiops-e2e-validate-valid.out

{
  printf '%s\n' "id: T-20260721-002"
  printf '%s\n' "status: verification_ready"
  printf '%s\n' "workflow: feature"
  printf '%s\n' "target_role: Verification Role"
  printf '%s\n' "required_capabilities:"
  printf '%s\n' "- qa_review"
} > "$invalid_task"

if "$repo_root/bin/aiops" validate task "$invalid_task" >/tmp/aiops-e2e-validate-invalid.out 2>&1; then
  printf '%s\n' "validate task should fail when verification_ready task has no qa_to" >&2
  exit 1
fi

grep -q 'missing: qa_to required for status verification_ready' /tmp/aiops-e2e-validate-invalid.out || {
  printf '%s\n' "validate task did not report missing qa_to" >&2
  exit 1
}

printf '%s\n' "ok: validate task"

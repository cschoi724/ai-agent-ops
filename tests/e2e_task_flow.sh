#!/usr/bin/env sh
set -eu

repo_root="$(CDPATH= cd "$(dirname "$0")/.." && pwd)"
tmpdir="$(mktemp -d /tmp/aiops-e2e-task-flow.XXXXXX)"
trap 'rm -rf "$tmpdir"' EXIT INT TERM

ln -s "$repo_root" "$tmpdir/.ai"
mkdir -p "$tmpdir/.ai_project/tasks/active" "$tmpdir/.ai_project/tasks/backlog" "$tmpdir/.ai_project/tasks/archive"
printf '# Source of Truth\n' > "$tmpdir/.ai_project/source_of_truth.md"

"$repo_root/bin/aiops" task create \
  --target "$tmpdir" \
  --id T-20260727-001 \
  --title "Task flow validation" \
  --workflow feature \
  --role "Lead Role" \
  --capability planning \
  --allowed-path src/ \
  --source-of-truth .ai_project/source_of_truth.md \
  --created-by "Lead Agent" \
  >/tmp/aiops-e2e-task-create.out

grep -q 'task_id: T-20260727-001' /tmp/aiops-e2e-task-create.out || {
  printf '%s\n' "task create did not report task id" >&2
  exit 1
}

"$repo_root/bin/aiops" task status T-20260727-001 --target "$tmpdir" >/tmp/aiops-e2e-task-status.out
grep -q 'status: proposed' /tmp/aiops-e2e-task-status.out || {
  printf '%s\n' "task status did not report proposed" >&2
  exit 1
}

"$repo_root/bin/aiops" task transition T-20260727-001 \
  --target "$tmpdir" \
  --to scoped \
  --role "Lead Role" \
  --by "Lead Agent" \
  --reason "scope ready" \
  >/tmp/aiops-e2e-task-scoped.out

grep -q 'from: proposed' /tmp/aiops-e2e-task-scoped.out || {
  printf '%s\n' "transition did not report proposed source" >&2
  exit 1
}
grep -q 'to: scoped' /tmp/aiops-e2e-task-scoped.out || {
  printf '%s\n' "transition did not report scoped target" >&2
  exit 1
}

if "$repo_root/bin/aiops" task transition T-20260727-001 \
  --target "$tmpdir" \
  --to done \
  --role "Execution Role" \
  --by "Dev Agent" \
  >/tmp/aiops-e2e-task-invalid-transition.out 2>&1; then
  printf '%s\n' "invalid task transition should fail" >&2
  exit 1
fi

grep -q 'invalid transition: scoped -> done by Execution Role' /tmp/aiops-e2e-task-invalid-transition.out || {
  printf '%s\n' "invalid transition error missing" >&2
  exit 1
}

cat > "$tmpdir/.ai_project/tasks/active/T-20260727-002.md" <<'EOF'
---
schema: aiops.task.v1
id: T-20260727-002
title: Atomic failed transition
status: proposed
type: feature
priority: medium
workflow: feature
target_agent: Development Agent
target_role: Direction Role
required_capabilities:
  - planning
depends_on: []
blocks: []
locked_by:
lock_session:
updated_at: 2026-08-05
---

# Atomic failed transition
EOF

"$repo_root/bin/aiops" validate task "$tmpdir/.ai_project/tasks/active/T-20260727-002.md" --strict >/tmp/aiops-e2e-task-atomic-before-validate.out
cp "$tmpdir/.ai_project/tasks/active/T-20260727-002.md" /tmp/aiops-e2e-task-atomic-before.md
if "$repo_root/bin/aiops" task transition T-20260727-002 \
  --target "$tmpdir" \
  --to approved \
  --role "Direction Role" \
  --by "Lead Agent" \
  >/tmp/aiops-e2e-task-atomic-failed-transition.out 2>&1; then
  printf '%s\n' "invalid metadata transition should fail" >&2
  exit 1
fi

grep -q 'transition produced invalid task metadata' /tmp/aiops-e2e-task-atomic-failed-transition.out || {
  printf '%s\n' "invalid metadata transition error missing" >&2
  exit 1
}
cmp -s /tmp/aiops-e2e-task-atomic-before.md "$tmpdir/.ai_project/tasks/active/T-20260727-002.md" || {
  printf '%s\n' "failed invalid metadata transition mutated task file" >&2
  exit 1
}

"$repo_root/bin/aiops" task transition T-20260727-001 \
  --target "$tmpdir" \
  --to approved \
  --role "Direction Role" \
  --by "Lead Agent" \
  >/tmp/aiops-e2e-task-approved.out

cp "$tmpdir/.ai_project/tasks/active/T-20260727-001.md" /tmp/aiops-e2e-task-before-blocked.md
if "$repo_root/bin/aiops" task transition T-20260727-001 \
  --target "$tmpdir" \
  --to blocked \
  --role "Execution Role" \
  --by "Dev Agent" \
  >/tmp/aiops-e2e-task-blocked-missing-fields.out 2>&1; then
  printf '%s\n' "blocked transition without blocker should fail" >&2
  exit 1
fi

grep -q 'blocked transition requires --blocker' /tmp/aiops-e2e-task-blocked-missing-fields.out || {
  printf '%s\n' "blocked transition did not require blocker before mutation" >&2
  exit 1
}
cmp -s /tmp/aiops-e2e-task-before-blocked.md "$tmpdir/.ai_project/tasks/active/T-20260727-001.md" || {
  printf '%s\n' "failed blocked transition mutated task file" >&2
  exit 1
}

"$repo_root/bin/aiops" task transition T-20260727-001 \
  --target "$tmpdir" \
  --to in_progress \
  --role "Execution Role" \
  --by "Dev Agent" \
  >/tmp/aiops-e2e-task-progress.out

grep -q 'locked_by: Dev Agent' "$tmpdir/.ai_project/tasks/active/T-20260727-001.md" || {
  printf '%s\n' "in_progress transition did not lock task" >&2
  exit 1
}

if "$repo_root/bin/aiops" task lock T-20260727-001 \
  --target "$tmpdir" \
  --by "QA Agent" \
  >/tmp/aiops-e2e-task-lock-conflict.out 2>&1; then
  printf '%s\n' "lock conflict should fail" >&2
  exit 1
fi

grep -q 'task is already locked by Dev Agent' /tmp/aiops-e2e-task-lock-conflict.out || {
  printf '%s\n' "lock conflict error missing" >&2
  exit 1
}

"$repo_root/bin/aiops" task transition T-20260727-001 \
  --target "$tmpdir" \
  --to verification_ready \
  --role "Execution Role" \
  --by "Dev Agent" \
  >/tmp/aiops-e2e-task-verification-ready.out

grep -q 'target_role: Verification Role' "$tmpdir/.ai_project/tasks/active/T-20260727-001.md" || {
  printf '%s\n' "verification_ready did not set Verification Role" >&2
  exit 1
}

"$repo_root/bin/aiops" task transition T-20260727-001 \
  --target "$tmpdir" \
  --to verification_in_progress \
  --role "Verification Role" \
  --by "QA Agent" \
  >/tmp/aiops-e2e-task-verification-progress.out

"$repo_root/bin/aiops" task transition T-20260727-001 \
  --target "$tmpdir" \
  --to verification_passed \
  --role "Verification Role" \
  --by "QA Agent" \
  >/tmp/aiops-e2e-task-verification-passed.out

"$repo_root/bin/aiops" task transition T-20260727-001 \
  --target "$tmpdir" \
  --to completion_review \
  --role "Completion Role" \
  --by "Lead Agent" \
  >/tmp/aiops-e2e-task-completion-review.out

"$repo_root/bin/aiops" task transition T-20260727-001 \
  --target "$tmpdir" \
  --to done \
  --role "Completion Role" \
  --by "Lead Agent" \
  >/tmp/aiops-e2e-task-done.out

"$repo_root/bin/aiops" validate task "$tmpdir/.ai_project/tasks/active/T-20260727-001.md" --strict >/tmp/aiops-e2e-task-validate.out

grep -q 'status: done' "$tmpdir/.ai_project/tasks/active/T-20260727-001.md" || {
  printf '%s\n' "task did not end as done" >&2
  exit 1
}

printf '%s\n' "ok: task flow"

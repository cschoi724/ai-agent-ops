#!/usr/bin/env sh
set -eu

repo_root="$(CDPATH= cd "$(dirname "$0")/.." && pwd)"
tmpdir="$(mktemp -d /tmp/aiops-e2e-shared-status.XXXXXX)"
trap 'rm -rf "$tmpdir"' EXIT INT TERM

remote="$tmpdir/remote.git"
project="$tmpdir/project"

git init --bare "$remote" >/dev/null 2>&1
git init -b develop "$project" >/dev/null
git -C "$project" config user.email "aiops@example.test"
git -C "$project" config user.name "AI Ops Test"
git -C "$project" remote add origin "$remote"

ln -s "$repo_root" "$project/.ai"
mkdir -p "$project/.ai_project/tasks/active" "$project/.ai_project/tasks/backlog" "$project/.ai_project/tasks/archive"
printf '# Source of Truth\n' > "$project/.ai_project/source_of_truth.md"

cat > "$project/.ai_project/operating_model.md" <<'EOF'
---
schema: aiops.operating_model.v1
project: SharedStatusProject
bootstrap_mode: fast_track
core_version: 0.8.0
core_source: symlink
core_update_policy: manual_review
start_context: assigned_or_existing_project
readiness_level: existing_project_scan_required
operating_mode: team_pr
team_pattern: single_team
workflow_policy: standard_vnext
ownership_model: path_plus_domain
coordination: parallel_with_locks
board_model: project_board_only
branch_pr: branch_per_task
canonical_status_ref: origin/develop
knowledge_mode: minimal
release_role: inactive
active_roles:
  - Lead Role
  - Execution Role
  - Verification Role
  - Completion Role
  - Ops Governance Role
deferred_roles: []
---

# Project Operating Model
EOF

cat > "$project/.ai_project/tasks/active/T-20260731-001.md" <<'EOF'
---
schema: aiops.task.v1
id: T-20260731-001
title: Shared status check
status: done
type: feature
priority: medium
workflow: feature
target_agent:
target_role:
required_capabilities:
  - implementation
allowed_paths:
  - src/
source_of_truth:
  - .ai_project/source_of_truth.md
depends_on: []
blocks: []
locked_by:
lock_session:
updated_at: 2026-07-31
report_to: .ai_project/reports/T-20260731-001_task-report.md
qa_to: .ai_project/qa/T-20260731-001_qa-report.md
---

# Shared status check
EOF

git -C "$project" add .ai_project .ai >/dev/null
git -C "$project" commit -m "seed shared status fixture" >/dev/null
git -C "$project" push -u origin develop >/dev/null 2>&1

"$repo_root/bin/aiops" status-ref --target "$project" >/tmp/aiops-e2e-status-ref.out
grep -q 'canonical_status_ref: origin/develop' /tmp/aiops-e2e-status-ref.out || {
  printf '%s\n' "status-ref did not read canonical ref" >&2
  exit 1
}

"$repo_root/bin/aiops" sync-status --target "$project" >/tmp/aiops-e2e-sync-status.out
grep -q 'recorded: .ai_project/.runtime/status_ref' /tmp/aiops-e2e-sync-status.out || {
  printf '%s\n' "sync-status did not record runtime status ref" >&2
  exit 1
}

perl -0pi -e 's/status: done/status: completion_review/' "$project/.ai_project/tasks/active/T-20260731-001.md"

"$repo_root/bin/aiops" task status T-20260731-001 --target "$project" >/tmp/aiops-e2e-task-local.out
grep -q 'source: local' /tmp/aiops-e2e-task-local.out || {
  printf '%s\n' "local task status did not mark source" >&2
  exit 1
}
grep -q 'status: completion_review' /tmp/aiops-e2e-task-local.out || {
  printf '%s\n' "local task status did not see local snapshot" >&2
  exit 1
}

"$repo_root/bin/aiops" task status T-20260731-001 --target "$project" --source canonical >/tmp/aiops-e2e-task-canonical.out
grep -q 'source: canonical' /tmp/aiops-e2e-task-canonical.out || {
  printf '%s\n' "canonical task status did not mark source" >&2
  exit 1
}
grep -q 'status_ref: origin/develop' /tmp/aiops-e2e-task-canonical.out || {
  printf '%s\n' "canonical task status did not report status ref" >&2
  exit 1
}
grep -q 'status: done' /tmp/aiops-e2e-task-canonical.out || {
  printf '%s\n' "canonical task status did not read origin/develop state" >&2
  exit 1
}

"$repo_root/bin/aiops" worktree doctor --target "$project" >/tmp/aiops-e2e-worktree-doctor.out
grep -q 'AI Ops worktree doctor' /tmp/aiops-e2e-worktree-doctor.out || {
  printf '%s\n' "worktree doctor header missing" >&2
  exit 1
}
grep -q 'classification: dirty' /tmp/aiops-e2e-worktree-doctor.out || {
  printf '%s\n' "worktree doctor did not protect dirty worktree" >&2
  exit 1
}

printf '%s\n' "ok: shared status worktree"

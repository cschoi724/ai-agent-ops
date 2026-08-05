#!/usr/bin/env sh
set -eu

repo_root="$(CDPATH= cd "$(dirname "$0")/.." && pwd)"
tmpdir="$(mktemp -d /tmp/aiops-e2e-transition-guard.XXXXXX)"
trap 'rm -rf "$tmpdir"' EXIT INT TERM

remote="$tmpdir/remote.git"
project="$tmpdir/project"
stale="$tmpdir/stale"
integrator="$tmpdir/integrator"

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
project: TransitionGuardProject
bootstrap_mode: fast_track
core_version: 0.9.0
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
deferred_roles: []
---

# Project Operating Model
EOF

cat > "$project/.ai_project/tasks/active/T-20260805-004.md" <<'EOF'
---
schema: aiops.task.v1
id: T-20260805-004
title: Canonical transition guard
status: approved
type: feature
priority: medium
workflow: feature
target_agent: Development Agent
target_role: Execution Role
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
updated_at: 2026-08-05
report_to: .ai_project/reports/T-20260805-004_task-report.md
qa_to: .ai_project/qa/T-20260805-004_qa-report.md
status_ref:
status_ref_sha:
base_ref:
base_sha:
branch:
  name:
  base:
pr:
  status:
---

# Canonical transition guard
EOF

git -C "$project" add .ai .ai_project >/dev/null
git -C "$project" commit -m "seed canonical transition guard fixture" >/dev/null
git -C "$project" push -u origin develop >/dev/null 2>&1

"$repo_root/bin/aiops" sync-status --target "$project" >/tmp/aiops-e2e-transition-guard-sync.out

git clone "$remote" "$stale" >/dev/null 2>&1
git -C "$stale" checkout develop >/dev/null 2>&1
perl -0pi -e 's/status: approved/status: completion_review/' "$stale/.ai_project/tasks/active/T-20260805-004.md"

if "$repo_root/bin/aiops" task transition T-20260805-004 \
  --target "$stale" \
  --to done \
  --role "Completion Role" \
  --by "Lead Agent" \
  >/tmp/aiops-e2e-transition-guard-stale-state.out 2>&1; then
  printf '%s\n' "stale local state transition should fail" >&2
  exit 1
fi

grep -q 'local task state is stale against canonical_status_ref' /tmp/aiops-e2e-transition-guard-stale-state.out || {
  printf '%s\n' "stale state guard error missing" >&2
  exit 1
}
grep -q 'canonical_status: approved' /tmp/aiops-e2e-transition-guard-stale-state.out || {
  printf '%s\n' "stale state guard did not report canonical status" >&2
  exit 1
}

"$repo_root/bin/aiops" task transition T-20260805-004 \
  --target "$project" \
  --to in_progress \
  --role "Execution Role" \
  --by "Dev Agent" \
  >/tmp/aiops-e2e-transition-guard-progress.out

grep -q 'canonical_status_ref: origin/develop' /tmp/aiops-e2e-transition-guard-progress.out || {
  printf '%s\n' "transition did not report canonical ref" >&2
  exit 1
}
grep -Eq '^status_ref_sha: [0-9a-f]+' "$project/.ai_project/tasks/active/T-20260805-004.md" || {
  printf '%s\n' "transition did not record status_ref_sha" >&2
  exit 1
}
grep -Eq '^base_sha: [0-9a-f]+' "$project/.ai_project/tasks/active/T-20260805-004.md" || {
  printf '%s\n' "transition did not record base_sha" >&2
  exit 1
}

git clone "$remote" "$integrator" >/dev/null 2>&1
git -C "$integrator" checkout develop >/dev/null 2>&1
git -C "$integrator" config user.email "aiops@example.test"
git -C "$integrator" config user.name "AI Ops Test"
perl -0pi -e 's/status: approved/status: done/' "$integrator/.ai_project/tasks/active/T-20260805-004.md"
git -C "$integrator" add .ai_project/tasks/active/T-20260805-004.md >/dev/null
git -C "$integrator" commit -m "advance canonical task state" >/dev/null
git -C "$integrator" push origin develop >/dev/null 2>&1
git -C "$project" fetch origin develop >/dev/null 2>&1

if "$repo_root/bin/aiops" task transition T-20260805-004 \
  --target "$project" \
  --to verification_ready \
  --role "Execution Role" \
  --by "Dev Agent" \
  >/tmp/aiops-e2e-transition-guard-stale-sha.out 2>&1; then
  printf '%s\n' "stale status_ref_sha transition should fail" >&2
  exit 1
fi

grep -q 'local task status_ref_sha is stale against canonical_status_ref' /tmp/aiops-e2e-transition-guard-stale-sha.out || {
  printf '%s\n' "stale sha guard error missing" >&2
  exit 1
}
grep -q 'next: run aiops sync-status and reload task state' /tmp/aiops-e2e-transition-guard-stale-sha.out || {
  printf '%s\n' "stale sha guard next step missing" >&2
  exit 1
}

printf '%s\n' "ok: task transition canonical guard"

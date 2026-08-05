#!/usr/bin/env sh
set -eu

repo_root="$(CDPATH= cd "$(dirname "$0")/.." && pwd)"
tmpdir="$(mktemp -d /tmp/aiops-e2e-validate-relationships.XXXXXX)"
trap 'rm -rf "$tmpdir"' EXIT INT TERM

git init -b main "$tmpdir" >/dev/null
git -C "$tmpdir" config user.email "aiops@example.test"
git -C "$tmpdir" config user.name "AI Ops Test"

ln -s "$repo_root" "$tmpdir/.ai"
mkdir -p \
  "$tmpdir/.ai_project/tasks/active" \
  "$tmpdir/.ai_project/tasks/backlog" \
  "$tmpdir/.ai_project/tasks/archive"

for file in current_context.md source_of_truth.md task_board.md ops_decisions.md ops_issues.md; do
  printf '# %s\n' "$file" > "$tmpdir/.ai_project/$file"
done

cat > "$tmpdir/.ai_project/operating_model.md" <<'EOF'
---
schema: aiops.operating_model.v1
project: RelationshipProject
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
deferred_roles:
  - Verification Role
---

# Project Operating Model
EOF

cat > "$tmpdir/.ai_project/agent_registry.md" <<'EOF'
---
schema: aiops.agent_registry.v1
project: RelationshipProject
agents:
  - agent: Development Agent
    status: enabled
    team: Product Team
    roles:
      - Execution Role
    capabilities:
      - implementation
---

# Project Agent Registry
EOF

cat > "$tmpdir/.ai_project/tasks/active/T-20260805-001.md" <<'EOF'
---
schema: aiops.task.v1
id: T-20260805-001
title: Relationship warning task
status: approved
workflow: missing_workflow
target_agent: Missing Agent
target_role: Release Role
required_capabilities:
  - implementation
allowed_paths:
  - src/
source_of_truth:
  - Docs/MISSING_SOURCE.md
depends_on:
  - T-20260805-999
blocks: []
updated_at: 2026-08-05
report_to: .ai_project/reports/T-20260805-001_task-report.md
---

# Relationship warning task
EOF

git -C "$tmpdir" add .ai .ai_project >/dev/null
git -C "$tmpdir" commit -m "seed relationship fixture" >/dev/null

"$repo_root/bin/aiops" validate project --target "$tmpdir" --strict >/tmp/aiops-e2e-validate-relationships.out

grep -q 'validate: relationships' /tmp/aiops-e2e-validate-relationships.out || {
  printf '%s\n' "relationship validation section missing" >&2
  exit 1
}
grep -q 'target_role not declared' /tmp/aiops-e2e-validate-relationships.out || {
  printf '%s\n' "missing target_role relationship warning" >&2
  exit 1
}
grep -q 'target_agent not registered' /tmp/aiops-e2e-validate-relationships.out || {
  printf '%s\n' "missing target_agent relationship warning" >&2
  exit 1
}
grep -q 'workflow not found' /tmp/aiops-e2e-validate-relationships.out || {
  printf '%s\n' "missing workflow relationship warning" >&2
  exit 1
}
grep -q 'references missing task' /tmp/aiops-e2e-validate-relationships.out || {
  printf '%s\n' "missing dependency relationship warning" >&2
  exit 1
}
grep -q 'source_of_truth missing' /tmp/aiops-e2e-validate-relationships.out || {
  printf '%s\n' "missing source_of_truth relationship warning" >&2
  exit 1
}
grep -q 'canonical_status_ref does not resolve locally' /tmp/aiops-e2e-validate-relationships.out || {
  printf '%s\n' "missing canonical status ref relationship warning" >&2
  exit 1
}
grep -q 'ok: relationship validation report_only' /tmp/aiops-e2e-validate-relationships.out || {
  printf '%s\n' "relationship validation should be report_only" >&2
  exit 1
}

printf '%s\n' "ok: validate project relationships"

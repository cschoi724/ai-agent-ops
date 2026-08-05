#!/usr/bin/env sh
set -eu

repo_root="$(CDPATH= cd "$(dirname "$0")/.." && pwd)"
tmpdir="$(mktemp -d /tmp/aiops-e2e-status-requirements.XXXXXX)"
trap 'rm -rf "$tmpdir"' EXIT INT TERM

ln -s "$repo_root" "$tmpdir/.ai"
mkdir -p \
  "$tmpdir/.ai_project/tasks/active" \
  "$tmpdir/.ai_project/tasks/backlog" \
  "$tmpdir/.ai_project/tasks/archive" \
  "$tmpdir/.ai_project/reports" \
  "$tmpdir/.ai_project/qa"

for file in current_context.md source_of_truth.md task_board.md ops_decisions.md ops_issues.md; do
  printf '# %s\n' "$file" > "$tmpdir/.ai_project/$file"
done

cat > "$tmpdir/.ai_project/operating_model.md" <<'EOF'
---
schema: aiops.operating_model.v1
project: StatusRequirementsProject
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

cat > "$tmpdir/.ai_project/agent_registry.md" <<'EOF'
---
schema: aiops.agent_registry.v1
project: StatusRequirementsProject
agents:
  - agent: Development Agent
    status: enabled
    team: Product Team
    roles:
      - Execution Role
    capabilities:
      - implementation
  - agent: QA Agent
    status: enabled
    team: Product Team
    roles:
      - Verification Role
    capabilities:
      - verification
---

# Project Agent Registry
EOF

cat > "$tmpdir/.ai_project/tasks/active/T-20260805-001.md" <<'EOF'
---
schema: aiops.task.v1
id: T-20260805-001
title: Approved missing approval evidence
status: approved
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
updated_at: 2026-08-05
report_to: .ai_project/reports/T-20260805-001_task-report.md
---

# Approved missing approval evidence
EOF

cat > "$tmpdir/.ai_project/tasks/active/T-20260805-002.md" <<'EOF'
---
schema: aiops.task.v1
id: T-20260805-002
title: Verification ready missing report evidence
status: verification_ready
workflow: feature
target_agent: QA Agent
target_role: Verification Role
required_capabilities:
  - verification
allowed_paths:
  - src/
source_of_truth:
  - .ai_project/source_of_truth.md
depends_on: []
blocks: []
updated_at: 2026-08-05
report_to: .ai_project/reports/T-20260805-002_task-report.md
qa_to: .ai_project/qa/T-20260805-002_qa-report.md
---

# Verification ready missing report evidence
EOF

cat > "$tmpdir/.ai_project/tasks/archive/T-20260805-003.md" <<'EOF'
---
schema: aiops.task.v1
id: T-20260805-003
title: Done complete enough
status: done
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
updated_at: 2026-08-05
report_to: .ai_project/reports/T-20260805-003_task-report.md
qa_to: .ai_project/qa/T-20260805-003_qa-report.md
status_ref: origin/main
status_ref_sha: abc123
branch:
  name: task/T-20260805-003
pr:
  status: merged
---

# Done complete enough
EOF

printf '# report\n' > "$tmpdir/.ai_project/reports/T-20260805-003_task-report.md"
printf '# qa\n' > "$tmpdir/.ai_project/qa/T-20260805-003_qa-report.md"

"$repo_root/bin/aiops" validate project --target "$tmpdir" --strict >/tmp/aiops-e2e-status-requirements.out

grep -q 'validate: status requirements' /tmp/aiops-e2e-status-requirements.out || {
  printf '%s\n' "status requirements section missing" >&2
  exit 1
}
grep -q 'T-20260805-001.md status approved missing evidence: approved_by' /tmp/aiops-e2e-status-requirements.out || {
  printf '%s\n' "approved status requirement warning missing" >&2
  exit 1
}
grep -q 'T-20260805-002.md status verification_ready missing evidence: report_to file, status_ref, status_ref_sha' /tmp/aiops-e2e-status-requirements.out || {
  printf '%s\n' "verification_ready status requirement warning missing" >&2
  exit 1
}
grep -q 'ok: .ai_project/tasks/archive/T-20260805-003.md status requirements' /tmp/aiops-e2e-status-requirements.out || {
  printf '%s\n' "complete done task should pass status requirements" >&2
  exit 1
}
grep -q 'ok: status requirements report_only' /tmp/aiops-e2e-status-requirements.out || {
  printf '%s\n' "status requirements should be report_only" >&2
  exit 1
}

printf '%s\n' "ok: validate status requirements"

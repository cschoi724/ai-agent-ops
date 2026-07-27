#!/usr/bin/env sh
set -eu

repo_root="$(CDPATH= cd "$(dirname "$0")/.." && pwd)"
tmpdir="$(mktemp -d /tmp/aiops-e2e-validate-project.XXXXXX)"
trap 'rm -rf "$tmpdir"' EXIT INT TERM

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
project: ValidateProject
bootstrap_mode: fast_track
core_version: 0.6.4
core_source: symlink
core_update_policy: manual_review
start_context: new_project_with_requirement
readiness_level: idea_structured
operating_mode: solo_light
team_pattern: single_team
workflow_policy: skip_scoped_for_simple_tasks
ownership_model: path_plus_domain
coordination: single_active_task
board_model: project_board_only
branch_pr: pending_decision
knowledge_mode: minimal
release_role: inactive
active_roles:
  - Direction Role
  - Lead Role
  - Ops Governance Role
deferred_roles:
  - Execution Role
  - Verification Role
---

# Project Operating Model
EOF

cat > "$tmpdir/.ai_project/agent_registry.md" <<'EOF'
---
schema: aiops.agent_registry.v1
project: ValidateProject
agents:
  - agent: Lead Agent
    status: enabled
    team: Product Team
    roles:
      - Lead Role
      - Completion Role
    capabilities:
      - scope_definition
      - completion_review
  - agent: AI Ops Agent
    status: enabled
    team: AI Ops Governance
    roles:
      - Ops Governance Role
    capabilities:
      - process_governance
---

# Project Agent Registry
EOF

cat > "$tmpdir/.ai_project/tasks/active/T-20260727-001.md" <<'EOF'
---
schema: aiops.task.v1
id: T-20260727-001
title: Validate project task
status: approved
workflow: feature
target_role: Execution Role
required_capabilities:
  - implementation
allowed_paths:
  - src/
source_of_truth:
  - .ai_project/source_of_truth.md
report_to: .ai_project/reports/T-20260727-001_task-report.md
---

# Validate project task
EOF

"$repo_root/bin/aiops" validate project --target "$tmpdir" --strict >/tmp/aiops-e2e-validate-project-pass.out
grep -q 'ok: project validate' /tmp/aiops-e2e-validate-project-pass.out || {
  printf '%s\n' "validate project did not pass valid project" >&2
  exit 1
}

cat > "$tmpdir/.ai_project/tasks/active/T-20260727-002.md" <<'EOF'
---
schema: aiops.task.v1
id: T-20260727-002
title: Invalid project task
status: working
workflow: feature
target_role: Coder
required_capabilities:
  - implementation
---

# Invalid project task
EOF

if "$repo_root/bin/aiops" validate --target "$tmpdir" --strict >/tmp/aiops-e2e-validate-project-fail.out 2>&1; then
  printf '%s\n' "validate project should fail invalid task schema" >&2
  exit 1
fi

grep -q 'schema_error: invalid status working' /tmp/aiops-e2e-validate-project-fail.out || {
  printf '%s\n' "validate project did not report invalid status" >&2
  exit 1
}

grep -q 'schema_error: invalid target_role Coder' /tmp/aiops-e2e-validate-project-fail.out || {
  printf '%s\n' "validate project did not report invalid target_role" >&2
  exit 1
}

printf '%s\n' "ok: validate project schema"

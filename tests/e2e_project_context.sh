#!/usr/bin/env sh
set -eu

repo_root="$(CDPATH= cd "$(dirname "$0")/.." && pwd)"
tmpdir="$(mktemp -d /tmp/aiops-e2e-project-context.XXXXXX)"
trap 'rm -rf "$tmpdir"' EXIT INT TERM

project="$tmpdir/project"
mkdir -p \
  "$project/.ai_project/tasks/active" \
  "$project/.ai_project/tasks/backlog" \
  "$project/.ai_project/tasks/archive"

ln -s "$repo_root" "$project/.ai"

for file in current_context.md source_of_truth.md task_board.md ops_decisions.md ops_issues.md; do
  printf '# %s\n' "$file" > "$project/.ai_project/$file"
done

cat > "$project/.ai_project/operating_model.md" <<'EOF'
---
schema: aiops.operating_model.v1
project: ContextProject
bootstrap_mode: fast_track
core_version: 0.9.0
core_source: symlink
core_update_policy: manual_review
start_context: assigned_or_existing_project
readiness_level: implementation_ready
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
  - Ops Governance Role
deferred_roles: []
---

# Project Operating Model
EOF

cat > "$project/.ai_project/agent_registry.md" <<'EOF'
---
schema: aiops.agent_registry.v1
project: ContextProject
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
      - validation
---

# Project Agent Registry
EOF

cat > "$project/.ai_project/tasks/active/T-20260805-006.md" <<'EOF'
---
schema: aiops.task.v1
id: T-20260805-006
title: Context contract task
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
report_to: .ai_project/reports/T-20260805-006_task-report.md
qa_to: .ai_project/qa/T-20260805-006_qa-report.md
---

# Context contract task
EOF

"$repo_root/bin/aiops" project context \
  --target "$project" \
  --role execution \
  --task T-20260805-006 \
  >/tmp/aiops-e2e-project-context.out

grep -q 'AI Ops project context' /tmp/aiops-e2e-project-context.out || {
  printf '%s\n' "project context header missing" >&2
  exit 1
}
grep -q 'role: Execution Role' /tmp/aiops-e2e-project-context.out || {
  printf '%s\n' "project context did not normalize role" >&2
  exit 1
}
grep -q 'status: approved' /tmp/aiops-e2e-project-context.out || {
  printf '%s\n' "project context did not read task status" >&2
  exit 1
}
grep -q 'workflow: feature' /tmp/aiops-e2e-project-context.out || {
  printf '%s\n' "project context did not read workflow" >&2
  exit 1
}
grep -q 'to: in_progress' /tmp/aiops-e2e-project-context.out || {
  printf '%s\n' "project context did not report next transition" >&2
  exit 1
}
grep -q 'canonical_publish: not_required' /tmp/aiops-e2e-project-context.out || {
  printf '%s\n' "project context did not report next checkpoint policy" >&2
  exit 1
}
grep -q 'edit outside allowed_paths' /tmp/aiops-e2e-project-context.out || {
  printf '%s\n' "project context did not report allowed path guard" >&2
  exit 1
}

"$repo_root/bin/aiops" project context \
  --target "$project" \
  --role execution \
  --task T-20260805-006 \
  --json \
  >/tmp/aiops-e2e-project-context.json

ruby -rjson -e '
  data = JSON.parse(File.read(ARGV[0]))
  abort("wrong schema") unless data["schema"] == "aiops.project_context.v1"
  abort("wrong role") unless data["role"] == "Execution Role"
  abort("wrong task status") unless data.dig("task", "status") == "approved"
  abort("missing allowed paths") unless data["allowed_paths"] == ["src/"]
  next_transition = data["valid_next_transitions"].find { |item| item["to"] == "in_progress" }
  abort("missing next transition") unless next_transition
  abort("wrong checkpoint policy") unless next_transition["canonical_publish"] == "not_required"
  abort("missing recommended inspect") unless data["recommended_checks"].any? { |item| item.include?("aiops project inspect") }
' /tmp/aiops-e2e-project-context.json

"$repo_root/bin/aiops" role prompt execution \
  --target "$project" \
  --task T-20260805-006 \
  >/tmp/aiops-e2e-project-context-role-prompt.out

grep -q 'aiops project context --role "Execution Role"' /tmp/aiops-e2e-project-context-role-prompt.out || {
  printf '%s\n' "role prompt did not include project context command" >&2
  exit 1
}

printf '%s\n' "ok: project context"

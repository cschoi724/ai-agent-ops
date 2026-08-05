#!/usr/bin/env sh
set -eu

repo_root="$(CDPATH= cd "$(dirname "$0")/.." && pwd)"
tmpdir="$(mktemp -d /tmp/aiops-e2e-project-inspect.XXXXXX)"
trap 'rm -rf "$tmpdir"' EXIT INT TERM

remote="$tmpdir/remote.git"
project="$tmpdir/project"

git init --bare "$remote" >/dev/null 2>&1
git init -b develop "$project" >/dev/null
git -C "$project" config user.email "aiops@example.test"
git -C "$project" config user.name "AI Ops Test"
git -C "$project" remote add origin "$remote"

ln -s "$repo_root" "$project/.ai"
mkdir -p \
  "$project/.ai_project/tasks/active" \
  "$project/.ai_project/tasks/backlog" \
  "$project/.ai_project/tasks/archive"

for file in current_context.md source_of_truth.md task_board.md ops_decisions.md ops_issues.md; do
  printf '# %s\n' "$file" > "$project/.ai_project/$file"
done

cat > "$project/.ai_project/operating_model.md" <<'EOF'
---
schema: aiops.operating_model.v1
project: InspectProject
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
  - Ops Governance Role
deferred_roles: []
---

# Project Operating Model
EOF

cat > "$project/.ai_project/agent_registry.md" <<'EOF'
---
schema: aiops.agent_registry.v1
project: InspectProject
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
---

# Project Agent Registry
EOF

cat > "$project/.ai_project/tasks/active/T-20260805-001.md" <<'EOF'
---
schema: aiops.task.v1
id: T-20260805-001
title: Inspect task
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
report_to: .ai_project/reports/T-20260805-001_task-report.md
qa_to: .ai_project/qa/T-20260805-001_qa-report.md
---

# Inspect task
EOF

git -C "$project" add .ai .ai_project >/dev/null
git -C "$project" commit -m "seed project inspect fixture" >/dev/null
git -C "$project" push -u origin develop >/dev/null 2>&1

"$repo_root/bin/aiops" sync-status --target "$project" >/tmp/aiops-e2e-project-inspect-sync.out

"$repo_root/bin/aiops" project inspect --target "$project" >/tmp/aiops-e2e-project-inspect.out
grep -q 'AI Ops project inspect' /tmp/aiops-e2e-project-inspect.out || {
  printf '%s\n' "project inspect header missing" >&2
  exit 1
}
grep -q 'name: InspectProject' /tmp/aiops-e2e-project-inspect.out || {
  printf '%s\n' "project inspect did not read project name" >&2
  exit 1
}
grep -q 'status_ref_state: recorded_current' /tmp/aiops-e2e-project-inspect.out || {
  printf '%s\n' "project inspect did not mark recorded current status ref" >&2
  exit 1
}
grep -q 'by_status: approved=1' /tmp/aiops-e2e-project-inspect.out || {
  printf '%s\n' "project inspect did not count task status" >&2
  exit 1
}

"$repo_root/bin/aiops" project inspect --target "$project" --json >/tmp/aiops-e2e-project-inspect.json
ruby -rjson -e '
  data = JSON.parse(File.read(ARGV[0]))
  abort("wrong schema") unless data["schema"] == "aiops.project_inspect.v1"
  abort("wrong project") unless data.dig("project", "name") == "InspectProject"
  abort("wrong status ref state") unless data.dig("git", "status_ref_state") == "recorded_current"
  abort("wrong task count") unless data.dig("tasks", "total") == 1
  abort("wrong active role") unless data.dig("agents", "active_roles").include?("Execution Role")
' /tmp/aiops-e2e-project-inspect.json

printf '%s\n' "ok: project inspect"

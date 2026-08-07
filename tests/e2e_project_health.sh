#!/usr/bin/env sh
set -eu

repo_root="$(CDPATH= cd "$(dirname "$0")/.." && pwd)"
tmpdir="$(mktemp -d /tmp/aiops-e2e-project-health.XXXXXX)"
trap 'rm -rf "$tmpdir"' EXIT INT TERM

remote="$tmpdir/remote.git"
project="$tmpdir/project"
core_version="$(cat "$repo_root/VERSION")"

git init --bare "$remote" >/dev/null 2>&1
git init -b develop "$project" >/dev/null
git -C "$project" config user.email "aiops@example.test"
git -C "$project" config user.name "AI Ops Test"
git -C "$project" remote add origin "$remote"

ln -s "$repo_root" "$project/.ai"
printf '# Agent Instructions\n' > "$project/AGENTS.md"

mkdir -p \
  "$project/.ai_project/tasks/active" \
  "$project/.ai_project/tasks/backlog" \
  "$project/.ai_project/tasks/archive"

for file in current_context.md source_of_truth.md task_board.md ops_decisions.md ops_issues.md; do
  printf '# %s\n' "$file" > "$project/.ai_project/$file"
done
printf '# branch_pr_strategy.md\n' > "$project/.ai_project/branch_pr_strategy.md"

cat > "$project/.ai_project/operating_model.md" <<EOF
---
schema: aiops.operating_model.v1
project: HealthProject
bootstrap_mode: fast_track
core_version: $core_version
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
project: HealthProject
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

git -C "$project" add .ai AGENTS.md .ai_project >/dev/null
git -C "$project" commit -m "seed project health fixture" >/dev/null
git -C "$project" push -u origin develop >/dev/null 2>&1

"$repo_root/bin/aiops" sync-status --target "$project" >/tmp/aiops-e2e-project-health-sync.out

"$repo_root/bin/aiops" project health --target "$project" >/tmp/aiops-e2e-project-health.out
grep -q 'AI Ops project health' /tmp/aiops-e2e-project-health.out || {
  printf '%s\n' "project health header missing" >&2
  exit 1
}
grep -q 'overall: ok' /tmp/aiops-e2e-project-health.out || {
  printf '%s\n' "project health did not report ok" >&2
  exit 1
}
grep -q 'bootstrap: complete' /tmp/aiops-e2e-project-health.out || {
  printf '%s\n' "project health did not report complete bootstrap" >&2
  exit 1
}
grep -q 'multi_agent: ready' /tmp/aiops-e2e-project-health.out || {
  printf '%s\n' "project health did not report multi-agent readiness" >&2
  exit 1
}
grep -q 'migration: not_required' /tmp/aiops-e2e-project-health.out || {
  printf '%s\n' "project health did not report migration status" >&2
  exit 1
}

"$repo_root/bin/aiops" project health --target "$project" --json >/tmp/aiops-e2e-project-health.json
ruby -rjson -e '
  data = JSON.parse(File.read(ARGV[0]))
  abort("wrong schema") unless data["schema"] == "aiops.project_health.v1"
  abort("wrong overall") unless data["overall"] == "ok"
  abort("wrong project") unless data.dig("project", "name") == "HealthProject"
  abort("wrong bootstrap readiness") unless data.dig("readiness", "bootstrap") == "complete"
  abort("wrong multi agent readiness") unless data.dig("readiness", "multi_agent") == "ready"
  abort("unexpected blockers") unless data.dig("summary", "blockers") == 0
' /tmp/aiops-e2e-project-health.json

empty_project="$tmpdir/empty"
mkdir -p "$empty_project"
"$repo_root/bin/aiops" project health --target "$empty_project" >/tmp/aiops-e2e-project-health-empty.out
grep -q 'overall: blocked' /tmp/aiops-e2e-project-health-empty.out || {
  printf '%s\n' "project health did not block missing setup" >&2
  exit 1
}
grep -q 'run aiops seed --adapter both' /tmp/aiops-e2e-project-health-empty.out || {
  printf '%s\n' "project health did not suggest seed for missing setup" >&2
  exit 1
}

printf '%s\n' "ok: project health"

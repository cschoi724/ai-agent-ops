#!/usr/bin/env sh
set -eu

repo_root="$(CDPATH= cd "$(dirname "$0")/.." && pwd)"
tmpdir="$(mktemp -d /tmp/aiops-e2e-bootstrap-strict.XXXXXX)"
trap 'rm -rf "$tmpdir"' EXIT INT TERM

ln -s "$repo_root" "$tmpdir/.ai"
cp "$repo_root/templates/tool_adapters/codex/AGENTS.md" "$tmpdir/AGENTS.md"
cp "$repo_root/templates/tool_adapters/claude/CLAUDE.md" "$tmpdir/CLAUDE.md"
mkdir -p \
  "$tmpdir/.ai_project/tasks/active" \
  "$tmpdir/.ai_project/tasks/backlog" \
  "$tmpdir/.ai_project/tasks/archive"

version="$(cat "$repo_root/VERSION")"

cat > "$tmpdir/.ai_project/operating_model.md" <<EOF
---
schema: aiops.operating_model.v1
project: BootstrapStrictConsistency
bootstrap_mode: guided_full
core_version: "$version"
core_source: homebrew
core_update_policy: follow_core_with_project_validation
start_context: new_project_with_requirement
readiness_level: idea_structured
operating_mode: solo_light
team_pattern: single_team
workflow_policy: skip_scoped_for_simple_tasks
ownership_model: path_plus_domain
coordination: single_active_task
board_model: project_board_only
branch_pr: pending_decision
canonical_status_ref: unresolved
knowledge_mode: minimal
release_role: inactive
active_roles:
  - Direction Role
  - Lead Role
  - Ops Governance Role
deferred_roles:
  - Execution Role
  - Verification Role
inactive_roles:
  - Release Role
---

# Project Operating Model
EOF

cat > "$tmpdir/.ai_project/agent_registry.md" <<'EOF'
---
schema: aiops.agent_registry.v1
project: BootstrapStrictConsistency
agents:
  - agent: current-ai-agent-session
    status: enabled
    team: single_team
    roles:
      - Direction Role
      - Lead Role
      - Ops Governance Role
    capabilities:
      - direction_discovery
      - planning
      - ops_governance
---

# Agent Registry
EOF

for file in current_context.md source_of_truth.md task_board.md ops_decisions.md ops_issues.md; do
  printf '# %s\n' "$file" > "$tmpdir/.ai_project/$file"
done

"$repo_root/bin/aiops" doctor --target "$tmpdir" --strict > "$tmpdir/doctor.out"
"$repo_root/bin/aiops" validate project --target "$tmpdir" --strict > "$tmpdir/validate.out"

for output in "$tmpdir/doctor.out" "$tmpdir/validate.out"; do
  grep -q 'not_required: .ai_project/branch_pr_strategy.md' "$output" || {
    printf '%s\n' "branch_pr_strategy should be not_required in $output" >&2
    cat "$output" >&2
    exit 1
  }
  grep -q 'not_required: .ai_project/workflow_overrides.md' "$output" || {
    printf '%s\n' "workflow_overrides should be not_required in $output" >&2
    cat "$output" >&2
    exit 1
  }
  grep -q 'not_required: .ai_project/ops_migration_plan.md' "$output" || {
    printf '%s\n' "ops_migration_plan should be not_required in $output" >&2
    cat "$output" >&2
    exit 1
  }
  if grep -q 'missing: .ai_project/branch_pr_strategy.md\|missing: .ai_project/workflow_overrides.md\|missing: .ai_project/ops_migration_plan.md' "$output"; then
    printf '%s\n' "conditional files should not be missing in $output" >&2
    cat "$output" >&2
    exit 1
  fi
done

if grep -q 'differs from current core' "$tmpdir/doctor.out"; then
  printf '%s\n' "quoted core_version should not produce mismatch warning" >&2
  cat "$tmpdir/doctor.out" >&2
  exit 1
fi

printf '%s\n' "ok: bootstrap strict consistency"

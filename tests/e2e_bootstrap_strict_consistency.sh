#!/usr/bin/env sh
set -eu

repo_root="$(CDPATH= cd "$(dirname "$0")/.." && pwd)"
tmpdir="$(mktemp -d /tmp/aiops-e2e-bootstrap-strict.XXXXXX)"
active_branch_project="${tmpdir}-active-branch"
trap 'rm -rf "$tmpdir" "$active_branch_project"' EXIT INT TERM

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
"$repo_root/bin/aiops" project snapshot --target "$tmpdir" --json > "$tmpdir/snapshot.json"
"$repo_root/bin/aiops" validate project-snapshot "$tmpdir/snapshot.json" >/dev/null
"$repo_root/bin/aiops" policy evaluate --snapshot "$tmpdir/snapshot.json" --json > "$tmpdir/policy.json"
"$repo_root/bin/aiops" validate policy-evaluation "$tmpdir/policy.json" >/dev/null
"$repo_root/bin/aiops" project health --target "$tmpdir" --json > "$tmpdir/health.json"

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

ruby -rjson -e '
  snapshot = JSON.parse(File.read(ARGV[0]))
  policy = JSON.parse(File.read(ARGV[1]))
  health = JSON.parse(File.read(ARGV[2]))

  abort("snapshot should not be blocked") unless snapshot.dig("health", "blockers") == 0
  abort("snapshot should allow task start") unless snapshot.dig("control", "can_start_task") == true
  abort("policy should not report blockers") unless policy.dig("summary", "blocker") == 0
  abort("health should not report blockers") unless health.dig("summary", "blockers") == 0
  abort("health should be warning for unresolved canonical/status decisions") unless %w[ok warning].include?(health["overall"])
  snapshot_missing = snapshot.fetch("checks").select { |check| check["id"] == "required_file_missing" }
  abort("snapshot should not report conditional required file missing") unless snapshot_missing.empty?
' "$tmpdir/snapshot.json" "$tmpdir/policy.json" "$tmpdir/health.json"

if grep -q 'differs from current core' "$tmpdir/doctor.out"; then
  printf '%s\n' "quoted core_version should not produce mismatch warning" >&2
  cat "$tmpdir/doctor.out" >&2
  exit 1
fi

cp -R "$tmpdir" "$active_branch_project"
ruby -0pi -e 'gsub("branch_pr: pending_decision", "branch_pr: branch_per_task")' "$active_branch_project/.ai_project/operating_model.md"

if "$repo_root/bin/aiops" doctor --target "$active_branch_project" --strict > "$active_branch_project/doctor.out" 2>&1; then
  printf '%s\n' "doctor should fail when active branch_pr strategy lacks branch_pr_strategy.md" >&2
  cat "$active_branch_project/doctor.out" >&2
  exit 1
fi
if "$repo_root/bin/aiops" validate project --target "$active_branch_project" --strict > "$active_branch_project/validate.out" 2>&1; then
  printf '%s\n' "validate should fail when active branch_pr strategy lacks branch_pr_strategy.md" >&2
  cat "$active_branch_project/validate.out" >&2
  exit 1
fi
"$repo_root/bin/aiops" project snapshot --target "$active_branch_project" --json > "$active_branch_project/snapshot.json"
"$repo_root/bin/aiops" validate project-snapshot "$active_branch_project/snapshot.json" >/dev/null
"$repo_root/bin/aiops" policy evaluate --snapshot "$active_branch_project/snapshot.json" --json > "$active_branch_project/policy.json"
"$repo_root/bin/aiops" validate policy-evaluation "$active_branch_project/policy.json" >/dev/null
"$repo_root/bin/aiops" project health --target "$active_branch_project" --json > "$active_branch_project/health.json"

ruby -rjson -e '
  snapshot = JSON.parse(File.read(ARGV[0]))
  policy = JSON.parse(File.read(ARGV[1]))
  health = JSON.parse(File.read(ARGV[2]))
  missing_paths = snapshot.fetch("checks").select { |check| check["id"] == "required_file_missing" }.map { |check| check.dig("evidence", "path") }

  abort("snapshot should report branch_pr_strategy missing") unless missing_paths.include?(".ai_project/branch_pr_strategy.md")
  abort("snapshot should be blocked") unless snapshot.dig("health", "blockers").to_i > 0
  abort("snapshot should block task start") unless snapshot.dig("control", "can_start_task") == false
  abort("policy should report blocker") unless policy.dig("summary", "blocker").to_i > 0
  abort("health should be blocked") unless health["overall"] == "blocked"
' "$active_branch_project/snapshot.json" "$active_branch_project/policy.json" "$active_branch_project/health.json"

printf '%s\n' "ok: bootstrap strict consistency"

#!/usr/bin/env sh
set -eu

repo_root="$(CDPATH= cd "$(dirname "$0")/.." && pwd)"
tmpdir="$(mktemp -d /tmp/aiops-e2e-project-state-consistency.XXXXXX)"
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
mkdir -p \
  "$project/.ai_project/tasks/active" \
  "$project/.ai_project/tasks/backlog" \
  "$project/.ai_project/tasks/archive" \
  "$project/.ai_project/reports" \
  "$project/.ai_project/qa"

for file in current_context.md source_of_truth.md task_board.md ops_decisions.md ops_issues.md; do
  printf '# %s\n' "$file" > "$project/.ai_project/$file"
done

cat > "$project/.ai_project/operating_model.md" <<EOF
---
schema: aiops.operating_model.v1
project: StateConsistencyProject
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
project: StateConsistencyProject
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

cat > "$project/.ai_project/tasks/active/T-20260805-201.md" <<'EOF'
---
schema: aiops.task.v1
id: T-20260805-201
title: State consistency task
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
status_ref: origin/develop
status_ref_sha: placeholder
updated_at: 2026-08-05
report_to: .ai_project/reports/T-20260805-201_task-report.md
qa_to: .ai_project/qa/T-20260805-201_qa-report.md
---

# State consistency task
EOF

git -C "$project" add .ai .ai_project >/dev/null
git -C "$project" commit -m "seed state consistency fixture" >/dev/null
git -C "$project" push -u origin develop >/dev/null 2>&1
"$repo_root/bin/aiops" sync-status --target "$project" >/dev/null

"$repo_root/bin/aiops" project snapshot --target "$project" --json > "$tmpdir/snapshot.json"
"$repo_root/bin/aiops" validate project-snapshot "$tmpdir/snapshot.json" >/dev/null
"$repo_root/bin/aiops" project inspect --target "$project" --json > "$tmpdir/inspect.json"
"$repo_root/bin/aiops" project health --target "$project" --json > "$tmpdir/health.json"
"$repo_root/bin/aiops" project context --target "$project" --role execution --task T-20260805-201 --json > "$tmpdir/context.json"

ruby -rjson -e '
  snapshot = JSON.parse(File.read(ARGV[0]))
  inspect = JSON.parse(File.read(ARGV[1]))
  health = JSON.parse(File.read(ARGV[2]))
  context = JSON.parse(File.read(ARGV[3]))

  def assert_equal(label, left, right)
    abort("#{label} mismatch: #{left.inspect} != #{right.inspect}") unless left == right
  end

  assert_equal("project.name snapshot/inspect", snapshot.dig("project", "name"), inspect.dig("project", "name"))
  assert_equal("project.name snapshot/health", snapshot.dig("project", "name"), health.dig("project", "name"))
  assert_equal("project.name snapshot/context", snapshot.dig("project", "name"), context.dig("project", "name"))

  %w[operating_mode workflow_policy knowledge_mode].each do |key|
    assert_equal("project.#{key} snapshot/inspect", snapshot.dig("project", key), inspect.dig("project", key))
    assert_equal("project.#{key} snapshot/health", snapshot.dig("project", key), health.dig("project", key))
    assert_equal("project.#{key} snapshot/context", snapshot.dig("project", key), context.dig("project", key))
  end

  assert_equal("git.branch snapshot/inspect", snapshot.dig("source_refs", "local_branch"), inspect.dig("git", "branch"))
  assert_equal("git.branch snapshot/health", snapshot.dig("source_refs", "local_branch"), health.dig("git", "branch"))
  assert_equal("git.branch snapshot/context", snapshot.dig("source_refs", "local_branch"), context.dig("git", "branch"))
  assert_equal("git.head snapshot/inspect", snapshot.dig("source_refs", "local_head"), inspect.dig("git", "head"))
  assert_equal("git.head snapshot/health", snapshot.dig("source_refs", "local_head"), health.dig("git", "head"))
  assert_equal("git.head snapshot/context", snapshot.dig("source_refs", "local_head"), context.dig("git", "head"))

  assert_equal("canonical ref snapshot/inspect", snapshot.dig("source_refs", "canonical_status_ref"), inspect.dig("git", "canonical_status_ref"))
  assert_equal("canonical ref snapshot/health", snapshot.dig("source_refs", "canonical_status_ref"), health.dig("git", "canonical_status_ref"))
  assert_equal("canonical ref snapshot/context", snapshot.dig("source_refs", "canonical_status_ref"), context.dig("git", "canonical_status_ref"))
  assert_equal("canonical sha snapshot/inspect", snapshot.dig("source_refs", "canonical_status_sha"), inspect.dig("git", "canonical_status_sha"))
  assert_equal("canonical sha snapshot/health", snapshot.dig("source_refs", "canonical_status_sha"), health.dig("git", "canonical_status_sha"))
  assert_equal("canonical sha snapshot/context", snapshot.dig("source_refs", "canonical_status_sha"), context.dig("git", "canonical_status_sha"))
  assert_equal("status ref state snapshot/inspect", snapshot.dig("source_refs", "status_ref_state"), inspect.dig("git", "status_ref_state"))
  assert_equal("status ref state snapshot/health", snapshot.dig("source_refs", "status_ref_state"), health.dig("git", "status_ref_state"))

  assert_equal("task total snapshot/inspect", snapshot.dig("tasks", "total"), inspect.dig("tasks", "total"))
  assert_equal("task total snapshot/health", snapshot.dig("tasks", "total"), health.dig("tasks", "total"))
  assert_equal("task active snapshot/health", snapshot.dig("tasks", "active"), health.dig("tasks", "active"))
  assert_equal("task status distribution snapshot/inspect", snapshot.dig("tasks", "by_status"), inspect.dig("tasks", "by_status"))
  assert_equal("task status distribution snapshot/health", snapshot.dig("tasks", "by_status"), health.dig("tasks", "by_status"))

  assert_equal("health overall snapshot/health", snapshot.dig("health", "overall"), health["overall"])

  abort("context task status mismatch") unless context.dig("task", "status") == "approved"
  abort("context task workflow mismatch") unless context.dig("task", "workflow") == "feature"
  abort("context should recommend snapshot first") unless context["recommended_checks"].first.include?("aiops project snapshot")
' "$tmpdir/snapshot.json" "$tmpdir/inspect.json" "$tmpdir/health.json" "$tmpdir/context.json"

partial_project="$tmpdir/partial"
mkdir -p "$partial_project/.ai_project"
ln -s "$repo_root" "$partial_project/.ai"
cat > "$partial_project/.ai_project/operating_model.md" <<EOF
---
schema: aiops.operating_model.v1
project: PartialProject
core_version: $core_version
operating_mode: solo_light
workflow_policy: standard_vnext
knowledge_mode: minimal
---

# Partial Project Operating Model
EOF

"$repo_root/bin/aiops" project snapshot --target "$partial_project" --json > "$tmpdir/partial-snapshot.json"
"$repo_root/bin/aiops" validate project-snapshot "$tmpdir/partial-snapshot.json" >/dev/null
"$repo_root/bin/aiops" project health --target "$partial_project" --json > "$tmpdir/partial-health.json"

ruby -rjson -e '
  snapshot = JSON.parse(File.read(ARGV[0]))
  health = JSON.parse(File.read(ARGV[1]))

  abort("partial snapshot should be blocked") unless snapshot.dig("health", "overall") == "blocked"
  abort("partial snapshot should block task start") unless snapshot.dig("control", "can_start_task") == false
  abort("partial health should be blocked") unless health["overall"] == "blocked"
  abort("partial overall mismatch") unless snapshot.dig("health", "overall") == health["overall"]
  abort("snapshot required file blocker missing") unless snapshot["checks"].any? { |check| check["id"] == "required_file_missing" && check["severity"] == "blocker" }
  abort("snapshot required dir blocker missing") unless snapshot["checks"].any? { |check| check["id"] == "required_dir_missing" && check["severity"] == "blocker" }
' "$tmpdir/partial-snapshot.json" "$tmpdir/partial-health.json"

space_project="$tmpdir/space project"
mkdir -p \
  "$space_project/.ai_project/tasks/active" \
  "$space_project/.ai_project/tasks/backlog" \
  "$space_project/.ai_project/tasks/archive"
ln -s "$repo_root" "$space_project/.ai"

for file in current_context.md source_of_truth.md task_board.md ops_decisions.md ops_issues.md; do
  printf '# %s\n' "$file" > "$space_project/.ai_project/$file"
done

cat > "$space_project/.ai_project/operating_model.md" <<EOF
---
schema: aiops.operating_model.v1
project: SpaceProject
core_version: $core_version
operating_mode: solo_light
workflow_policy: standard_vnext
knowledge_mode: minimal
active_roles:
  - Execution Role
---

# Space Project Operating Model
EOF

cat > "$space_project/.ai_project/agent_registry.md" <<'EOF'
---
schema: aiops.agent_registry.v1
project: SpaceProject
agents:
  - agent: Development Agent
    status: enabled
    team: Product Team
    roles:
      - Execution Role
    capabilities:
      - implementation
---

# Space Project Agent Registry
EOF

cat > "$space_project/.ai_project/tasks/active/T-20260805-202.md" <<'EOF'
---
schema: aiops.task.v1
id: T-20260805-202
title: Space path task
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
report_to: .ai_project/reports/T-20260805-202_task-report.md
qa_to: .ai_project/qa/T-20260805-202_qa-report.md
---

# Space path task
EOF

"$repo_root/bin/aiops" project context --target "$space_project" --role execution --task T-20260805-202 --json > "$tmpdir/space-context.json"
ruby -rjson -rshellwords -e '
  context = JSON.parse(File.read(ARGV[0]))
  target = ARGV[1]
  context.fetch("recommended_checks").each do |command|
    next unless command.include?("--target")
    parts = Shellwords.split(command)
    index = parts.index("--target")
    abort("recommended command missing --target: #{command}") unless index
    abort("recommended command target was not preserved: #{command}") unless parts[index + 1] == target
  end
' "$tmpdir/space-context.json" "$space_project"

printf '%s\n' "ok: project state consistency"

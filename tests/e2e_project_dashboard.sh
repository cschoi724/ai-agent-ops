#!/usr/bin/env sh
set -eu

repo_root="$(CDPATH= cd "$(dirname "$0")/.." && pwd)"
tmpdir="$(mktemp -d /tmp/aiops-e2e-project-dashboard.XXXXXX)"
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
printf '# AI Ops local runtime cache\n.ai_project/.runtime/\n' > "$project/.gitignore"

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
project: DashboardProject
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
deferred_roles: []
---

# Project Operating Model
EOF

cat > "$project/.ai_project/agent_registry.md" <<'EOF'
---
schema: aiops.agent_registry.v1
project: DashboardProject
agents:
  - agent: Lead Agent
    status: enabled
    team: Product Team
    roles:
      - Lead Role
    capabilities:
      - scope_definition
  - agent: Development Agent
    status: enabled
    team: Product Team
    roles:
      - Execution Role
    capabilities:
      - implementation
  - agent: Deferred Agent
    status: deferred
    team: custom_platform_team
    roles:
      - custom_execution_role
    capabilities:
      - future_work
---

# Project Agent Registry
EOF

cat > "$project/.ai_project/tasks/active/T-20260807-001_dashboard-done.md" <<'EOF'
---
schema: aiops.task.v1
id: T-20260807-001
title: Finished dashboard fixture task
status: done
workflow: feature
target_role: Completion Role
target_agent: Lead Agent
required_capabilities:
  - completion_review
allowed_paths:
  - docs/
source_of_truth:
  - .ai_project/source_of_truth.md
---

# Finished dashboard fixture task
EOF

cat > "$project/.ai_project/tasks/active/T-20260807-002_dashboard-approved.md" <<'EOF'
---
schema: aiops.task.v1
id: T-20260807-002
title: Approved dashboard fixture task
status: approved
workflow: feature
target_role: Execution Role
target_agent: Development Agent
depends_on:
  - T-20260807-001
blocks:
  - T-20260807-003
required_capabilities:
  - implementation
allowed_paths:
  - src/
source_of_truth:
  - .ai_project/source_of_truth.md
---

# Approved dashboard fixture task
EOF

cat > "$project/.ai_project/tasks/active/T-20260807-003_dashboard-scoped.md" <<'EOF'
---
schema: aiops.task.v1
id: T-20260807-003
title: Scoped dashboard fixture task
status: scoped
workflow: feature
target_role: Lead Role
target_agent: Lead Agent
depends_on:
  - T-20260807-002
required_capabilities:
  - scope_definition
allowed_paths:
  - planning/
source_of_truth:
  - .ai_project/source_of_truth.md
---

# Scoped dashboard fixture task
EOF

cat > "$project/.ai_project/tasks/active/T-20260807-004_dashboard-verification.md" <<'EOF'
---
schema: aiops.task.v1
id: T-20260807-004
title: Verification dashboard fixture task
status: verification_ready
workflow: feature
target_role: Verification Role
target_agent: Lead Agent
depends_on:
  - T-20260807-003
required_capabilities:
  - verification
allowed_paths:
  - qa/
source_of_truth:
  - .ai_project/source_of_truth.md
---

# Verification dashboard fixture task
EOF

cat > "$project/.ai_project/tasks/active/T-20260807-005_dashboard-completion.md" <<'EOF'
---
schema: aiops.task.v1
id: T-20260807-005
title: Completion dashboard fixture task
status: completion_review
workflow: feature
target_role: Completion Role
target_agent: Lead Agent
locked_by: Lead Agent
depends_on:
  - T-20260807-004
required_capabilities:
  - completion_review
allowed_paths:
  - reports/
source_of_truth:
  - .ai_project/source_of_truth.md
---

# Completion dashboard fixture task
EOF

git -C "$project" add .ai .gitignore AGENTS.md .ai_project >/dev/null
git -C "$project" commit -m "seed project dashboard fixture" >/dev/null
git -C "$project" push -u origin develop >/dev/null 2>&1

"$repo_root/bin/aiops" sync-status --target "$project" >/tmp/aiops-e2e-project-dashboard-sync.out

before_hash="$(find "$project" -type f -not -path '*/.git/*' -print | sort | xargs shasum -a 256 | shasum -a 256 | awk "{print \$1}")"
"$repo_root/bin/aiops" project dashboard --target "$project" >/tmp/aiops-e2e-project-dashboard.out
"$repo_root/bin/aiops" project health --target "$project" --json >/tmp/aiops-e2e-project-dashboard-health.json
"$repo_root/bin/aiops" project snapshot --target "$project" --json >/tmp/aiops-e2e-project-dashboard-snapshot.json
"$repo_root/bin/aiops" project dashboard --target "$project" --json >/tmp/aiops-e2e-project-dashboard.json
"$repo_root/bin/aiops" project dashboard --target "$project" --json --user-cli >/tmp/aiops-e2e-project-dashboard-user-cli-json.json
"$repo_root/bin/aiops" validate project-dashboard /tmp/aiops-e2e-project-dashboard.json >/tmp/aiops-e2e-project-dashboard-validate.out
"$repo_root/bin/aiops" validate project-dashboard /tmp/aiops-e2e-project-dashboard-user-cli-json.json >/tmp/aiops-e2e-project-dashboard-user-cli-json-validate.out
after_hash="$(find "$project" -type f -not -path '*/.git/*' -print | sort | xargs shasum -a 256 | shasum -a 256 | awk "{print \$1}")"
[ "$before_hash" = "$after_hash" ] || {
  printf '%s\n' "project dashboard modified project files" >&2
  exit 1
}

grep -q 'AI Ops Dashboard' /tmp/aiops-e2e-project-dashboard.out || {
  printf '%s\n' "dashboard header missing" >&2
  exit 1
}
grep -q 'Project: DashboardProject' /tmp/aiops-e2e-project-dashboard.out || {
  printf '%s\n' "dashboard project name missing" >&2
  exit 1
}
grep -q '1 / 5 done' /tmp/aiops-e2e-project-dashboard.out || {
  printf '%s\n' "dashboard progress missing" >&2
  exit 1
}
grep -q 'Multi-agent: ready' /tmp/aiops-e2e-project-dashboard.out || {
  printf '%s\n' "dashboard multi-agent readiness missing" >&2
  exit 1
}
grep -q 'Enabled: 2    Deferred: 1    Total: 3' /tmp/aiops-e2e-project-dashboard.out || {
  printf '%s\n' "dashboard agent summary missing" >&2
  exit 1
}
ruby -rjson -e '
  health = JSON.parse(File.read(ARGV[0]))
  dashboard = File.read(ARGV[1])
  expected = "Status: #{health["overall"].upcase}    Blockers: #{health.dig("summary", "blockers")}    Warnings: #{health.dig("summary", "warnings")}"
  abort("dashboard summary diverges from project health") unless dashboard.include?(expected)
  health.fetch("readiness").each do |key, value|
    label = key.split("_").map(&:capitalize).join(" ")
    label = "Multi-agent" if key == "multi_agent"
    label = "Task Work" if key == "task_work"
    abort("dashboard readiness #{key} diverges from project health") unless dashboard.include?("#{label}: #{value}")
  end
' /tmp/aiops-e2e-project-dashboard-health.json /tmp/aiops-e2e-project-dashboard.out
ruby -rjson -e '
  health = JSON.parse(File.read(ARGV[0]))
  snapshot = JSON.parse(File.read(ARGV[1]))
  dashboard = JSON.parse(File.read(ARGV[2]))
  abort("dashboard json schema mismatch") unless dashboard["schema"] == "aiops.project_dashboard.v1"
  abort("dashboard json project mismatch") unless dashboard.dig("project", "name") == "DashboardProject"
  abort("dashboard json status diverges") unless dashboard.dig("status", "overall") == health["overall"]
  abort("dashboard json blocker count diverges") unless dashboard.dig("status", "blockers") == health.dig("summary", "blockers")
  abort("dashboard json warning count diverges") unless dashboard.dig("status", "warnings") == health.dig("summary", "warnings")
  abort("dashboard json progress missing") unless dashboard.dig("progress", "total_tasks") == 5 && dashboard.dig("progress", "done_tasks") == 1
  abort("dashboard json readiness diverges") unless dashboard.dig("readiness", "multi_agent") == health.dig("readiness", "multi_agent")
  active = dashboard.dig("tasks", "active_items")
  abort("dashboard json active items missing") unless active.is_a?(Array) && active.length == 4
  approved = active.find { |task| task["id"] == "T-20260807-002" }
  abort("dashboard json approved task missing") unless approved
  abort("dashboard json next action missing") unless approved.dig("next", "action") == "start execution"
  abort("dashboard json dependency missing") unless approved["depends_on"].include?("T-20260807-001")
  abort("dashboard json maps missing") unless dashboard.dig("maps", "dependencies", "edges").any? { |edge| edge["from"] == "T-20260807-001" && edge["to"] == "T-20260807-002" }
  abort("dashboard risk metadata count changed machine projection") unless dashboard.dig("views", "risk", "task_metadata_missing") == snapshot.dig("tasks", "missing_metadata").to_i
  abort("dashboard risk status ref count changed machine projection") unless dashboard.dig("views", "risk", "task_status_ref_missing") == snapshot.dig("tasks", "missing_status_ref_sha").to_i
' /tmp/aiops-e2e-project-dashboard-health.json /tmp/aiops-e2e-project-dashboard-snapshot.json /tmp/aiops-e2e-project-dashboard.json
ruby -rjson -e '
  standard = JSON.parse(File.read(ARGV[0]))
  user_cli = JSON.parse(File.read(ARGV[1]))
  standard.delete("generated_at")
  user_cli.delete("generated_at")
  abort("project dashboard --json --user-cli changed json projection") unless standard == user_cli
' /tmp/aiops-e2e-project-dashboard.json /tmp/aiops-e2e-project-dashboard-user-cli-json.json

"$repo_root/bin/aiops" project dashboard --target "$project" --level compact >/tmp/aiops-e2e-project-dashboard-compact.out
grep -q 'Project: DashboardProject' /tmp/aiops-e2e-project-dashboard-compact.out || {
  printf '%s\n' "compact dashboard project missing" >&2
  exit 1
}
if grep -q '^Settings$' /tmp/aiops-e2e-project-dashboard-compact.out; then
  printf '%s\n' "compact dashboard should omit settings section" >&2
  exit 1
fi
"$repo_root/bin/aiops" status --target "$project" >/tmp/aiops-e2e-user-status.out
grep -q '^DashboardProject 상태$' /tmp/aiops-e2e-user-status.out || {
  printf '%s\n' "user status localized title missing" >&2
  exit 1
}
grep -q '^운영 상태$' /tmp/aiops-e2e-user-status.out || {
  printf '%s\n' "user status operations section missing" >&2
  exit 1
}
grep -q '^현재 일감$' /tmp/aiops-e2e-user-status.out || {
  printf '%s\n' "user status work section missing" >&2
  exit 1
}
grep -q '진행률' /tmp/aiops-e2e-user-status.out || {
  printf '%s\n' "user status progress missing" >&2
  exit 1
}
if grep -q '^AI Ops Dashboard$' /tmp/aiops-e2e-user-status.out; then
  printf '%s\n' "user status should not use advanced dashboard output" >&2
  exit 1
fi
if "$repo_root/bin/aiops" status --target "$project" --view release >/tmp/aiops-e2e-user-status-view.out 2>&1; then
  printf '%s\n' "user status accepted unsupported --view" >&2
  exit 1
fi
grep -q 'aiops status does not support --view' /tmp/aiops-e2e-user-status-view.out || {
  printf '%s\n' "user status unsupported --view message missing" >&2
  exit 1
}

"$repo_root/bin/aiops" project dashboard --target "$project" --color always >/tmp/aiops-e2e-project-dashboard-color.out
ruby -e '
  text = File.read(ARGV[0])
  abort("dashboard color output missing ansi escape") unless text.include?(27.chr + "[")
' /tmp/aiops-e2e-project-dashboard-color.out

"$repo_root/bin/aiops" project dashboard --target "$project" --color never >/tmp/aiops-e2e-project-dashboard-no-color.out
ruby -e '
  text = File.read(ARGV[0])
  abort("dashboard no-color output included ansi escape") if text.include?(27.chr + "[")
' /tmp/aiops-e2e-project-dashboard-no-color.out

"$repo_root/bin/aiops" status --target "$project" --color always >/tmp/aiops-e2e-user-status-color.out
ruby -e '
  text = File.read(ARGV[0])
  abort("user status color output missing ansi escape") unless text.include?(27.chr + "[")
' /tmp/aiops-e2e-user-status-color.out

"$repo_root/bin/aiops" status --target "$project" --color never >/tmp/aiops-e2e-user-status-no-color.out
ruby -e '
  text = File.read(ARGV[0])
  abort("user status no-color output included ansi escape") if text.include?(27.chr + "[")
' /tmp/aiops-e2e-user-status-no-color.out

"$repo_root/bin/aiops" project dashboard --target "$project" --level detail >/tmp/aiops-e2e-project-dashboard-detail.out
grep -q '^Task Status$' /tmp/aiops-e2e-project-dashboard-detail.out || {
  printf '%s\n' "detail dashboard task status missing" >&2
  exit 1
}
grep -q '^Control$' /tmp/aiops-e2e-project-dashboard-detail.out || {
  printf '%s\n' "detail dashboard control section missing" >&2
  exit 1
}

"$repo_root/bin/aiops" project dashboard --target "$project" --view work >/tmp/aiops-e2e-project-dashboard-work.out
grep -q 'AI Ops Work Dashboard' /tmp/aiops-e2e-project-dashboard-work.out || {
  printf '%s\n' "work dashboard header missing" >&2
  exit 1
}
grep -q 'Active Work: 4 / 5 tasks' /tmp/aiops-e2e-project-dashboard-work.out || {
  printf '%s\n' "work dashboard active count missing" >&2
  exit 1
}
grep -q 'T-20260807-002' /tmp/aiops-e2e-project-dashboard-work.out || {
  printf '%s\n' "work dashboard approved task missing" >&2
  exit 1
}
grep -q 'start execution' /tmp/aiops-e2e-project-dashboard-work.out || {
  printf '%s\n' "work dashboard execution next action missing" >&2
  exit 1
}
grep -q 'approve or split' /tmp/aiops-e2e-project-dashboard-work.out || {
  printf '%s\n' "work dashboard lead next action missing" >&2
  exit 1
}
grep -q 'start verification' /tmp/aiops-e2e-project-dashboard-work.out || {
  printf '%s\n' "work dashboard verification next action missing" >&2
  exit 1
}
grep -q 'start completion' /tmp/aiops-e2e-project-dashboard-work.out || {
  printf '%s\n' "work dashboard completion next action missing" >&2
  exit 1
}
"$repo_root/bin/aiops" work --target "$project" >/tmp/aiops-e2e-user-work.out
grep -q '^DashboardProject 일감$' /tmp/aiops-e2e-user-work.out || {
  printf '%s\n' "user work localized title missing" >&2
  exit 1
}
grep -q '^상태 요약$' /tmp/aiops-e2e-user-work.out || {
  printf '%s\n' "user work status summary missing" >&2
  exit 1
}
grep -q '^일감 목록$' /tmp/aiops-e2e-user-work.out || {
  printf '%s\n' "user work list missing" >&2
  exit 1
}
grep -q '담당 역할:' /tmp/aiops-e2e-user-work.out || {
  printf '%s\n' "user work role label missing" >&2
  exit 1
}
grep -q '구현 시작' /tmp/aiops-e2e-user-work.out || {
  printf '%s\n' "user work localized next action missing" >&2
  exit 1
}
grep -q '담당 에이전트: Development Agent' /tmp/aiops-e2e-user-work.out || {
  printf '%s\n' "user work should preserve agent name" >&2
  exit 1
}
if grep -q '^AI Ops Work Dashboard$' /tmp/aiops-e2e-user-work.out; then
  printf '%s\n' "user work should not use advanced work dashboard output" >&2
  exit 1
fi
if "$repo_root/bin/aiops" work --target "$project" --format html --map workflow --output /tmp/aiops-e2e-user-work.html >/tmp/aiops-e2e-user-work-html.out 2>&1; then
  printf '%s\n' "user work accepted unsupported html format" >&2
  exit 1
fi
grep -q 'aiops work --format supports: terminal, tree' /tmp/aiops-e2e-user-work-html.out || {
  printf '%s\n' "user work unsupported format message missing" >&2
  exit 1
}

"$repo_root/bin/aiops" project dashboard --target "$project" --view work --color always >/tmp/aiops-e2e-project-dashboard-work-color.out
ruby -e '
  text = File.read(ARGV[0])
  esc = 27.chr
  checks = {
    "approved status" => "#{esc}[32mapproved",
    "scoped status" => "#{esc}[33mscoped",
    "completion status" => "#{esc}[35mcompletion_review",
    "workflow" => "#{esc}[36mfeature",
    "role" => "#{esc}[34mExecution Role",
    "agent" => "#{esc}[36mDevelopment Agent",
    "empty lock" => "#{esc}[90mnone",
    "held lock" => "#{esc}[1;31mLead Agent",
    "next action" => "#{esc}[32mstart execution"
  }
  checks.each do |label, needle|
    abort("work dashboard color missing #{label}") unless text.include?(needle)
  end
' /tmp/aiops-e2e-project-dashboard-work-color.out

"$repo_root/bin/aiops" project dashboard --target "$project" --view work --format tree >/tmp/aiops-e2e-project-dashboard-work-tree.out
"$repo_root/bin/aiops" work --target "$project" --format tree >/tmp/aiops-e2e-user-work-tree.out
grep -q 'AI Ops Work Tree' /tmp/aiops-e2e-project-dashboard-work-tree.out || {
  printf '%s\n' "work tree header missing" >&2
  exit 1
}
grep -q 'active_work' /tmp/aiops-e2e-project-dashboard-work-tree.out || {
  printf '%s\n' "work tree root missing" >&2
  exit 1
}
grep -q 'approved' /tmp/aiops-e2e-project-dashboard-work-tree.out || {
  printf '%s\n' "work tree approved group missing" >&2
  exit 1
}
grep -q 'verification_ready' /tmp/aiops-e2e-project-dashboard-work-tree.out || {
  printf '%s\n' "work tree verification group missing" >&2
  exit 1
}
grep -q '^DashboardProject 일감 트리$' /tmp/aiops-e2e-user-work-tree.out || {
  printf '%s\n' "user work tree localized title missing" >&2
  exit 1
}
grep -q '^현재 일감$' /tmp/aiops-e2e-user-work-tree.out || {
  printf '%s\n' "user work tree root missing" >&2
  exit 1
}
grep -q '승인됨' /tmp/aiops-e2e-user-work-tree.out || {
  printf '%s\n' "user work tree localized status missing" >&2
  exit 1
}
grep -q '담당:' /tmp/aiops-e2e-user-work-tree.out || {
  printf '%s\n' "user work tree assignee label missing" >&2
  exit 1
}
if grep -q '^AI Ops Work Tree$' /tmp/aiops-e2e-user-work-tree.out; then
  printf '%s\n' "user work tree should not use advanced work tree output" >&2
  exit 1
fi

"$repo_root/bin/aiops" project dashboard --target "$project" --view work --format tree --color always >/tmp/aiops-e2e-project-dashboard-work-tree-color.out
ruby -e '
  text = File.read(ARGV[0])
  esc = 27.chr
  checks = {
    "tree status" => "#{esc}[35mverification_ready",
    "tree role" => "Role: #{esc}[34mVerification Role",
    "tree agent" => "Agent: #{esc}[36mLead Agent",
    "tree workflow" => "Workflow: #{esc}[36mfeature",
    "tree next" => "Next: #{esc}[35mstart verification"
  }
  checks.each do |label, needle|
    abort("work tree color missing #{label}") unless text.include?(needle)
  end
' /tmp/aiops-e2e-project-dashboard-work-tree-color.out

"$repo_root/bin/aiops" project dashboard --target "$project" --view work --level detail >/tmp/aiops-e2e-project-dashboard-work-detail.out
grep -q 'Allowed Paths:' /tmp/aiops-e2e-project-dashboard-work-detail.out || {
  printf '%s\n' "work detail allowed paths missing" >&2
  exit 1
}
grep -q 'Source of Truth:' /tmp/aiops-e2e-project-dashboard-work-detail.out || {
  printf '%s\n' "work detail source of truth missing" >&2
  exit 1
}
grep -q 'aiops role prompt execution' /tmp/aiops-e2e-project-dashboard-work-detail.out || {
  printf '%s\n' "work detail role prompt missing" >&2
  exit 1
}

"$repo_root/bin/aiops" project dashboard --target "$project" --view risk >/tmp/aiops-e2e-project-dashboard-risk.out
grep -q 'AI Ops Risk Dashboard' /tmp/aiops-e2e-project-dashboard-risk.out || {
  printf '%s\n' "risk dashboard header missing" >&2
  exit 1
}
grep -q '^Risk Signals$' /tmp/aiops-e2e-project-dashboard-risk.out || {
  printf '%s\n' "risk dashboard signals missing" >&2
  exit 1
}
grep -q 'Task Status Ref Missing:' /tmp/aiops-e2e-project-dashboard-risk.out || {
  printf '%s\n' "risk dashboard status ref signal missing" >&2
  exit 1
}
"$repo_root/bin/aiops" risks --target "$project" >/tmp/aiops-e2e-user-risks.out
grep -q '^DashboardProject 위험$' /tmp/aiops-e2e-user-risks.out || {
  printf '%s\n' "user risks localized title missing" >&2
  exit 1
}
grep -q '^위험 신호$' /tmp/aiops-e2e-user-risks.out || {
  printf '%s\n' "user risks signals section missing" >&2
  exit 1
}
grep -q '일감 기준 SHA 누락' /tmp/aiops-e2e-user-risks.out || {
  printf '%s\n' "user risks status ref signal missing" >&2
  exit 1
}
if grep -q '^AI Ops Risk Dashboard$' /tmp/aiops-e2e-user-risks.out; then
  printf '%s\n' "user risks should not use advanced risk dashboard output" >&2
  exit 1
fi
if "$repo_root/bin/aiops" risks --target "$project" --view agents >/tmp/aiops-e2e-user-risks-view.out 2>&1; then
  printf '%s\n' "user risks accepted unsupported --view" >&2
  exit 1
fi
grep -q 'aiops risks does not support --view' /tmp/aiops-e2e-user-risks-view.out || {
  printf '%s\n' "user risks unsupported --view message missing" >&2
  exit 1
}

"$repo_root/bin/aiops" project dashboard --target "$project" --view risk --level detail >/tmp/aiops-e2e-project-dashboard-risk-detail.out
grep -q '^Policy Rules$' /tmp/aiops-e2e-project-dashboard-risk-detail.out || {
  printf '%s\n' "risk detail policy rules missing" >&2
  exit 1
}
grep -q '^Approval Required$' /tmp/aiops-e2e-project-dashboard-risk-detail.out || {
  printf '%s\n' "risk detail approval section missing" >&2
  exit 1
}

"$repo_root/bin/aiops" project dashboard --target "$project" --view agents >/tmp/aiops-e2e-project-dashboard-agents.out
grep -q 'AI Ops Agent Dashboard' /tmp/aiops-e2e-project-dashboard-agents.out || {
  printf '%s\n' "agents dashboard header missing" >&2
  exit 1
}
grep -q 'Development Agent' /tmp/aiops-e2e-project-dashboard-agents.out || {
  printf '%s\n' "agents dashboard development agent missing" >&2
  exit 1
}
grep -q 'Execution Role' /tmp/aiops-e2e-project-dashboard-agents.out || {
  printf '%s\n' "agents dashboard execution role missing" >&2
  exit 1
}
grep -q '^Role Load$' /tmp/aiops-e2e-project-dashboard-agents.out || {
  printf '%s\n' "agents dashboard role load missing" >&2
  exit 1
}
"$repo_root/bin/aiops" agents --target "$project" >/tmp/aiops-e2e-user-agents.out
grep -q '^DashboardProject 에이전트$' /tmp/aiops-e2e-user-agents.out || {
  printf '%s\n' "user agents localized title missing" >&2
  exit 1
}
grep -q '^에이전트$' /tmp/aiops-e2e-user-agents.out || {
  printf '%s\n' "user agents section missing" >&2
  exit 1
}
grep -q '^역할별 일감$' /tmp/aiops-e2e-user-agents.out || {
  printf '%s\n' "user agents role load section missing" >&2
  exit 1
}
grep -q 'Development Agent' /tmp/aiops-e2e-user-agents.out || {
  printf '%s\n' "user agents should preserve agent name" >&2
  exit 1
}
grep -q 'Product Team' /tmp/aiops-e2e-user-agents.out || {
  printf '%s\n' "user agents should preserve team name" >&2
  exit 1
}
if grep -Eq '개발 담당|제품팀' /tmp/aiops-e2e-user-agents.out; then
  printf '%s\n' "user agents translated agent or team proper name" >&2
  exit 1
fi
if grep -q '^AI Ops Agent Dashboard$' /tmp/aiops-e2e-user-agents.out; then
  printf '%s\n' "user agents should not use advanced agent dashboard output" >&2
  exit 1
fi

"$repo_root/bin/aiops" project dashboard --target "$project" --view agents --level detail >/tmp/aiops-e2e-project-dashboard-agents-detail.out
grep -q 'Capabilities: implementation' /tmp/aiops-e2e-project-dashboard-agents-detail.out || {
  printf '%s\n' "agents detail capabilities missing" >&2
  exit 1
}
grep -q 'Assigned Active Tasks:' /tmp/aiops-e2e-project-dashboard-agents-detail.out || {
  printf '%s\n' "agents detail assigned tasks missing" >&2
  exit 1
}

"$repo_root/bin/aiops" project dashboard --target "$project" --view release >/tmp/aiops-e2e-project-dashboard-release.out
grep -q 'AI Ops Release Dashboard' /tmp/aiops-e2e-project-dashboard-release.out || {
  printf '%s\n' "release dashboard header missing" >&2
  exit 1
}
grep -q '^Readiness$' /tmp/aiops-e2e-project-dashboard-release.out || {
  printf '%s\n' "release dashboard readiness missing" >&2
  exit 1
}
grep -q 'Canonical Sync: recorded_current' /tmp/aiops-e2e-project-dashboard-release.out || {
  printf '%s\n' "release dashboard canonical sync missing" >&2
  exit 1
}
grep -q 'Release Check: aiops release-check --strict --allow-pending-release' /tmp/aiops-e2e-project-dashboard-release.out || {
  printf '%s\n' "release dashboard release-check command missing" >&2
  exit 1
}
"$repo_root/bin/aiops" release --target "$project" >/tmp/aiops-e2e-user-release.out
grep -q '^DashboardProject 출시 준비$' /tmp/aiops-e2e-user-release.out || {
  printf '%s\n' "user release localized title missing" >&2
  exit 1
}
grep -q '^준비 상태$' /tmp/aiops-e2e-user-release.out || {
  printf '%s\n' "user release readiness section missing" >&2
  exit 1
}
grep -q '^출시 전 확인$' /tmp/aiops-e2e-user-release.out || {
  printf '%s\n' "user release checklist section missing" >&2
  exit 1
}
grep -q '^  점검 명령: aiops release-check --strict --allow-pending-release$' /tmp/aiops-e2e-user-release.out || {
  printf '%s\n' "user release release-check command missing" >&2
  exit 1
}
if grep -q '^AI Ops Release Dashboard$' /tmp/aiops-e2e-user-release.out; then
  printf '%s\n' "user release should not use advanced release dashboard output" >&2
  exit 1
fi

"$repo_root/bin/aiops" project dashboard --target "$project" --view release --json >/tmp/aiops-e2e-project-dashboard-release-json.json
"$repo_root/bin/aiops" validate project-dashboard /tmp/aiops-e2e-project-dashboard-release-json.json >/tmp/aiops-e2e-project-dashboard-release-json-validate.out
ruby -rjson -e '
  dashboard = JSON.parse(File.read(ARGV[0]))
  abort("release json view missing") unless dashboard["view"] == "release"
  abort("dashboard views missing risk") unless dashboard.dig("views", "risk", "task_status_ref_missing").is_a?(Integer)
  abort("dashboard views missing agents") unless dashboard.dig("views", "agents", "items").any? { |agent| agent["name"] == "Development Agent" && agent["assigned_active_tasks"].any? { |task| task["id"] == "T-20260807-002" } }
  abort("dashboard views missing release") unless dashboard.dig("views", "release", "release_check_command") == "aiops release-check --strict --allow-pending-release"
' /tmp/aiops-e2e-project-dashboard-release-json.json

printf '%s\n' "stale marker" > "$project/stale.txt"
git -C "$project" add stale.txt >/dev/null
git -C "$project" commit -m "advance canonical ref" >/dev/null
git -C "$project" push origin develop >/dev/null 2>&1
git -C "$project" fetch origin develop >/dev/null 2>&1
"$repo_root/bin/aiops" project dashboard --target "$project" >/tmp/aiops-e2e-project-dashboard-stale.out
grep -q 'Multi-agent: sync_required' /tmp/aiops-e2e-project-dashboard-stale.out || {
  printf '%s\n' "dashboard stale multi-agent state missing" >&2
  exit 1
}
grep -q 'aiops sync-status --target' /tmp/aiops-e2e-project-dashboard-stale.out || {
  printf '%s\n' "dashboard stale sync next step missing" >&2
  exit 1
}
"$repo_root/bin/aiops" release --target "$project" --color never >/tmp/aiops-e2e-user-release-stale.out
grep -q '일감 상태 전환: 공용 기준 상태가 최신이 아닙니다' /tmp/aiops-e2e-user-release-stale.out || {
  printf '%s\n' "user release stale transition message missing" >&2
  exit 1
}
if grep -Eq 'Task Transition|canonical status ref is not current' /tmp/aiops-e2e-user-release-stale.out; then
  printf '%s\n' "user release stale output leaked machine action/reason" >&2
  exit 1
fi

empty_project="$tmpdir/empty"
mkdir -p "$empty_project"
"$repo_root/bin/aiops" project dashboard --target "$empty_project" >/tmp/aiops-e2e-project-dashboard-empty.out
"$repo_root/bin/aiops" project dashboard --target "$empty_project" --format html --output /tmp/aiops-e2e-project-dashboard-empty.html >/tmp/aiops-e2e-project-dashboard-empty-html.out
"$repo_root/bin/aiops" project snapshot --target "$empty_project" --json >/tmp/aiops-e2e-project-snapshot-empty.json
"$repo_root/bin/aiops" project dashboard --target "$empty_project" --json >/tmp/aiops-e2e-project-dashboard-empty.json
"$repo_root/bin/aiops" validate project-dashboard /tmp/aiops-e2e-project-dashboard-empty.json >/tmp/aiops-e2e-project-dashboard-empty-validate.out
ruby -rjson -e '
  expected = "AI Ops core가 연결되지 않았습니다. seed 설치가 필요합니다."
  snapshot = JSON.parse(File.read(ARGV[0]))
  dashboard = JSON.parse(File.read(ARGV[1]))
  snapshot_message = Array(snapshot["next"]).find { |step| step["action"] == "approve_seed" }&.fetch("message", nil)
  dashboard_message = Array(dashboard["next"]).find { |step| step["action"] == "approve_seed" }&.fetch("message", nil)
  abort("empty snapshot machine message changed") unless snapshot_message == expected
  abort("empty dashboard machine message changed") unless dashboard_message == expected
' /tmp/aiops-e2e-project-snapshot-empty.json /tmp/aiops-e2e-project-dashboard-empty.json
grep -q 'Status: BLOCKED' /tmp/aiops-e2e-project-dashboard-empty.out || {
  printf '%s\n' "empty dashboard should be blocked" >&2
  exit 1
}
grep -q 'core_missing' /tmp/aiops-e2e-project-dashboard-empty.out || {
  printf '%s\n' "empty dashboard core blocker missing" >&2
  exit 1
}
grep -q 'AI Ops 코어가 연결되지 않았습니다. seed 설치가 필요합니다.' /tmp/aiops-e2e-project-dashboard-empty.out || {
  printf '%s\n' "empty terminal dashboard next step was not localized for display" >&2
  exit 1
}
grep -q 'AI Ops 코어가 연결되지 않았습니다. seed 설치가 필요합니다.' /tmp/aiops-e2e-project-dashboard-empty.html || {
  printf '%s\n' "empty HTML dashboard next step was not localized for display" >&2
  exit 1
}
if grep -q 'AI Ops core가' /tmp/aiops-e2e-project-dashboard-empty.out /tmp/aiops-e2e-project-dashboard-empty.html; then
  printf '%s\n' "empty terminal or HTML dashboard leaked machine wording" >&2
  exit 1
fi
"$repo_root/bin/aiops" status --target "$empty_project" --color never >/tmp/aiops-e2e-user-status-empty.out
"$repo_root/bin/aiops" risks --target "$empty_project" --color never >/tmp/aiops-e2e-user-risks-empty.out
"$repo_root/bin/aiops" release --target "$empty_project" --color never >/tmp/aiops-e2e-user-release-empty.out
cat /tmp/aiops-e2e-user-status-empty.out /tmp/aiops-e2e-user-risks-empty.out /tmp/aiops-e2e-user-release-empty.out >/tmp/aiops-e2e-user-empty-combined.out
grep -q '공용 기준 설정 필요' /tmp/aiops-e2e-user-empty-combined.out || {
  printf '%s\n' "empty user output canonical status label missing" >&2
  exit 1
}
grep -q '설정 필요' /tmp/aiops-e2e-user-empty-combined.out || {
  printf '%s\n' "empty user output not configured label missing" >&2
  exit 1
}
grep -q '확인 필요' /tmp/aiops-e2e-user-empty-combined.out || {
  printf '%s\n' "empty user output unresolved label missing" >&2
  exit 1
}
grep -q '프로젝트 설정 없음' /tmp/aiops-e2e-user-empty-combined.out || {
  printf '%s\n' "empty user output project config check label missing" >&2
  exit 1
}
grep -q '필수 파일 없음' /tmp/aiops-e2e-user-empty-combined.out || {
  printf '%s\n' "empty user output required file check label missing" >&2
  exit 1
}
grep -q '필수 디렉터리 없음' /tmp/aiops-e2e-user-empty-combined.out || {
  printf '%s\n' "empty user output required dir check label missing" >&2
  exit 1
}
grep -q 'Workflow catalog 파일 없음' /tmp/aiops-e2e-user-empty-combined.out || {
  printf '%s\n' "empty user output workflow catalog check label missing" >&2
  exit 1
}
grep -q '필수 파일 없음: .ai_project/operating_model.md 파일이 없습니다' /tmp/aiops-e2e-user-empty-combined.out || {
  printf '%s\n' "empty user output required file message is not natural" >&2
  exit 1
}
grep -q '필수 디렉터리 없음: .ai_project/tasks 디렉터리가 없습니다' /tmp/aiops-e2e-user-empty-combined.out || {
  printf '%s\n' "empty user output required directory message is not natural" >&2
  exit 1
}
grep -q 'Workflow catalog 파일 없음: .ai/runtime/workflows.json 파일을 읽을 수 없습니다' /tmp/aiops-e2e-user-empty-combined.out || {
  printf '%s\n' "empty user output workflow catalog message is not natural" >&2
  exit 1
}
grep -q 'AI Ops 코어가 없습니다. aiops seed를 먼저 실행하세요' /tmp/aiops-e2e-user-empty-combined.out || {
  printf '%s\n' "empty user output core missing message missing" >&2
  exit 1
}
grep -q '.ai_project가 없습니다. bootstrap을 먼저 실행하세요' /tmp/aiops-e2e-user-empty-combined.out || {
  printf '%s\n' "empty user output project missing message missing" >&2
  exit 1
}
grep -q 'AGENTS.md 또는 CLAUDE.md 안내 파일이 없습니다' /tmp/aiops-e2e-user-empty-combined.out || {
  printf '%s\n' "empty user output adapter missing message missing" >&2
  exit 1
}
grep -q '일감 시작: 프로젝트 설정에 차단 항목이 있습니다' /tmp/aiops-e2e-user-release-empty.out || {
  printf '%s\n' "empty user output task start message missing" >&2
  exit 1
}
if grep -Eq 'Needs Canonical Status Ref|Not Configured|Unresolved|Project Config Missing|Required File Missing|Required Dir Missing|Workflow Catalog Missing|Adapter Missing|Task Start|Task Transition|project setup has blockers|workflow catalog missing or unreadable|canonical status ref is not current|adapter is 항목이 없습니다|AI Ops core가' /tmp/aiops-e2e-user-empty-combined.out; then
  printf '%s\n' "empty user output leaked machine labels or messages" >&2
  exit 1
fi

"$repo_root/bin/aiops" project dashboard --target "$project" --view work --format mermaid --map dependencies >/tmp/aiops-e2e-project-dashboard-mermaid-dependencies.out
grep -q '^flowchart LR$' /tmp/aiops-e2e-project-dashboard-mermaid-dependencies.out || {
  printf '%s\n' "dependency mermaid flowchart header missing" >&2
  exit 1
}
grep -q 'T_T_20260807_001 --> T_T_20260807_002' /tmp/aiops-e2e-project-dashboard-mermaid-dependencies.out || {
  printf '%s\n' "dependency mermaid edge missing" >&2
  exit 1
}
grep -q 'class T_T_20260807_002 active' /tmp/aiops-e2e-project-dashboard-mermaid-dependencies.out || {
  printf '%s\n' "dependency mermaid class missing" >&2
  exit 1
}
grep -q 'classDef proposed' /tmp/aiops-e2e-project-dashboard-mermaid-dependencies.out || {
  printf '%s\n' "dependency mermaid classDef missing" >&2
  exit 1
}

"$repo_root/bin/aiops" project dashboard --target "$project" --view work --format mermaid --map summary >/tmp/aiops-e2e-project-dashboard-mermaid-summary.out
grep -q 'A_General\["General' /tmp/aiops-e2e-project-dashboard-mermaid-summary.out || {
  printf '%s\n' "summary mermaid area node missing" >&2
  exit 1
}
grep -q 'class A_General area' /tmp/aiops-e2e-project-dashboard-mermaid-summary.out || {
  printf '%s\n' "summary mermaid area class missing" >&2
  exit 1
}

"$repo_root/bin/aiops" project dashboard --target "$project" --view work --format mermaid --map dependencies --focus T-20260807-002 --depth 1 >/tmp/aiops-e2e-project-dashboard-mermaid-focus.out
grep -q 'T_T_20260807_001 --> T_T_20260807_002' /tmp/aiops-e2e-project-dashboard-mermaid-focus.out || {
  printf '%s\n' "focus mermaid predecessor missing" >&2
  exit 1
}
grep -q 'T_T_20260807_002 --> T_T_20260807_003' /tmp/aiops-e2e-project-dashboard-mermaid-focus.out || {
  printf '%s\n' "focus mermaid successor missing" >&2
  exit 1
}
if grep -q 'T_T_20260807_004' /tmp/aiops-e2e-project-dashboard-mermaid-focus.out; then
  printf '%s\n' "focus mermaid included task outside depth" >&2
  exit 1
fi

"$repo_root/bin/aiops" project dashboard --target "$project" --view work --format mermaid --map swimlane --group-by agent >/tmp/aiops-e2e-project-dashboard-mermaid-swimlane.out
grep -q 'subgraph G_Development_Agent\["개발 담당"\]' /tmp/aiops-e2e-project-dashboard-mermaid-swimlane.out || {
  printf '%s\n' "swimlane mermaid agent group missing" >&2
  exit 1
}
grep -q 'T_T_20260807_002\["T-20260807-002' /tmp/aiops-e2e-project-dashboard-mermaid-swimlane.out || {
  printf '%s\n' "swimlane mermaid task missing" >&2
  exit 1
}

"$repo_root/bin/aiops" project dashboard --target "$project" --view work --format mermaid --map critical-path --focus T-20260807-005 --depth 4 >/tmp/aiops-e2e-project-dashboard-mermaid-critical.out
grep -q 'T_T_20260807_005\["T-20260807-005' /tmp/aiops-e2e-project-dashboard-mermaid-critical.out || {
  printf '%s\n' "critical path target missing" >&2
  exit 1
}
grep -q '목표"\]' /tmp/aiops-e2e-project-dashboard-mermaid-critical.out || {
  printf '%s\n' "critical path target label missing" >&2
  exit 1
}

"$repo_root/bin/aiops" project dashboard --target "$project" --view work --format mermaid --map dependencies --json >/tmp/aiops-e2e-project-dashboard-mermaid-json.json
"$repo_root/bin/aiops" validate project-dashboard /tmp/aiops-e2e-project-dashboard-mermaid-json.json >/tmp/aiops-e2e-project-dashboard-mermaid-json-validate.out
ruby -rjson -e '
  dashboard = JSON.parse(File.read(ARGV[0]))
  abort("mermaid json format missing") unless dashboard["format"] == "mermaid"
  abort("mermaid json map missing") unless dashboard["map"] == "dependencies"
  abort("mermaid json work view missing") unless dashboard["view"] == "work"
  abort("mermaid json map edge missing") unless dashboard.dig("maps", "dependencies", "edges").any? { |edge| edge["from"] == "T-20260807-001" && edge["to"] == "T-20260807-002" }
' /tmp/aiops-e2e-project-dashboard-mermaid-json.json

before_html_hash="$(find "$project" -type f -not -path '*/.git/*' -print | sort | xargs shasum -a 256 | shasum -a 256 | awk "{print \$1}")"
"$repo_root/bin/aiops" project dashboard --target "$project" --format html --output /tmp/aiops-e2e-project-dashboard.html >/tmp/aiops-e2e-project-dashboard-html.out
"$repo_root/bin/aiops" project dashboard --target "$project" --format html >/tmp/aiops-e2e-project-dashboard-html-stdout.html
"$repo_root/bin/aiops" project dashboard --target "$project" --format html --map agents --output /tmp/aiops-e2e-project-dashboard-agents.html >/tmp/aiops-e2e-project-dashboard-html-agents.out
"$repo_root/bin/aiops" project dashboard --target "$project" --format html --map dependencies --focus T-20260807-002 --depth 1 --filter-status approved,scoped --filter-agent "Development Agent" --filter-role "Execution Role" --filter-workflow feature --output /tmp/aiops-e2e-project-dashboard-explorer.html >/tmp/aiops-e2e-project-dashboard-explorer.out
after_html_hash="$(find "$project" -type f -not -path '*/.git/*' -print | sort | xargs shasum -a 256 | shasum -a 256 | awk "{print \$1}")"
[ "$before_html_hash" = "$after_html_hash" ] || {
  printf '%s\n' "html dashboard modified project files" >&2
  exit 1
}
grep -q 'wrote: /tmp/aiops-e2e-project-dashboard.html' /tmp/aiops-e2e-project-dashboard-html.out || {
  printf '%s\n' "html dashboard output confirmation missing" >&2
  exit 1
}
grep -q '<!doctype html>' /tmp/aiops-e2e-project-dashboard.html || {
  printf '%s\n' "html dashboard doctype missing" >&2
  exit 1
}
grep -q 'AI Ops 프로젝트 대시보드' /tmp/aiops-e2e-project-dashboard.html || {
  printf '%s\n' "html dashboard title missing" >&2
  exit 1
}
grep -q 'DashboardProject' /tmp/aiops-e2e-project-dashboard.html || {
  printf '%s\n' "html dashboard project missing" >&2
  exit 1
}
grep -q '보는 법' /tmp/aiops-e2e-project-dashboard.html || {
  printf '%s\n' "html dashboard Korean guide missing" >&2
  exit 1
}
grep -q '초록: 정상 / 완료 / 사용 가능' /tmp/aiops-e2e-project-dashboard.html || {
  printf '%s\n' "html dashboard legend missing" >&2
  exit 1
}
grep -q 'class="mermaid"' /tmp/aiops-e2e-project-dashboard.html || {
  printf '%s\n' "html dashboard mermaid container missing" >&2
  exit 1
}
grep -q 'data-zoom="in"' /tmp/aiops-e2e-project-dashboard.html || {
  printf '%s\n' "html dashboard zoom controls missing" >&2
  exit 1
}
grep -q 'id="graph-explorer"' /tmp/aiops-e2e-project-dashboard.html || {
  printf '%s\n' "html dashboard graph explorer missing" >&2
  exit 1
}
grep -q 'id="explorer-search"' /tmp/aiops-e2e-project-dashboard.html || {
  printf '%s\n' "html dashboard task search missing" >&2
  exit 1
}
grep -q 'id="explorer-agent"' /tmp/aiops-e2e-project-dashboard.html || {
  printf '%s\n' "html dashboard agent filter missing" >&2
  exit 1
}
grep -q 'id="explorer-role"' /tmp/aiops-e2e-project-dashboard.html || {
  printf '%s\n' "html dashboard role filter missing" >&2
  exit 1
}
grep -q 'id="explorer-workflow"' /tmp/aiops-e2e-project-dashboard.html || {
  printf '%s\n' "html dashboard workflow filter missing" >&2
  exit 1
}
grep -q 'id="explorer-focus"' /tmp/aiops-e2e-project-dashboard.html || {
  printf '%s\n' "html dashboard focus selector missing" >&2
  exit 1
}
grep -q 'id="explorer-depth"' /tmp/aiops-e2e-project-dashboard.html || {
  printf '%s\n' "html dashboard depth selector missing" >&2
  exit 1
}
grep -q 'name="explorer-status"' /tmp/aiops-e2e-project-dashboard.html || {
  printf '%s\n' "html dashboard status toggles missing" >&2
  exit 1
}
grep -q '의존성 맵에.*중심 일감과 연결 깊이' /tmp/aiops-e2e-project-dashboard.html || {
  printf '%s\n' "html dashboard large graph guidance missing" >&2
  exit 1
}
ruby -rjson -e '
  html = File.read(ARGV[0])
  payload = html[/<script type="application\/json" id="dashboard-explorer-data">(.*?)<\/script>/m, 1]
  abort("explorer data payload missing") unless payload
  data = JSON.parse(payload)
  abort("explorer task data missing") unless data["tasks"].length == 5
  abort("explorer dependency data missing") unless data["edges"].include?(["T-20260807-001", "T-20260807-002"])
  abort("explorer leaked raw agent name") if payload.include?("Development Agent")
  row_ids = html.scan(/class="task-row" data-task-id="([^"]+)"/).flatten.sort
  task_ids = data["tasks"].map { |task| task["id"] }.sort
  abort("explorer table and task data differ") unless row_ids == task_ids
  abort("explorer focus bypasses filters") if html.include?("return matches || (focus && task.id === focus)")
  abort("explorer Mermaid render queue missing") unless html.include?("let renderQueue = Promise.resolve()")
  abort("initial Mermaid render promise missing") unless html.include?("window.aiopsMermaidReady=(async()=>")
  abort("initial Mermaid nodes are not limited to open maps") unless html.include?(".map-panel[open] .mermaid")
  abort("lazy Mermaid map renderer missing") unless html.include?("window.aiopsMermaidRenderGraph") && html.include?("document.addEventListener(\"toggle\"")
  abort("Explorer did not await initial Mermaid render") unless html.include?("await window.aiopsMermaidReady")
  await_index = html.index("await window.aiopsMermaidReady")
  reset_index = html.index(%q{graph.removeAttribute("data-processed")})
  abort("Explorer resets Mermaid DOM before initial render completes") unless await_index && reset_index && await_index < reset_index
' /tmp/aiops-e2e-project-dashboard.html
ruby -rjson -e '
  html = File.read(ARGV[0])
  payload = html[/<script type="application\/json" id="dashboard-explorer-data">(.*?)<\/script>/m, 1]
  data = JSON.parse(payload)
  abort("explorer initial status filter missing") unless data.dig("initial", "statuses") == ["approved", "scoped"]
  abort("explorer initial focus missing") unless data.dig("initial", "focus") == "T-20260807-002"
  abort("explorer initial depth missing") unless data.dig("initial", "depth") == 1
  abort("explorer agent filter token missing") if data.dig("initial", "agent").to_s.empty?
  abort("explorer role filter token missing") if data.dig("initial", "role").to_s.empty?
  abort("explorer workflow filter token missing") if data.dig("initial", "workflow").to_s.empty?
  abort("explorer agent name was not preserved") unless html.match?(/<option value="agent-[0-9]+" selected>Development Agent<\/option>/)
  abort("explorer localized role option missing") unless html.match?(/<option value="role-[0-9]+" selected>구현\/실행<\/option>/)
  abort("explorer localized workflow option missing") unless html.match?(/<option value="workflow-[0-9]+" selected>기능 개발<\/option>/)
' /tmp/aiops-e2e-project-dashboard-explorer.html

for invalid_filter in status agent role workflow; do
  if "$repo_root/bin/aiops" project dashboard --target "$project" --format html "--filter-$invalid_filter" DOES_NOT_EXIST --output "/tmp/aiops-e2e-project-dashboard-invalid-$invalid_filter.html" >/tmp/aiops-e2e-project-dashboard-invalid-filter.out 2>&1; then
    printf '%s\n' "unknown HTML $invalid_filter filter should fail" >&2
    exit 1
  fi
  grep -q "unknown --filter-$invalid_filter value: DOES_NOT_EXIST" /tmp/aiops-e2e-project-dashboard-invalid-filter.out || {
    printf '%s\n' "unknown HTML $invalid_filter filter error missing" >&2
    exit 1
  }
done
grep -q 'class="panel map-panel" data-map="summary" open' /tmp/aiops-e2e-project-dashboard.html || {
  printf '%s\n' "html dashboard open summary panel missing" >&2
  exit 1
}
grep -q 'class="agent-card ok"' /tmp/aiops-e2e-project-dashboard.html || {
  printf '%s\n' "html dashboard enabled agent color class missing" >&2
  exit 1
}
grep -q 'class="agent-card neutral"' /tmp/aiops-e2e-project-dashboard.html || {
  printf '%s\n' "html dashboard deferred agent color class missing" >&2
  exit 1
}
grep -q '사용 가능' /tmp/aiops-e2e-project-dashboard.html || {
  printf '%s\n' "html dashboard human agent status missing" >&2
  exit 1
}
grep -q '개발 담당' /tmp/aiops-e2e-project-dashboard.html || {
  printf '%s\n' "html dashboard human agent name missing" >&2
  exit 1
}
grep -q '표준 워크플로우' /tmp/aiops-e2e-project-dashboard.html || {
  printf '%s\n' "html dashboard human project setting missing" >&2
  exit 1
}
grep -q 'Custom Platform Team' /tmp/aiops-e2e-project-dashboard.html || {
  printf '%s\n' "html dashboard humanized team fallback missing" >&2
  exit 1
}
grep -q 'Custom Execution Role' /tmp/aiops-e2e-project-dashboard.html || {
  printf '%s\n' "html dashboard humanized role fallback missing" >&2
  exit 1
}
grep -q '구현/실행' /tmp/aiops-e2e-project-dashboard.html || {
  printf '%s\n' "html dashboard human role label missing" >&2
  exit 1
}
grep -q '구현' /tmp/aiops-e2e-project-dashboard.html || {
  printf '%s\n' "html dashboard human capability label missing" >&2
  exit 1
}
if grep -q 'future_work' /tmp/aiops-e2e-project-dashboard.html; then
  printf '%s\n' "html dashboard leaked raw capability label" >&2
  exit 1
fi
if ! grep -Eq '<option value="agent-[0-9]+">Development Agent</option>' /tmp/aiops-e2e-project-dashboard.html; then
  printf '%s\n' "html dashboard explorer agent name missing" >&2
  exit 1
fi
if grep -q 'custom_platform_team' /tmp/aiops-e2e-project-dashboard.html; then
  printf '%s\n' "html dashboard leaked raw team fallback" >&2
  exit 1
fi
if grep -q 'custom_execution_role' /tmp/aiops-e2e-project-dashboard.html; then
  printf '%s\n' "html dashboard leaked raw role fallback" >&2
  exit 1
fi
grep -q '담당 역할' /tmp/aiops-e2e-project-dashboard.html || {
  printf '%s\n' "html dashboard human check message missing" >&2
  exit 1
}
if grep -q 'target_role' /tmp/aiops-e2e-project-dashboard.html; then
  printf '%s\n' "html dashboard leaked raw check field" >&2
  exit 1
fi
if grep -q 'sync-상태' /tmp/aiops-e2e-project-dashboard.html; then
  printf '%s\n' "html dashboard corrupted command while humanizing message" >&2
  exit 1
fi
grep -q 'T_T_20260807_001 --&gt; T_T_20260807_002' /tmp/aiops-e2e-project-dashboard.html || {
  printf '%s\n' "html dashboard mermaid dependency edge missing" >&2
  exit 1
}
grep -q 'Mermaid 원본 보기' /tmp/aiops-e2e-project-dashboard.html || {
  printf '%s\n' "html dashboard mermaid source missing" >&2
  exit 1
}
grep -q '<!doctype html>' /tmp/aiops-e2e-project-dashboard-html-stdout.html || {
  printf '%s\n' "html dashboard stdout doctype missing" >&2
  exit 1
}
grep -q '담당자 / 역할 맵' /tmp/aiops-e2e-project-dashboard-agents.html || {
  printf '%s\n' "html dashboard selected map missing" >&2
  exit 1
}
if "$repo_root/bin/aiops" project dashboard --target "$project" --json --output /tmp/aiops-e2e-project-dashboard-invalid.html >/tmp/aiops-e2e-project-dashboard-html-invalid.out 2>&1; then
  printf '%s\n' "json output combination unexpectedly succeeded" >&2
  exit 1
fi
grep -q 'project dashboard --json cannot be combined with --output' /tmp/aiops-e2e-project-dashboard-html-invalid.out || {
  printf '%s\n' "json output combination error missing" >&2
  exit 1
}
if "$repo_root/bin/aiops" project dashboard --target "$project" --filter-status approved >/tmp/aiops-e2e-project-dashboard-filter-invalid.out 2>&1; then
  printf '%s\n' "terminal dashboard accepted HTML-only filter option" >&2
  exit 1
fi
grep -q 'project dashboard filter options require --format html' /tmp/aiops-e2e-project-dashboard-filter-invalid.out || {
  printf '%s\n' "HTML-only filter option error missing" >&2
  exit 1
}
if "$repo_root/bin/aiops" status --target "$project" --filter-status approved >/tmp/aiops-e2e-user-dashboard-filter-invalid.out 2>&1; then
  printf '%s\n' "user dashboard shortcut accepted graph explorer filter" >&2
  exit 1
fi
grep -q 'aiops status does not support --filter-status' /tmp/aiops-e2e-user-dashboard-filter-invalid.out || {
  printf '%s\n' "user dashboard graph explorer filter guard missing" >&2
  exit 1
}

"$repo_root/bin/aiops" project dashboard --target "$project" --view work --format mermaid --map workflow >/tmp/aiops-e2e-project-dashboard-mermaid-workflow.out
grep -q 'S_proposed --> S_scoped' /tmp/aiops-e2e-project-dashboard-mermaid-workflow.out || {
  printf '%s\n' "workflow mermaid status edge missing" >&2
  exit 1
}
grep -q 'S_rework_requested\["재작업 필요"\]' /tmp/aiops-e2e-project-dashboard-mermaid-workflow.out || {
  printf '%s\n' "workflow mermaid rework node missing" >&2
  exit 1
}
grep -q 'T_T_20260807_004\["T-20260807-004' /tmp/aiops-e2e-project-dashboard-mermaid-workflow.out || {
  printf '%s\n' "workflow mermaid task node missing" >&2
  exit 1
}

"$repo_root/bin/aiops" project dashboard --target "$project" --view work --format mermaid --map agents >/tmp/aiops-e2e-project-dashboard-mermaid-agents.out
grep -q 'A_Development_Agent\["개발 담당"\]' /tmp/aiops-e2e-project-dashboard-mermaid-agents.out || {
  printf '%s\n' "agents mermaid agent node missing" >&2
  exit 1
}
grep -q 'R_Execution_Role\["구현/실행"\]' /tmp/aiops-e2e-project-dashboard-mermaid-agents.out || {
  printf '%s\n' "agents mermaid role node missing" >&2
  exit 1
}
grep -q 'A_Development_Agent --> R_Execution_Role' /tmp/aiops-e2e-project-dashboard-mermaid-agents.out || {
  printf '%s\n' "agents mermaid agent-role edge missing" >&2
  exit 1
}
grep -q 'R_Execution_Role --> T_T_20260807_002' /tmp/aiops-e2e-project-dashboard-mermaid-agents.out || {
  printf '%s\n' "agents mermaid role-task edge missing" >&2
  exit 1
}

"$repo_root/bin/aiops" project dashboard --target "$project" --format html --map swimlane --group-by agent --output /tmp/aiops-e2e-project-dashboard-swimlane-agent.html >/tmp/aiops-e2e-project-dashboard-swimlane-agent.out
grep -q 'subgraph G_Development_Agent\[&quot;개발 담당&quot;\]' /tmp/aiops-e2e-project-dashboard-swimlane-agent.html || {
  printf '%s\n' "html swimlane agent group label missing" >&2
  exit 1
}

"$repo_root/bin/aiops" project dashboard --target "$project" --format html --map swimlane --group-by role --output /tmp/aiops-e2e-project-dashboard-swimlane-role.html >/tmp/aiops-e2e-project-dashboard-swimlane-role.out
grep -q 'subgraph G_Execution_Role\[&quot;구현/실행&quot;\]' /tmp/aiops-e2e-project-dashboard-swimlane-role.html || {
  printf '%s\n' "html swimlane role group label missing" >&2
  exit 1
}

"$repo_root/bin/aiops" project dashboard --target "$project" --format html --map swimlane --group-by status --output /tmp/aiops-e2e-project-dashboard-swimlane-status.html >/tmp/aiops-e2e-project-dashboard-swimlane-status.out
grep -q 'subgraph G_approved\[&quot;승인됨&quot;\]' /tmp/aiops-e2e-project-dashboard-swimlane-status.html || {
  printf '%s\n' "html swimlane status group label missing" >&2
  exit 1
}

"$repo_root/bin/aiops" project dashboard --target "$project" --format html --map swimlane --group-by workflow --output /tmp/aiops-e2e-project-dashboard-swimlane-workflow.html >/tmp/aiops-e2e-project-dashboard-swimlane-workflow.out
grep -q 'subgraph G_feature\[&quot;기능 개발&quot;\]' /tmp/aiops-e2e-project-dashboard-swimlane-workflow.html || {
  printf '%s\n' "html swimlane workflow group label missing" >&2
  exit 1
}

"$repo_root/bin/aiops" project dashboard --target "$empty_project" --view work --format mermaid --map blockers >/tmp/aiops-e2e-project-dashboard-mermaid-blockers.out
grep -q '^flowchart TD$' /tmp/aiops-e2e-project-dashboard-mermaid-blockers.out || {
  printf '%s\n' "blockers mermaid flowchart header missing" >&2
  exit 1
}
grep -q 'core_missing' /tmp/aiops-e2e-project-dashboard-mermaid-blockers.out || {
  printf '%s\n' "blockers mermaid core blocker missing" >&2
  exit 1
}

if "$repo_root/bin/aiops" project dashboard --target "$project" --view work --format mermaid --map unknown >/tmp/aiops-e2e-project-dashboard-mermaid-invalid.out 2>&1; then
  printf '%s\n' "invalid mermaid map unexpectedly succeeded" >&2
  exit 1
fi
grep -q 'unknown project dashboard map: unknown' /tmp/aiops-e2e-project-dashboard-mermaid-invalid.out || {
  printf '%s\n' "invalid mermaid map error missing" >&2
  exit 1
}

printf '%s\n' "ok: project dashboard"

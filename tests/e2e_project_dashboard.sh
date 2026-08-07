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
    team: Future Team
    roles:
      - Execution Role
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
"$repo_root/bin/aiops" project dashboard --target "$project" --json >/tmp/aiops-e2e-project-dashboard.json
"$repo_root/bin/aiops" validate project-dashboard /tmp/aiops-e2e-project-dashboard.json >/tmp/aiops-e2e-project-dashboard-validate.out
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
  dashboard = JSON.parse(File.read(ARGV[1]))
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
' /tmp/aiops-e2e-project-dashboard-health.json /tmp/aiops-e2e-project-dashboard.json

"$repo_root/bin/aiops" project dashboard --target "$project" --level compact >/tmp/aiops-e2e-project-dashboard-compact.out
grep -q 'Project: DashboardProject' /tmp/aiops-e2e-project-dashboard-compact.out || {
  printf '%s\n' "compact dashboard project missing" >&2
  exit 1
}
if grep -q '^Settings$' /tmp/aiops-e2e-project-dashboard-compact.out; then
  printf '%s\n' "compact dashboard should omit settings section" >&2
  exit 1
fi

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

empty_project="$tmpdir/empty"
mkdir -p "$empty_project"
"$repo_root/bin/aiops" project dashboard --target "$empty_project" >/tmp/aiops-e2e-project-dashboard-empty.out
grep -q 'Status: BLOCKED' /tmp/aiops-e2e-project-dashboard-empty.out || {
  printf '%s\n' "empty dashboard should be blocked" >&2
  exit 1
}
grep -q 'core_missing' /tmp/aiops-e2e-project-dashboard-empty.out || {
  printf '%s\n' "empty dashboard core blocker missing" >&2
  exit 1
}

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

"$repo_root/bin/aiops" project dashboard --target "$project" --view work --format mermaid --map dependencies --json >/tmp/aiops-e2e-project-dashboard-mermaid-json.json
"$repo_root/bin/aiops" validate project-dashboard /tmp/aiops-e2e-project-dashboard-mermaid-json.json >/tmp/aiops-e2e-project-dashboard-mermaid-json-validate.out
ruby -rjson -e '
  dashboard = JSON.parse(File.read(ARGV[0]))
  abort("mermaid json format missing") unless dashboard["format"] == "mermaid"
  abort("mermaid json map missing") unless dashboard["map"] == "dependencies"
  abort("mermaid json work view missing") unless dashboard["view"] == "work"
  abort("mermaid json map edge missing") unless dashboard.dig("maps", "dependencies", "edges").any? { |edge| edge["type"] == "depends_on" }
' /tmp/aiops-e2e-project-dashboard-mermaid-json.json

before_html_hash="$(find "$project" -type f -not -path '*/.git/*' -print | sort | xargs shasum -a 256 | shasum -a 256 | awk "{print \$1}")"
"$repo_root/bin/aiops" project dashboard --target "$project" --format html --output /tmp/aiops-e2e-project-dashboard.html >/tmp/aiops-e2e-project-dashboard-html.out
"$repo_root/bin/aiops" project dashboard --target "$project" --format html >/tmp/aiops-e2e-project-dashboard-html-stdout.html
"$repo_root/bin/aiops" project dashboard --target "$project" --format html --map agents --output /tmp/aiops-e2e-project-dashboard-agents.html >/tmp/aiops-e2e-project-dashboard-html-agents.out
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
grep -q 'AI Ops Project Dashboard' /tmp/aiops-e2e-project-dashboard.html || {
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
grep -q '초록: ready / done / enabled' /tmp/aiops-e2e-project-dashboard.html || {
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
grep -q 'class="panel map-panel" data-map="dependencies" open' /tmp/aiops-e2e-project-dashboard.html || {
  printf '%s\n' "html dashboard open dependency panel missing" >&2
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
grep -q 'T_T_20260807_001 --&gt; T_T_20260807_002' /tmp/aiops-e2e-project-dashboard.html || {
  printf '%s\n' "html dashboard mermaid dependency edge missing" >&2
  exit 1
}
grep -q 'Mermaid source' /tmp/aiops-e2e-project-dashboard.html || {
  printf '%s\n' "html dashboard mermaid source missing" >&2
  exit 1
}
grep -q '<!doctype html>' /tmp/aiops-e2e-project-dashboard-html-stdout.html || {
  printf '%s\n' "html dashboard stdout doctype missing" >&2
  exit 1
}
grep -q 'Agent / Role Map' /tmp/aiops-e2e-project-dashboard-agents.html || {
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

"$repo_root/bin/aiops" project dashboard --target "$project" --view work --format mermaid --map workflow >/tmp/aiops-e2e-project-dashboard-mermaid-workflow.out
grep -q 'S_proposed --> S_scoped' /tmp/aiops-e2e-project-dashboard-mermaid-workflow.out || {
  printf '%s\n' "workflow mermaid status edge missing" >&2
  exit 1
}
grep -q 'S_rework_requested\["rework_requested"\]' /tmp/aiops-e2e-project-dashboard-mermaid-workflow.out || {
  printf '%s\n' "workflow mermaid rework node missing" >&2
  exit 1
}
grep -q 'T_T_20260807_004\["T-20260807-004' /tmp/aiops-e2e-project-dashboard-mermaid-workflow.out || {
  printf '%s\n' "workflow mermaid task node missing" >&2
  exit 1
}

"$repo_root/bin/aiops" project dashboard --target "$project" --view work --format mermaid --map agents >/tmp/aiops-e2e-project-dashboard-mermaid-agents.out
grep -q 'A_Development_Agent\["Development Agent"\]' /tmp/aiops-e2e-project-dashboard-mermaid-agents.out || {
  printf '%s\n' "agents mermaid agent node missing" >&2
  exit 1
}
grep -q 'R_Execution_Role\["Execution Role"\]' /tmp/aiops-e2e-project-dashboard-mermaid-agents.out || {
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

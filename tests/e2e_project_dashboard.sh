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

if "$repo_root/bin/aiops" project dashboard --target "$project" --view work --format mermaid >/tmp/aiops-e2e-project-dashboard-mermaid.out 2>&1; then
  printf '%s\n' "mermaid dashboard unexpectedly succeeded in phase 3" >&2
  exit 1
fi
grep -q 'planned for a later dashboard phase' /tmp/aiops-e2e-project-dashboard-mermaid.out || {
  printf '%s\n' "mermaid dashboard did not report later phase" >&2
  exit 1
}

printf '%s\n' "ok: project dashboard"

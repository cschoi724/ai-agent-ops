#!/usr/bin/env sh
set -eu

repo_root="$(CDPATH= cd "$(dirname "$0")/.." && pwd)"
tmpdir="$(mktemp -d /tmp/aiops-e2e-agent-aliases.XXXXXX)"
trap 'rm -rf "$tmpdir"' EXIT INT TERM

project="$tmpdir/project"
mkdir -p "$project/.ai_project/tasks/active" "$project/.ai_project/tasks/backlog" \
  "$project/.ai_project/tasks/archive" "$project/.ai_project/reports" "$project/.ai_project/qa" \
  "$project/.ai_project/handoffs"
ln -s "$repo_root" "$project/.ai"

cat > "$project/.ai_project/agent_registry.md" <<'EOF'
---
schema: aiops.agent_registry.v1
project: AgentAliasFixture
agents:
  - id: builder-agent
    agent: Builder Agent
    aliases:
      - Execution Agent
    status: enabled
    team: Development Team
    roles:
      - Execution Role
    capabilities:
      - implementation
  - id: verifier-agent
    agent: Verifier Agent
    aliases:
      - Verification Agent
    status: enabled
    team: Quality Team
    roles:
      - Verification Role
    capabilities:
      - qa
      - validation
---

# Agent Registry
EOF

cat > "$project/.ai_project/source_of_truth.md" <<'EOF'
# Source of Truth
EOF

cat > "$project/.ai_project/tasks/active/T-20260818-101.md" <<'EOF'
---
schema: aiops.task.v1
id: T-20260818-101
title: Stable Agent identity fixture
status: approved
type: feature
priority: medium
workflow: feature
target_agent_id: builder-agent
target_agent: Execution Agent
target_role: Execution Role
required_capabilities:
  - implementation
depends_on: []
blocks: []
allowed_paths:
  - src/
source_of_truth:
  - .ai_project/source_of_truth.md
report_to: .ai_project/reports/T-20260818-101_task-report.md
qa_to: .ai_project/qa/T-20260818-101_qa-report.md
---

# Stable identity fixture
EOF

"$repo_root/bin/aiops" agent inspect --target "$project" --json > "$tmpdir/alias.json"
"$repo_root/bin/aiops" validate agent-identity-audit "$tmpdir/alias.json" >/dev/null
ruby -rjson -e '
  data = JSON.parse(File.read(ARGV[0]))
  abort "alias audit should be ready" unless data["ready"]
  abort "alias reference should require migration" unless data.dig("summary", "migration_required") == 1
  reference = data.fetch("references").find { |entry| entry["task_id"] == "T-20260818-101" }
  abort "alias state missing" unless reference["state"] == "alias"
  abort "Agent ID mismatch" unless reference["resolved_agent_id"] == "builder-agent"
  abort "current display name mismatch" unless reference["resolved_agent"] == "Builder Agent"
' "$tmpdir/alias.json"

"$repo_root/bin/aiops" project snapshot --target "$project" --json > "$tmpdir/snapshot.json"
"$repo_root/bin/aiops" validate project-snapshot "$tmpdir/snapshot.json" >/dev/null
ruby -rjson -e '
  data = JSON.parse(File.read(ARGV[0]))
  task = data.fetch("tasks").fetch("items").find { |entry| entry["id"] == "T-20260818-101" }
  abort "snapshot lost stable Agent ID" unless task["target_agent_id"] == "builder-agent"
  abort "snapshot did not project current Agent name" unless task["target_agent"] == "Builder Agent"
' "$tmpdir/snapshot.json"

"$repo_root/bin/aiops" project dashboard --target "$project" --json > "$tmpdir/dashboard.json"
"$repo_root/bin/aiops" validate project-dashboard "$tmpdir/dashboard.json" >/dev/null
ruby -rjson -e '
  data = JSON.parse(File.read(ARGV[0]))
  task = data.dig("tasks", "items").find { |entry| entry["id"] == "T-20260818-101" }
  abort "dashboard lost stable Agent ID" unless task["target_agent_id"] == "builder-agent"
  abort "dashboard did not project current Agent name" unless task["target_agent"] == "Builder Agent"
' "$tmpdir/dashboard.json"

"$repo_root/bin/aiops" task accept T-20260818-101 --target "$project" --check --json > "$tmpdir/plan.json"
"$repo_root/bin/aiops" validate task-transition-plan "$tmpdir/plan.json" >/dev/null
ruby -rjson -e '
  data = JSON.parse(File.read(ARGV[0]))
  abort "actor ID missing" unless data.dig("actor", "agent_id") == "builder-agent"
  abort "actor display name was not refreshed" unless data.dig("actor", "agent") == "Builder Agent"
  abort "next ID missing" unless data.dig("next", "agent_id") == "builder-agent"
' "$tmpdir/plan.json"

perl -0pi -e 's/agent: Builder Agent/agent: Build Platform Agent/' "$project/.ai_project/agent_registry.md"
perl -0pi -e 's/      - Execution Agent/      - Execution Agent\n      - Builder Agent/' "$project/.ai_project/agent_registry.md"
"$repo_root/bin/aiops" project snapshot --target "$project" --json > "$tmpdir/renamed-snapshot.json"
ruby -rjson -e '
  data = JSON.parse(File.read(ARGV[0]))
  task = data.fetch("tasks").fetch("items").find { |entry| entry["id"] == "T-20260818-101" }
  abort "renamed snapshot did not use current Agent name" unless task["target_agent"] == "Build Platform Agent"
' "$tmpdir/renamed-snapshot.json"
"$repo_root/bin/aiops" task accept T-20260818-101 --target "$project" --check --json > "$tmpdir/renamed-plan.json"
ruby -rjson -e '
  data = JSON.parse(File.read(ARGV[0]))
  abort "renamed Agent ID changed" unless data.dig("actor", "agent_id") == "builder-agent"
  abort "renamed display name missing" unless data.dig("actor", "agent") == "Build Platform Agent"
' "$tmpdir/renamed-plan.json"

cat > "$project/.ai_project/reports/T-20260818-101_task-report.md" <<'EOF'
# Task report
EOF
perl -0pi -e 's/status: approved/status: in_progress/; s/locked_by:/locked_by: Execution Agent/' \
  "$project/.ai_project/tasks/active/T-20260818-101.md"
"$repo_root/bin/aiops" task advance T-20260818-101 --target "$project" --check --json \
  --evidence .ai_project/reports/T-20260818-101_task-report.md > "$tmpdir/renamed-handoff-plan.json"
ruby -rjson -e '
  data = JSON.parse(File.read(ARGV[0]))
  abort "renamed lock owner was not recognized" unless data.dig("actor", "agent") == "Build Platform Agent"
  abort "renamed actor ID changed" unless data.dig("actor", "agent_id") == "builder-agent"
  abort "receiver display name mismatch" unless data.dig("next", "agent") == "Verifier Agent"
  abort "receiver ID mismatch" unless data.dig("next", "agent_id") == "verifier-agent"
' "$tmpdir/renamed-handoff-plan.json"

perl -0pi -e 's/target_agent: Execution Agent/target_agent: Verifier Agent/' \
  "$project/.ai_project/tasks/active/T-20260818-101.md"
if "$repo_root/bin/aiops" task advance T-20260818-101 --target "$project" --check \
  --evidence .ai_project/reports/T-20260818-101_task-report.md > "$tmpdir/mismatch.out" 2>&1; then
  printf '%s\n' "lifecycle accepted mismatched Agent ID and display name" >&2
  exit 1
fi
grep -q 'target_agent_id builder-agent does not match target_agent Verifier Agent' "$tmpdir/mismatch.out"

cp "$project/.ai_project/agent_registry.md" "$tmpdir/registry-valid.md"
perl -0pi -e 's/      - Builder Agent/      - Builder Agent\n      - Builder Agent/' "$project/.ai_project/agent_registry.md"
if "$repo_root/bin/aiops" agent inspect --target "$project" --json > "$tmpdir/invalid-alias.json"; then
  printf '%s\n' "Agent inspection accepted duplicate aliases" >&2
  exit 1
fi
grep -q 'agent_aliases_invalid' "$tmpdir/invalid-alias.json"
mv "$tmpdir/registry-valid.md" "$project/.ai_project/agent_registry.md"

perl -0pi -e 's/      - Verification Agent/      - Verification Agent\n      - Builder Agent/' "$project/.ai_project/agent_registry.md"
if "$repo_root/bin/aiops" agent inspect --target "$project" --json > "$tmpdir/collision.json"; then
  printf '%s\n' "Agent inspection accepted an alias collision" >&2
  exit 1
fi
grep -q 'agent_identity_collision' "$tmpdir/collision.json"

printf '%s\n' "ok: Agent identity ID and alias compatibility"

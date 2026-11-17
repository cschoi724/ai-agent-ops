#!/usr/bin/env sh
set -eu

repo_root="$(CDPATH= cd "$(dirname "$0")/.." && pwd)"
aiops="$repo_root/bin/aiops"
tmpdir="$(mktemp -d /tmp/aiops-e2e-operator-contract.XXXXXX)"
trap 'rm -rf "$tmpdir"' EXIT INT TERM

fail() {
  printf '%s\n' "$1" >&2
  exit 1
}

expect_fail() {
  label="$1"
  pattern="$2"
  shift 2
  if "$@" > "$tmpdir/out.txt" 2>&1; then
    fail "$label: expected failure"
  fi
  grep -q -- "$pattern" "$tmpdir/out.txt" || {
    cat "$tmpdir/out.txt" >&2
    fail "$label: missing message '$pattern'"
  }
}

project="$tmpdir/project"
mkdir -p \
  "$project/.ai_project/tasks/active" \
  "$project/.ai_project/tasks/backlog" \
  "$project/.ai_project/tasks/archive" \
  "$project/.ai_project/reports" \
  "$project/.ai_project/qa" \
  "$project/.ai_project/handoffs"
ln -s "$repo_root" "$project/.ai"

cat > "$project/.ai_project/agent_registry.md" <<'EOF'
---
schema: aiops.agent_registry.v1
project: OperatorFixture
agents:
  - agent: Lead Agent
    status: enabled
    provider: claude-code
    runtime: session
    team: Product Team
    roles:
      - Lead Role
      - Direction Role
      - Completion Role
      - Operator Role
    capabilities:
      - planning
      - priority_management
      - completion_review
  - agent: Dev Agent
    status: enabled
    provider: claude-code
    runtime: subagent
    team: Development Team
    roles:
      - Execution Role
    capabilities:
      - implementation
  - agent: QA Agent
    status: enabled
    provider: codex
    runtime: subagent
    team: Quality Team
    roles:
      - Verification Role
    capabilities:
      - qa_review
  - agent: Hands-on Operator
    status: enabled
    team: Development Team
    roles:
      - Execution Role
      - Operator Role
    capabilities:
      - implementation
---

# Agent Registry
EOF

printf '# Source of Truth\n' > "$project/.ai_project/source_of_truth.md"

write_task() {
  task_id="$1"
  status="$2"
  agent="$3"
  role="$4"
  cat > "$project/.ai_project/tasks/active/$task_id.md" <<EOF
---
schema: aiops.task.v1
id: $task_id
title: Operator contract fixture
status: $status
type: feature
priority: medium
workflow: feature
team: Development Team
target_agent: $agent
target_role: $role
required_capabilities:
  - implementation
depends_on: []
blocks: []
allowed_paths:
  - src/
source_of_truth:
  - .ai_project/source_of_truth.md
approved_by:
locked_by:
locked_at:
lock_session:
updated_at: 2026-11-17
report_to: .ai_project/reports/${task_id}_task-report.md
qa_to: .ai_project/qa/${task_id}_qa-report.md
---

# Operator contract fixture
EOF
}

# --- dispatcher must hold Operator Role ---
task="T-20261117-001"
write_task "$task" scoped "Lead Agent" "Lead Role"
expect_fail "dispatcher without Operator Role" "does not have Operator Role" \
  "$aiops" task advance "$task" --target "$project" --dispatched-by "Dev Agent" --next-agent "Dev Agent" --owner-approved --check
expect_fail "unknown dispatcher" "dispatcher is not registered" \
  "$aiops" task advance "$task" --target "$project" --dispatched-by "Ghost Agent" --next-agent "Dev Agent" --owner-approved --check

# --- Operator-driven approval needs the Owner ---
expect_fail "approval without Owner" "Owner approval required" \
  "$aiops" task advance "$task" --target "$project" --dispatched-by "Lead Agent" --next-agent "Dev Agent" --check

"$aiops" task advance "$task" --target "$project" --dispatched-by "Lead Agent" --next-agent "Dev Agent" \
  --owner-approved --json > "$tmpdir/approve.json"
"$aiops" validate task-transition-plan "$tmpdir/approve.json" >/dev/null || fail "approve plan failed schema validation"
task_file="$project/.ai_project/tasks/active/$task.md"
grep -q '^status: approved$' "$task_file" || fail "task not approved"
grep -q '^approved_by: owner$' "$task_file" || fail "approved_by owner not recorded"
receipt="$(ruby -rjson -e 'puts JSON.parse(File.read(ARGV[0])).dig("receipt", "receipt_path")' "$tmpdir/approve.json")"
"$aiops" validate transition-receipt "$project/$receipt" >/dev/null || fail "receipt failed schema validation"
ruby -rjson -e '
  data = JSON.parse(File.read(ARGV[0]))
  abort "dispatched_by missing" unless data["dispatched_by"] == { "agent" => "Lead Agent", "role" => "Operator Role" }
  abort "owner_approved missing" unless data["owner_approved"] == true
  abort "actor should be the Role Agent, not the Operator label" unless data.dig("actor", "role") == "Lead Role"
' "$project/$receipt" || fail "receipt dispatch fields wrong"
handoff="$project/.ai_project/handoffs/${task}_lead_to_execution.md"
[ -f "$handoff" ] || handoff="$(ls "$project/.ai_project/handoffs/${task}_"*.md | head -1)"
grep -q '^dispatched_by: Lead Agent$' "$handoff" || fail "handoff missing dispatched_by"
"$aiops" validate handoff "$handoff" >/dev/null || fail "handoff failed validation"

# --- dispatched Execution work runs as the Execution Agent ---
"$aiops" task accept "$task" --target "$project" --dispatched-by "Lead Agent" --json > "$tmpdir/accept.json"
grep -q '^locked_by: Dev Agent$' "$task_file" || fail "Execution accept did not lock for Dev Agent"
grep -q '진행 지시\|"dispatched_by"' "$tmpdir/accept.json" || fail "accept plan missing dispatch"

# --- Operator never performs or receives Execution / Verification work ---
task2="T-20261117-002"
write_task "$task2" approved "Hands-on Operator" "Execution Role"
expect_fail "operator performing execution" "cannot perform Execution Role work" \
  "$aiops" task accept "$task2" --target "$project" --dispatched-by "Hands-on Operator" --check

task3="T-20261117-003"
write_task "$task3" scoped "Lead Agent" "Lead Role"
expect_fail "operator receiving execution" "cannot receive Execution Role work" \
  "$aiops" task advance "$task3" --target "$project" --dispatched-by "Hands-on Operator" --next-agent "Hands-on Operator" --owner-approved --check

# --- --owner-approved is only for transitions into approved ---
expect_fail "owner flag on wrong transition" "only applies to transitions into approved" \
  "$aiops" task accept "$task2" --target "$project" --owner-approved --check

# --- terminal output explains dispatch ---
"$aiops" task advance "$task3" --target "$project" --dispatched-by "Lead Agent" --next-agent "Dev Agent" --owner-approved --check > "$tmpdir/terminal.out"
grep -q '진행 지시: Lead Agent / Operator Role' "$tmpdir/terminal.out" || fail "terminal output missing dispatch line"
grep -q 'Owner 승인: 기록됨' "$tmpdir/terminal.out" || fail "terminal output missing Owner approval line"

# --- Registry rules: Owner Role is user-only, Operator Role is additive, provider/runtime enums ---
strict="$tmpdir/strict"
mkdir -p "$strict"
"$aiops" seed --target "$strict" --adapter both --mode link --core "$repo_root" --no-tool-extras >/dev/null
cp -R "$repo_root/templates/ai_project/fast_track" "$strict/.ai_project"
perl -0pi -e 's/\{\{START_CONTEXT\}\}/ops_setup_only/g; s/\{\{READINESS_LEVEL\}\}/ops_only/g' "$strict/.ai_project/operating_model.md"
mkdir -p "$strict/.ai_project/tasks/active" "$strict/.ai_project/tasks/backlog" "$strict/.ai_project/tasks/archive" "$strict/.ai_project/handoffs"
"$aiops" validate --target "$strict" --strict >/dev/null || fail "baseline strict project should validate"
cp "$strict/.ai_project/agent_registry.md" "$tmpdir/registry.orig"

add_agent() {
  ruby -ryaml -e '
    path, entry = ARGV
    text = File.read(path)
    _, front, body = text.split(/^---\n/, 3)
    data = YAML.safe_load(front)
    data["agents"] << YAML.safe_load(entry)
    File.write(path, YAML.dump(data) + "---\n" + body)
  ' "$strict/.ai_project/agent_registry.md" "$1"
}

add_agent '{"agent": "Owner Agent", "status": "enabled", "roles": ["Owner Role", "Lead Role"], "capabilities": ["planning"]}'
expect_fail "Owner Role registered" "Owner Role belongs only to the user" "$aiops" validate --target "$strict" --strict
cp "$tmpdir/registry.orig" "$strict/.ai_project/agent_registry.md"

add_agent '{"agent": "Bare Operator", "status": "enabled", "roles": ["Operator Role"], "capabilities": ["planning"]}'
expect_fail "Operator Role alone" "Operator Role is a permission added to an existing Role" "$aiops" validate --target "$strict" --strict
cp "$tmpdir/registry.orig" "$strict/.ai_project/agent_registry.md"

add_agent '{"agent": "Odd Provider", "status": "enabled", "provider": "vim", "roles": ["Lead Role"], "capabilities": ["planning"]}'
expect_fail "invalid provider" "invalid agents\[[0-9]*\].provider vim" "$aiops" validate --target "$strict" --strict
cp "$tmpdir/registry.orig" "$strict/.ai_project/agent_registry.md"

add_agent '{"agent": "Good Operator", "status": "enabled", "provider": "codex", "runtime": "session", "roles": ["Lead Role", "Operator Role"], "capabilities": ["planning"]}'
"$aiops" validate --target "$strict" --strict >/dev/null || fail "valid Operator registry should pass strict validation"

printf '%s\n' "ok: operator contract"

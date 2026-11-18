#!/usr/bin/env sh
set -eu

repo_root="$(CDPATH= cd "$(dirname "$0")/.." && pwd)"
aiops="$repo_root/bin/aiops"
tmpdir="$(mktemp -d /tmp/aiops-e2e-orchestrate.XXXXXX)"
trap 'rm -rf "$tmpdir"' EXIT INT TERM

fail() {
  printf '%s\n' "$1" >&2
  exit 1
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
printf '# Source of Truth\n' > "$project/.ai_project/source_of_truth.md"

cat > "$project/.ai_project/agent_registry.md" <<'EOF'
---
schema: aiops.agent_registry.v1
project: OrchestrateFixture
agents:
  - agent: Lead Agent
    status: enabled
    runtime: session
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
    runtime: subagent
    roles:
      - Execution Role
    capabilities:
      - implementation
  - agent: QA Agent
    status: enabled
    runtime: subagent
    roles:
      - Verification Role
    capabilities:
      - qa_review
---

# Agent Registry
EOF

task="T-20261117-001"
task_file="$project/.ai_project/tasks/active/$task.md"
cat > "$task_file" <<EOF
---
schema: aiops.task.v1
id: $task
title: Login retry
status: scoped
type: feature
priority: medium
workflow: feature
team: Development Team
target_agent: Lead Agent
target_role: Lead Role
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
report_to: .ai_project/reports/${task}_task-report.md
qa_to: .ai_project/qa/${task}_qa-report.md
---

# Login retry
EOF

plan() {
  "$aiops" orchestrate plan "$task" --target "$project" --operator "Lead Agent" --json > "$tmpdir/plan.json"
  "$aiops" validate orchestration-plan "$tmpdir/plan.json" >/dev/null || {
    cat "$tmpdir/plan.json" >&2
    fail "orchestration plan failed schema validation"
  }
}

field() {
  ruby -rjson -e 'value = ARGV[1].split(".").reduce(JSON.parse(File.read(ARGV[0]))) { |data, key| data.is_a?(Hash) ? data[key] : nil }; puts value.nil? ? "" : value' "$tmpdir/plan.json" "$1"
}

expect_state() {
  plan
  state="$(field state)"
  [ "$state" = "$1" ] || {
    cat "$tmpdir/plan.json" >&2
    fail "expected plan state $1 at status $(field status), got $state"
  }
}

# Run an argv array from the plan (key: next.argv, next.on_pass, next.on_fail) the way the Operator would.
run_step() {
  key="$1"
  shift
  ruby -rjson -e '
    plan = JSON.parse(File.read(ARGV[0]))
    argv = ARGV[1].split(".").reduce(plan) { |data, part| data[part] }
    abort "plan has no #{ARGV[1]}" unless argv.is_a?(Array)
    argv = argv.drop(1)
    argv[-1] = ARGV[3] if !ARGV[3].to_s.empty? && argv.last.start_with?("<")
    argv += ["--target", ARGV[2]]
    File.write(ARGV[4], argv.join("\0"))
  ' "$tmpdir/plan.json" "$key" "$project" "${1:-}" "$tmpdir/argv"
  xargs -0 "$aiops" < "$tmpdir/argv" > "$tmpdir/step.out" 2>&1 || {
    cat "$tmpdir/step.out" >&2
    fail "step $key failed at status $(field status)"
  }
}

status() {
  sed -n 's/^status: //p' "$task_file" | head -1
}

# --- the first operated session asks the Owner how to proceed ---
expect_state needs_owner
field reason | grep -q 'aiops:operated-session-consent' || fail "first run did not ask for Owner consent"
printf '# Ops Decisions\n\n- aiops:operated-session-consent commit=task_branch rework_limit=1\n' > "$project/.ai_project/ops_decisions.md"

# --- the operator without Operator Role is rejected ---
if "$aiops" orchestrate plan "$task" --target "$project" --operator "Dev Agent" --json >/dev/null 2>&1; then
  fail "plan accepted an operator without Operator Role"
fi

# --- Owner approval gate ---
expect_state needs_owner
[ "$(field next.requires_owner_approval)" = "true" ] || fail "scoped Task did not require Owner approval"
field next.argv | grep -q -- '--owner-approved' || fail "plan argv missing --owner-approved"
[ "$(field next.owner_command | tr "\n" " ")" = "aiops approve 001 " ] || fail "plan should offer the short Owner command"
"$aiops" orchestrate plan "$task" --target "$project" --operator "Lead Agent" | grep -q '! aiops approve 001' || fail "plan output should show the short Owner command"
# The Owner's short command: no Task ID needed when only one Task waits; runs from a subfolder.
mkdir -p "$project/src/deep"
(cd "$project/src/deep" && "$aiops" approve) > "$tmpdir/approve.out" 2>&1 || { cat "$tmpdir/approve.out" >&2; fail "aiops approve failed"; }
grep -q "Owner 승인: $task" "$tmpdir/approve.out" || fail "aiops approve did not show the Task"
[ "$(status)" = "approved" ] || fail "aiops approve did not approve the Task"
(cd "$project" && "$aiops" approve) > "$tmpdir/approve.out" 2>&1 || fail "aiops approve with nothing waiting should succeed"
grep -q '승인을 기다리는 Task가 없습니다' "$tmpdir/approve.out" || fail "aiops approve should say nothing is waiting"
if "$aiops" approve 001 --target "$project" >/dev/null 2>&1; then
  fail "aiops approve accepted a Task that is not waiting for approval"
fi
grep -q '^approved_by: owner$' "$task_file" || fail "approved_by owner missing"

cycle_to_verification() {
  expect_state ready
  [ "$(field next.subagent)" = "aiops-execution" ] || fail "approved Task should go to aiops-execution"
  run_step next.argv
  [ "$(status)" = "in_progress" ] || fail "Execution accept failed"

  expect_state work_required
  [ "$(field next.subagent)" = "aiops-execution" ] || fail "in_progress work should go to aiops-execution"
  printf '# Task Report\n\nImplemented retry.\n' > "$project/.ai_project/reports/${task}_task-report.md"
  run_step next.argv
  [ "$(status)" = "verification_ready" ] || fail "Execution advance failed"

  expect_state ready
  [ "$(field next.agent)" = "QA Agent" ] || fail "verification should be accepted by QA Agent"
  run_step next.argv
  [ "$(status)" = "verification_in_progress" ] || fail "Verification accept failed"

  expect_state work_required
  [ "$(field next.subagent)" = "aiops-verification" ] || fail "verification work should go to aiops-verification"
}

# --- first verification fails: automatic rework within the default limit (1) ---
cycle_to_verification
run_step next.on_fail "retry count off by one"
[ "$(status)" = "rework_requested" ] || fail "verification failure did not request rework"
expect_state ready
[ "$(field rework.count)" = "1" ] || fail "rework count should be 1"
[ "$(field next.subagent)" = "aiops-lead" ] || fail "rework should go to aiops-lead"
run_step next.argv
[ "$(status)" = "scoped" ] || fail "rework did not return to scoped"
expect_state ready
[ "$(field next.requires_owner_approval)" = "false" ] || fail "rework within limit should keep the Owner approval"
run_step next.argv
[ "$(status)" = "approved" ] || fail "re-approval within limit failed"

# --- second failure exceeds the limit: the Owner decides ---
cycle_to_verification
run_step next.on_fail "still failing"
expect_state ready
run_step next.argv
[ "$(status)" = "scoped" ] || fail "second rework did not return to scoped"
expect_state needs_owner
field reason | grep -q 'rework limit 1 reached (2 reworks)' || fail "plan did not stop at the rework limit"
if "$aiops" task advance "$task" --target "$project" --dispatched-by "Lead Agent" >/dev/null 2>"$tmpdir/limit.err"; then
  fail "lifecycle allowed re-approval past the rework limit without the Owner"
fi
grep -q 'rework limit 1 reached' "$tmpdir/limit.err" || fail "lifecycle did not explain the rework limit"
# A hand-edited rework_limit does not raise the limit; only Owner-approved receipts do.
sed -i.bak 's/^rework_limit: .*/rework_limit: 99/' "$task_file"
grep -q '^rework_limit: 99$' "$task_file" || fail "fixture did not forge rework_limit"
if "$aiops" task advance "$task" --target "$project" --dispatched-by "Lead Agent" >/dev/null 2>&1; then
  fail "forged rework_limit let the Task past the limit"
fi
mv "$task_file.bak" "$task_file"
expect_state needs_owner
"$aiops" approve 001 --target "$project" > "$tmpdir/approve.out" 2>&1 || { cat "$tmpdir/approve.out" >&2; fail "aiops approve by suffix failed"; }
[ "$(status)" = "approved" ] || fail "Owner re-approval failed"
grep -q '^rework_limit: 2$' "$task_file" || fail "Owner re-approval did not raise rework_limit"

# --- verification passes and the Task completes ---
cycle_to_verification
printf '# QA Report\n\nPASS\n' > "$project/.ai_project/qa/${task}_qa-report.md"
run_step next.on_pass
[ "$(status)" = "verification_passed" ] || fail "verification pass failed"
expect_state ready
[ "$(field next.subagent)" = "aiops-completion" ] || fail "completion should go to aiops-completion"
run_step next.argv
expect_state ready
run_step next.argv
[ "$(status)" = "done" ] || fail "Task did not reach done"
expect_state done

# --- every lifecycle receipt records the Operator ---
ruby -rjson -e '
  receipts = Dir.glob(File.join(ARGV[0], ".ai_project/reports/*-transition-receipt.json")).map { |path| JSON.parse(File.read(path)) }
  abort "no receipts" if receipts.empty?
  missing = receipts.reject { |receipt| receipt.dig("dispatched_by", "agent") == "Lead Agent" }
  abort "receipts without dispatched_by: #{missing.map { |r| r["transition"] }}" unless missing.empty?
  separated = receipts.select { |receipt| ["Execution Role", "Verification Role"].include?(receipt.dig("actor", "role")) }
  abort "Operator acted as Execution or Verification" if separated.any? { |receipt| receipt.dig("actor", "agent") == "Lead Agent" }
' "$project" || fail "receipt audit failed"

printf '%s\n' "ok: orchestrate"

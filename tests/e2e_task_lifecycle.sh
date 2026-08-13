#!/usr/bin/env sh
set -eu

repo_root="$(CDPATH= cd "$(dirname "$0")/.." && pwd)"
tmpdir="$(mktemp -d /tmp/aiops-e2e-task-lifecycle.XXXXXX)"
trap 'rm -rf "$tmpdir"' EXIT INT TERM

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
project: LifecycleFixture
agents:
  - agent: Lead Agent
    status: enabled
    team: Product Team
    roles:
      - Lead Role
      - Direction Role
      - Completion Role
    capabilities:
      - planning
      - priority_management
      - completion_review
  - agent: Dev Agent
    status: enabled
    team: Development Team
    roles:
      - Execution Role
    capabilities:
      - implementation
      - developer_verification
  - agent: QA Agent
    status: enabled
    team: Quality Team
    roles:
      - Verification Role
    capabilities:
      - qa_review
      - test_execution
  - agent: Empty QA Agent
    status: enabled
    team: Quality Team
    roles:
      - Verification Role
    capabilities: []
---

# Agent Registry
EOF

cat > "$project/.ai_project/source_of_truth.md" <<'EOF'
# Source of Truth
EOF

cat > "$project/.ai_project/task_board.md" <<'EOF'
# Project Task Board

## Current Focus

| Priority | Task | Status | Role | Team | Next |
|---|---|---|---|---|---|
EOF

write_task() {
  task_id="$1"
  status="$2"
  agent="$3"
  role="$4"
  source="$5"
  dependency="${6:-}"
  cat > "$project/.ai_project/tasks/active/$task_id.md" <<EOF
---
schema: aiops.task.v1
id: $task_id
title: Lifecycle automation fixture
status: $status
type: feature
priority: medium
workflow: feature
team: Development Team
target_agent: $agent
target_role: $role
required_capabilities:
  - implementation
depends_on:$(if [ -n "$dependency" ]; then printf '\n  - %s' "$dependency"; else printf ' []'; fi)
blocks: []
allowed_paths:
  - src/
source_of_truth:
  - $source
locked_by:
locked_at:
lock_session:
updated_at: 2026-08-13
report_to: .ai_project/reports/${task_id}_task-report.md
qa_to: .ai_project/qa/${task_id}_qa-report.md
status_ref:
status_ref_sha:
base_ref:
base_sha:
---

# Lifecycle automation fixture
EOF
}

task_id="T-20260813-001"
write_task "$task_id" approved "Dev Agent" "Execution Role" .ai_project/source_of_truth.md
task_file="$project/.ai_project/tasks/active/$task_id.md"

before_check="$(shasum -a 256 "$task_file" | awk '{print $1}')"
"$repo_root/bin/aiops" task accept "$task_id" --target "$project" --check --json > "$tmpdir/accept-check.json"
after_check="$(shasum -a 256 "$task_file" | awk '{print $1}')"
[ "$before_check" = "$after_check" ] || {
  printf '%s\n' "task accept --check mutated Task" >&2
  exit 1
}
"$repo_root/bin/aiops" validate task-transition-plan "$tmpdir/accept-check.json" >/dev/null
grep -q '"check_only": true' "$tmpdir/accept-check.json"
grep -q '"to": "in_progress"' "$tmpdir/accept-check.json"
ruby -rjson -e '
  data = JSON.parse(File.read(ARGV[0]))
  data.delete("actor")
  File.write(ARGV[1], JSON.pretty_generate(data))
' "$tmpdir/accept-check.json" "$tmpdir/invalid-plan.json"
if "$repo_root/bin/aiops" validate task-transition-plan "$tmpdir/invalid-plan.json" >/dev/null 2>&1; then
  printf '%s\n' "transition plan without actor should fail validation" >&2
  exit 1
fi

"$repo_root/bin/aiops" task accept "$task_id" --target "$project" --json > "$tmpdir/accept.json"
grep -q '^status: in_progress$' "$task_file"
grep -q '^locked_by: Dev Agent$' "$task_file"
grep -q 'aiops:lifecycle T-20260813-001' "$project/.ai_project/task_board.md"
"$repo_root/bin/aiops" validate task-transition-plan "$tmpdir/accept.json" >/dev/null
"$repo_root/bin/aiops" validate transition-receipt "$project/.ai_project/reports/$task_id-transition-receipt.json" >/dev/null

cat > "$project/.ai_project/reports/${task_id}_task-report.md" <<'EOF'
# Task Report

Implementation and self-check passed.
EOF

if "$repo_root/bin/aiops" task advance "$task_id" \
  --target "$project" --check >"$tmpdir/ambiguous-receiver.out" 2>&1; then
  printf '%s\n' "ambiguous receiver should block task advance" >&2
  exit 1
fi
grep -q 'cannot choose next Verification Role Agent' "$tmpdir/ambiguous-receiver.out"
if "$repo_root/bin/aiops" task advance "$task_id" \
  --target "$project" --next-agent "Unknown Agent" --check >"$tmpdir/unknown-receiver.out" 2>&1; then
  printf '%s\n' "unknown receiver should block task advance" >&2
  exit 1
fi
grep -q 'next Agent is not registered' "$tmpdir/unknown-receiver.out"

"$repo_root/bin/aiops" task advance "$task_id" \
  --target "$project" \
  --next-agent "QA Agent" \
  --summary "Implementation ready for verification" \
  --json > "$tmpdir/verification-ready.json"
grep -q '^status: verification_ready$' "$task_file"
grep -q '^target_agent: QA Agent$' "$task_file"
grep -q '^target_role: Verification Role$' "$task_file"
grep -q '^locked_by:$' "$task_file"
handoff="$project/.ai_project/handoffs/${task_id}_execution_to_verification.md"
[ -f "$handoff" ]
"$repo_root/bin/aiops" validate handoff "$handoff" --strict >/dev/null

"$repo_root/bin/aiops" task accept "$task_id" --target "$project" >/dev/null
grep -q '^status: verification_in_progress$' "$task_file"
grep -q '^locked_by: QA Agent$' "$task_file"

cat > "$project/.ai_project/qa/${task_id}_qa-report.md" <<'EOF'
# QA Report

Independent verification passed.
EOF

"$repo_root/bin/aiops" task advance "$task_id" \
  --target "$project" \
  --next-agent "Lead Agent" >/dev/null
grep -q '^status: verification_passed$' "$task_file"
grep -q '^target_agent: Lead Agent$' "$task_file"

"$repo_root/bin/aiops" task accept "$task_id" --target "$project" >/dev/null
grep -q '^status: completion_review$' "$task_file"
"$repo_root/bin/aiops" task advance "$task_id" --target "$project" >/dev/null
grep -q '^status: done$' "$task_file"
grep -q '^target_agent:$' "$task_file"
grep -q '^target_role:$' "$task_file"
"$repo_root/bin/aiops" validate task "$task_file" --strict >/dev/null

write_task T-20260813-002 in_progress "Dev Agent" "Execution Role" missing/source.md
if "$repo_root/bin/aiops" task advance T-20260813-002 --target "$project" --next-agent "QA Agent" --check >"$tmpdir/missing-source.out" 2>&1; then
  printf '%s\n' "missing source should block task advance" >&2
  exit 1
fi
grep -q 'source_of_truth path missing' "$tmpdir/missing-source.out"

write_task T-20260813-003 in_progress "Dev Agent" "Execution Role" .ai_project/source_of_truth.md
cat > "$project/.ai_project/reports/T-20260813-003_task-report.md" <<'EOF'
# Task Report
EOF
if "$repo_root/bin/aiops" task advance T-20260813-003 --target "$project" --next-agent "Empty QA Agent" --check >"$tmpdir/missing-capability.out" 2>&1; then
  printf '%s\n' "receiver without capabilities should block task advance" >&2
  exit 1
fi
grep -q 'has no declared capabilities' "$tmpdir/missing-capability.out"

write_task T-20260813-004 approved "Dev Agent" "Execution Role" .ai_project/source_of_truth.md T-20260813-005
write_task T-20260813-005 in_progress "Dev Agent" "Execution Role" .ai_project/source_of_truth.md
if "$repo_root/bin/aiops" task accept T-20260813-004 --target "$project" --check >"$tmpdir/dependency.out" 2>&1; then
  printf '%s\n' "incomplete dependency should block task accept" >&2
  exit 1
fi
grep -q 'dependency T-20260813-005 is not complete' "$tmpdir/dependency.out"

write_task T-20260813-006 approved "Dev Agent" "Execution Role" .ai_project/source_of_truth.md
rollback_task="$project/.ai_project/tasks/active/T-20260813-006.md"
rollback_board="$project/.ai_project/task_board.md"
cp "$rollback_task" "$tmpdir/rollback-task.before"
cp "$rollback_board" "$tmpdir/rollback-board.before"
if AIOPS_TEST_LIFECYCLE_FAIL=after_first_write \
  "$repo_root/bin/aiops" task accept T-20260813-006 --target "$project" >"$tmpdir/rollback.out" 2>&1; then
  printf '%s\n' "injected write failure should fail" >&2
  exit 1
fi
cmp -s "$rollback_task" "$tmpdir/rollback-task.before"
cmp -s "$rollback_board" "$tmpdir/rollback-board.before"
[ ! -f "$project/.ai_project/reports/T-20260813-006-transition-receipt.json" ]

write_task T-20260813-007 approved "Dev Agent" "Execution Role" .ai_project/source_of_truth.md
git init -b main "$project" >/dev/null
git -C "$project" config user.email "aiops@example.test"
git -C "$project" config user.name "AI Ops Test"
git -C "$project" add .
git -C "$project" commit -m "seed concurrent lifecycle fixture" >/dev/null
other_worktree="$tmpdir/other-worktree"
git -C "$project" worktree add -b concurrent-lifecycle "$other_worktree" >/dev/null
AIOPS_TEST_LIFECYCLE_HOLD_SECONDS=2 \
  "$repo_root/bin/aiops" task accept T-20260813-007 --target "$project" --check >"$tmpdir/holder.out" 2>&1 &
holder_pid=$!
sleep 1
if "$repo_root/bin/aiops" task accept T-20260813-007 --target "$other_worktree" --check >"$tmpdir/concurrent.out" 2>&1; then
  printf '%s\n' "concurrent transition should fail" >&2
  kill "$holder_pid" 2>/dev/null || true
  exit 1
fi
grep -q 'another worktree or process' "$tmpdir/concurrent.out"
wait "$holder_pid"

cat > "$project/outside.txt" <<'EOF'
base content
EOF
git -C "$project" add outside.txt
git -C "$project" commit -m "seed allowed path guard" >/dev/null
allowed_base="$(git -C "$project" rev-parse HEAD)"
write_task T-20260813-009 approved "Dev Agent" "Execution Role" .ai_project/source_of_truth.md
perl -0pi -e "s/base_sha:/base_sha: $allowed_base/" "$project/.ai_project/tasks/active/T-20260813-009.md"
cat > "$project/outside.txt" <<'EOF'
changed outside Task scope
EOF
if "$repo_root/bin/aiops" task accept T-20260813-009 \
  --target "$project" --check >"$tmpdir/outside-path.out" 2>&1; then
  printf '%s\n' "changed path outside allowed_paths should block task accept" >&2
  exit 1
fi
grep -q 'changed paths outside Task allowed_paths: outside.txt' "$tmpdir/outside-path.out"

canonical="$tmpdir/canonical-project"
remote="$tmpdir/canonical.git"
integrator="$tmpdir/integrator"
git init --bare --initial-branch=main "$remote" >/dev/null
git init -b main "$canonical" >/dev/null
git -C "$canonical" config user.email "aiops@example.test"
git -C "$canonical" config user.name "AI Ops Test"
git -C "$canonical" remote add origin "$remote"
ln -s "$repo_root" "$canonical/.ai"
mkdir -p "$canonical/.ai_project/tasks/active" "$canonical/.ai_project/reports" "$canonical/.ai_project/qa" "$canonical/.ai_project/handoffs"
cp "$project/.ai_project/agent_registry.md" "$canonical/.ai_project/agent_registry.md"
cp "$project/.ai_project/source_of_truth.md" "$canonical/.ai_project/source_of_truth.md"
cp "$project/.ai_project/task_board.md" "$canonical/.ai_project/task_board.md"
cat > "$canonical/.ai_project/operating_model.md" <<'EOF'
---
schema: aiops.operating_model.v1
project: LifecycleCanonicalFixture
canonical_status_ref: origin/main
---
EOF
cat > "$canonical/.ai_project/tasks/active/T-20260813-008.md" <<'EOF'
---
schema: aiops.task.v1
id: T-20260813-008
title: Canonical lifecycle guard
status: in_progress
type: feature
priority: medium
workflow: feature
team: Development Team
target_agent: Dev Agent
target_role: Execution Role
required_capabilities:
  - implementation
depends_on: []
blocks: []
allowed_paths:
  - src/
source_of_truth:
  - .ai_project/source_of_truth.md
locked_by: Dev Agent
locked_at: 2026-08-13
lock_session:
updated_at: 2026-08-13
report_to: .ai_project/reports/T-20260813-008_task-report.md
qa_to: .ai_project/qa/T-20260813-008_qa-report.md
status_ref:
status_ref_sha:
base_ref:
base_sha:
---

# Canonical lifecycle guard
EOF
cat > "$canonical/.ai_project/reports/T-20260813-008_task-report.md" <<'EOF'
# Task Report
EOF
git -C "$canonical" add .
git -C "$canonical" commit -m "seed canonical lifecycle fixture" >/dev/null
git -C "$canonical" push -u origin main >/dev/null 2>&1
"$repo_root/bin/aiops" sync-status --target "$canonical" >/dev/null

git clone "$remote" "$integrator" >/dev/null 2>&1
git -C "$integrator" config user.email "aiops@example.test"
git -C "$integrator" config user.name "AI Ops Test"
cat > "$integrator/canonical-change.txt" <<'EOF'
canonical changed
EOF
git -C "$integrator" add canonical-change.txt
git -C "$integrator" commit -m "advance canonical ref" >/dev/null
git -C "$integrator" push origin main >/dev/null 2>&1
git -C "$canonical" fetch origin main >/dev/null 2>&1

if "$repo_root/bin/aiops" task advance T-20260813-008 \
  --target "$canonical" --next-agent "QA Agent" --check >"$tmpdir/stale-canonical.out" 2>&1; then
  printf '%s\n' "stale canonical cache should block task advance" >&2
  exit 1
fi
grep -q 'recorded canonical status is stale' "$tmpdir/stale-canonical.out"
"$repo_root/bin/aiops" sync-status --target "$canonical" >/dev/null
"$repo_root/bin/aiops" task advance T-20260813-008 \
  --target "$canonical" --next-agent "QA Agent" --check --json >"$tmpdir/current-canonical.json"
"$repo_root/bin/aiops" validate task-transition-plan "$tmpdir/current-canonical.json" >/dev/null

perl -0pi -e 's/status: in_progress/status: approved/' "$integrator/.ai_project/tasks/active/T-20260813-008.md"
git -C "$integrator" add .ai_project/tasks/active/T-20260813-008.md
git -C "$integrator" commit -m "change canonical Task state" >/dev/null
git -C "$integrator" push origin main >/dev/null 2>&1
git -C "$canonical" fetch origin main >/dev/null 2>&1
"$repo_root/bin/aiops" sync-status --target "$canonical" >/dev/null
if "$repo_root/bin/aiops" task advance T-20260813-008 \
  --target "$canonical" --next-agent "QA Agent" --check >"$tmpdir/stale-task-state.out" 2>&1; then
  printf '%s\n' "stale local Task state should block task advance" >&2
  exit 1
fi
grep -q 'stale against canonical state approved' "$tmpdir/stale-task-state.out"

printf '%s\n' "ok: task lifecycle automation"

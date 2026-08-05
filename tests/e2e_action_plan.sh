#!/usr/bin/env sh
set -eu

repo_root="$(CDPATH= cd "$(dirname "$0")/.." && pwd)"
tmpdir="$(mktemp -d /tmp/aiops-e2e-action-plan.XXXXXX)"
trap 'rm -rf "$tmpdir"' EXIT INT TERM

remote="$tmpdir/remote.git"
project="$tmpdir/project"

git init --bare "$remote" >/dev/null 2>&1
git init -b develop "$project" >/dev/null
git -C "$project" config user.email "aiops@example.test"
git -C "$project" config user.name "AI Ops Test"
git -C "$project" remote add origin "$remote"

ln -s "$repo_root" "$project/.ai"
mkdir -p \
  "$project/.ai_project/tasks/active" \
  "$project/.ai_project/tasks/backlog" \
  "$project/.ai_project/tasks/archive"

for file in current_context.md source_of_truth.md task_board.md ops_decisions.md ops_issues.md; do
  printf '# %s\n' "$file" > "$project/.ai_project/$file"
done

cat > "$project/.ai_project/operating_model.md" <<'EOF'
---
schema: aiops.operating_model.v1
project: ActionPlanProject
core_version: 0.10.0
operating_mode: team_pr
workflow_policy: standard_vnext
canonical_status_ref: origin/develop
knowledge_mode: minimal
active_roles:
  - Execution Role
---

# Action Plan Project
EOF

cat > "$project/.ai_project/agent_registry.md" <<'EOF'
---
schema: aiops.agent_registry.v1
project: ActionPlanProject
agents:
  - agent: Development Agent
    status: enabled
    team: Product Team
    roles:
      - Execution Role
    capabilities:
      - implementation
---

# Agent Registry
EOF

cat > "$project/.ai_project/tasks/active/T-20260805-301.md" <<'EOF'
---
schema: aiops.task.v1
id: T-20260805-301
title: Action plan task
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
report_to: .ai_project/reports/T-20260805-301_task-report.md
qa_to: .ai_project/qa/T-20260805-301_qa-report.md
---

# Action plan task
EOF

git -C "$project" add .ai .ai_project >/dev/null
git -C "$project" commit -m "seed action plan fixture" >/dev/null
git -C "$project" push -u origin develop >/dev/null 2>&1
"$repo_root/bin/aiops" sync-status --target "$project" >/dev/null

"$repo_root/bin/aiops" action plan \
  --target "$project" \
  --role execution \
  --task T-20260805-301 \
  --intends read_source,edit_paths,run_tests,commit \
  --paths src/LoginView.swift \
  --json \
  > "$tmpdir/plan.json"

"$repo_root/bin/aiops" action validate "$tmpdir/plan.json" >/tmp/aiops-e2e-action-plan-validate.out
grep -q 'ok: action plan' /tmp/aiops-e2e-action-plan-validate.out || {
  printf '%s\n' "action plan validation did not pass" >&2
  exit 1
}

ruby -rjson -e '
  data = JSON.parse(File.read(ARGV[0]))
  abort("wrong schema") unless data["schema"] == "aiops.action_plan.v1"
  abort("wrong role") unless data["role"] == "Execution Role"
  abort("wrong task") unless data["task_id"] == "T-20260805-301"
  abort("commit approval missing") unless data["requires_user_approval"].include?("commit")
  abort("unexpected blocker") unless data["blocked_actions"].empty?
  abort("allowed path missing") unless data["allowed_paths"] == ["src/"]
  abort("requested path missing") unless data["requested_paths"] == ["src/LoginView.swift"]
' "$tmpdir/plan.json"

"$repo_root/bin/aiops" action plan \
  --target "$project" \
  --role execution \
  --task T-20260805-301 \
  --intends task_lock,task_unlock,create_handoff,create_pr,external_configuration_changes \
  --json \
  > "$tmpdir/extended-actions-plan.json"

"$repo_root/bin/aiops" action validate "$tmpdir/extended-actions-plan.json" >/dev/null
ruby -rjson -e '
  data = JSON.parse(File.read(ARGV[0]))
  expected = %w[task_lock task_unlock create_handoff create_pr external_configuration_changes]
  missing = expected - data["intended_actions"]
  abort("extended intended actions missing #{missing.join(",")}") unless missing.empty?
  abort("create_pr approval missing") unless data["requires_user_approval"].include?("create_pr")
  abort("external configuration approval missing") unless data["requires_user_approval"].include?("external_configuration_changes")
' "$tmpdir/extended-actions-plan.json"

"$repo_root/bin/aiops" action plan \
  --target "$project" \
  --role execution \
  --task T-20260805-301 \
  --intends edit_paths \
  --paths docs/plan.md \
  --json \
  > "$tmpdir/outside-path-plan.json"

ruby -rjson -e '
  data = JSON.parse(File.read(ARGV[0]))
  abort("edit_paths blocker missing") unless data["blocked_actions"].any? { |item| item["action"] == "edit_paths" && item["reason"].include?("outside") }
' "$tmpdir/outside-path-plan.json"
"$repo_root/bin/aiops" action validate "$tmpdir/outside-path-plan.json" >/dev/null

ruby -rjson -e '
  data = JSON.parse(File.read(ARGV[0]))
  data["blocked_actions"] = []
  File.write(ARGV[1], JSON.pretty_generate(data))
' "$tmpdir/outside-path-plan.json" "$tmpdir/invalid-missing-blocker.json"
if "$repo_root/bin/aiops" action validate "$tmpdir/invalid-missing-blocker.json" >/tmp/aiops-e2e-action-plan-invalid-blocker.out 2>&1; then
  printf '%s\n' "action validate should fail missing edit_paths blocker" >&2
  exit 1
fi
grep -q 'missing edit_paths blocker' /tmp/aiops-e2e-action-plan-invalid-blocker.out || {
  printf '%s\n' "missing edit_paths blocker error absent" >&2
  cat /tmp/aiops-e2e-action-plan-invalid-blocker.out >&2
  exit 1
}

"$repo_root/bin/aiops" action plan \
  --target "$project" \
  --role execution \
  --task T-20260805-301 \
  --intends edit_paths \
  --paths src/../docs/plan.md \
  --json \
  > "$tmpdir/traversal-plan.json"

ruby -rjson -e '
  data = JSON.parse(File.read(ARGV[0]))
  abort("traversal edit_paths blocker missing") unless data["blocked_actions"].any? { |item| item["action"] == "edit_paths" }
' "$tmpdir/traversal-plan.json"
"$repo_root/bin/aiops" action validate "$tmpdir/traversal-plan.json" >/dev/null

cat > "$project/.ai_project/tasks/active/T-20260805-302.md" <<'EOF'
---
schema: aiops.task.v1
id: T-20260805-302
title: Root allowed task
status: approved
type: feature
priority: medium
workflow: feature
target_agent: Development Agent
target_role: Execution Role
required_capabilities:
  - implementation
allowed_paths:
  - .
source_of_truth:
  - .ai_project/source_of_truth.md
depends_on: []
blocks: []
locked_by:
lock_session:
updated_at: 2026-08-05
report_to: .ai_project/reports/T-20260805-302_task-report.md
qa_to: .ai_project/qa/T-20260805-302_qa-report.md
---

# Root allowed task
EOF

"$repo_root/bin/aiops" action plan \
  --target "$project" \
  --role execution \
  --task T-20260805-302 \
  --intends edit_paths \
  --paths src/Login.swift \
  --json \
  > "$tmpdir/root-allowed-plan.json"

ruby -rjson -e '
  data = JSON.parse(File.read(ARGV[0]))
  abort("root allowed path should not be blocked") if data["blocked_actions"].any? { |item| item["action"] == "edit_paths" }
' "$tmpdir/root-allowed-plan.json"
"$repo_root/bin/aiops" action validate "$tmpdir/root-allowed-plan.json" >/dev/null

printf '%s\n' "advance canonical" > "$project/canonical.txt"
git -C "$project" add canonical.txt >/dev/null
git -C "$project" commit -m "advance canonical" >/dev/null
git -C "$project" push origin develop >/dev/null 2>&1
git -C "$project" fetch origin develop >/dev/null 2>&1

"$repo_root/bin/aiops" action plan \
  --target "$project" \
  --role execution \
  --task T-20260805-301 \
  --intends task_transition \
  --json \
  > "$tmpdir/stale-transition-plan.json"

ruby -rjson -e '
  data = JSON.parse(File.read(ARGV[0]))
  abort("expected stale status ref") unless data.dig("evidence", "status_ref_state") == "recorded_stale"
  abort("task_transition blocker missing") unless data["blocked_actions"].any? { |item| item["action"] == "task_transition" && item["reason"].include?("canonical") }
' "$tmpdir/stale-transition-plan.json"
"$repo_root/bin/aiops" action validate "$tmpdir/stale-transition-plan.json" >/dev/null

ruby -rjson -e '
  data = JSON.parse(File.read(ARGV[0]))
  data["blocked_actions"] = []
  File.write(ARGV[1], JSON.pretty_generate(data))
' "$tmpdir/stale-transition-plan.json" "$tmpdir/invalid-missing-transition-blocker.json"
if "$repo_root/bin/aiops" action validate "$tmpdir/invalid-missing-transition-blocker.json" >/tmp/aiops-e2e-action-plan-invalid-transition.out 2>&1; then
  printf '%s\n' "action validate should fail missing task_transition blocker" >&2
  exit 1
fi
grep -q 'missing task_transition blocker' /tmp/aiops-e2e-action-plan-invalid-transition.out || {
  printf '%s\n' "missing task_transition blocker error absent" >&2
  cat /tmp/aiops-e2e-action-plan-invalid-transition.out >&2
  exit 1
}

ruby -rjson -e '
  data = JSON.parse(File.read(ARGV[0]))
  data["requires_user_approval"] = []
  File.write(ARGV[1], JSON.pretty_generate(data))
' "$tmpdir/plan.json" "$tmpdir/invalid-missing-approval.json"
if "$repo_root/bin/aiops" action validate "$tmpdir/invalid-missing-approval.json" >/tmp/aiops-e2e-action-plan-invalid-approval.out 2>&1; then
  printf '%s\n' "action validate should fail missing approval action" >&2
  exit 1
fi
grep -q 'missing approval actions commit' /tmp/aiops-e2e-action-plan-invalid-approval.out || {
  printf '%s\n' "missing approval action error absent" >&2
  cat /tmp/aiops-e2e-action-plan-invalid-approval.out >&2
  exit 1
}

partial_project="$tmpdir/partial"
mkdir -p "$partial_project/.ai_project/tasks/active"
ln -s "$repo_root" "$partial_project/.ai"
cat > "$partial_project/.ai_project/operating_model.md" <<'EOF'
---
schema: aiops.operating_model.v1
project: PartialActionPlanProject
operating_mode: solo_light
workflow_policy: standard_vnext
knowledge_mode: minimal
---

# Partial Action Plan Project
EOF

cat > "$partial_project/.ai_project/tasks/active/T-20260805-303.md" <<'EOF'
---
schema: aiops.task.v1
id: T-20260805-303
title: Partial action plan task
status: approved
workflow: feature
target_role: Execution Role
target_agent: Development Agent
allowed_paths:
  - src/
source_of_truth:
  - .ai_project/source_of_truth.md
---

# Partial action plan task
EOF

"$repo_root/bin/aiops" project snapshot --target "$partial_project" --json > "$tmpdir/partial-snapshot.json"
"$repo_root/bin/aiops" action plan \
  --target "$partial_project" \
  --role execution \
  --task T-20260805-303 \
  --json \
  > "$tmpdir/partial-action-plan.json"

ruby -rjson -e '
  snapshot = JSON.parse(File.read(ARGV[0]))
  plan = JSON.parse(File.read(ARGV[1]))
  abort("partial snapshot should be blocked") unless snapshot.dig("health", "overall") == "blocked"
  abort("action evidence snapshot health mismatch") unless plan.dig("evidence", "snapshot_health") == snapshot.dig("health", "overall")
  abort("action evidence can_start_task mismatch") unless plan.dig("evidence", "can_start_task") == snapshot.dig("control", "can_start_task")
' "$tmpdir/partial-snapshot.json" "$tmpdir/partial-action-plan.json"
"$repo_root/bin/aiops" action validate "$tmpdir/partial-action-plan.json" >/dev/null

no_core_project="$tmpdir/no-core"
mkdir -p \
  "$no_core_project/.ai_project/tasks/active" \
  "$no_core_project/.ai_project/tasks/backlog" \
  "$no_core_project/.ai_project/tasks/archive"
for file in current_context.md source_of_truth.md task_board.md ops_decisions.md ops_issues.md; do
  printf '# %s\n' "$file" > "$no_core_project/.ai_project/$file"
done
cat > "$no_core_project/.ai_project/operating_model.md" <<'EOF'
---
schema: aiops.operating_model.v1
project: NoCoreActionPlanProject
operating_mode: solo_light
workflow_policy: standard_vnext
knowledge_mode: minimal
---

# No Core Action Plan Project
EOF

cat > "$no_core_project/.ai_project/agent_registry.md" <<'EOF'
---
schema: aiops.agent_registry.v1
project: NoCoreActionPlanProject
agents:
  - agent: Development Agent
    status: enabled
    team: Product Team
    roles:
      - Execution Role
    capabilities:
      - implementation
---

# Agent Registry
EOF

cat > "$no_core_project/.ai_project/tasks/active/T-20260805-304.md" <<'EOF'
---
schema: aiops.task.v1
id: T-20260805-304
title: No core action plan task
status: approved
workflow: feature
target_role: Execution Role
target_agent: Development Agent
allowed_paths:
  - src/
source_of_truth:
  - .ai_project/source_of_truth.md
---

# No core action plan task
EOF

"$repo_root/bin/aiops" project snapshot --target "$no_core_project" --json > "$tmpdir/no-core-snapshot.json"
"$repo_root/bin/aiops" action plan \
  --target "$no_core_project" \
  --role execution \
  --task T-20260805-304 \
  --json \
  > "$tmpdir/no-core-action-plan.json"

ruby -rjson -e '
  snapshot = JSON.parse(File.read(ARGV[0]))
  plan = JSON.parse(File.read(ARGV[1]))
  abort("no-core snapshot should be blocked") unless snapshot.dig("health", "overall") == "blocked"
  abort("no-core snapshot should block task start") unless snapshot.dig("control", "can_start_task") == false
  abort("no-core action evidence snapshot health mismatch") unless plan.dig("evidence", "snapshot_health") == snapshot.dig("health", "overall")
  abort("no-core action evidence can_start_task mismatch") unless plan.dig("evidence", "can_start_task") == snapshot.dig("control", "can_start_task")
  abort("no-core blocker evidence missing") unless plan.dig("evidence", "snapshot_blockers").include?("core_missing")
' "$tmpdir/no-core-snapshot.json" "$tmpdir/no-core-action-plan.json"
"$repo_root/bin/aiops" action validate "$tmpdir/no-core-action-plan.json" >/dev/null

printf '%s\n' "ok: action plan"

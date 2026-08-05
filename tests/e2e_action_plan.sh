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

printf '%s\n' "ok: action plan"

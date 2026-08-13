#!/usr/bin/env sh
set -eu

repo_root="$(CDPATH= cd "$(dirname "$0")/.." && pwd)"
tmpdir="$(mktemp -d /tmp/aiops-e2e-session.XXXXXX)"
trap 'rm -rf "$tmpdir"' EXIT INT TERM

ln -s "$repo_root" "$tmpdir/.ai"
mkdir -p "$tmpdir/.ai_project/tasks/active" "$tmpdir/.ai_project/tasks/backlog" "$tmpdir/.ai_project/tasks/archive"

for file in README.md source_of_truth.md task_board.md ops_decisions.md ops_issues.md; do
  printf '# %s\n' "$file" > "$tmpdir/.ai_project/$file"
done

cat > "$tmpdir/.ai_project/current_context.md" <<'EOF'
# Current Agent Context

## 다음 초점

1. Session prompt validation을 실행 가능한 Task 흐름으로 점검
2. Role Session 전환 문구와 인계 기준 확인
3. Verification Role이 독립 검증할 수 있는 입력 유지
EOF

cat > "$tmpdir/.ai_project/operating_model.md" <<'EOF'
---
schema: aiops.operating_model.v1
project: SessionProject
bootstrap_mode: fast_track
core_version: 0.6.4
core_source: symlink
core_update_policy: manual_review
start_context: new_project_with_requirement
readiness_level: idea_structured
operating_mode: solo_light
team_pattern: single_team
workflow_policy: skip_scoped_for_simple_tasks
ownership_model: path_plus_domain
coordination: single_active_task
board_model: project_board_only
branch_pr: pending_decision
knowledge_mode: minimal
release_role: inactive
active_roles:
  - Lead Role
  - Execution Role
  - Verification Role
  - Ops Governance Role
deferred_roles: []
---

# Project Operating Model
EOF

cat > "$tmpdir/.ai_project/agent_registry.md" <<'EOF'
---
schema: aiops.agent_registry.v1
project: SessionProject
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
  - agent: Dev Agent
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
      - qa_review
  - agent: Release Agent
    status: deferred
    team: Product Team
    roles:
      - Release Role
    capabilities:
      - release_coordination
---

# Project Agent Registry
EOF

"$repo_root/bin/aiops" task create \
  --target "$tmpdir" \
  --id T-20260727-020 \
  --title "Session prompt validation" \
  --workflow feature \
  --role "Execution Role" \
  --capability implementation \
  --status approved \
  --allowed-path src/ \
  --source-of-truth .ai_project/source_of_truth.md \
  --created-by "Lead Agent" \
  >/tmp/aiops-e2e-session-task-create.out

"$repo_root/bin/aiops" session-guide --target "$tmpdir" >/tmp/aiops-e2e-session-guide.out

grep -q 'AI Ops session guide' /tmp/aiops-e2e-session-guide.out || {
  printf '%s\n' "session-guide header missing" >&2
  exit 1
}

grep -q 'aiops role prompt execution' /tmp/aiops-e2e-session-guide.out || {
  printf '%s\n' "session-guide did not include execution prompt command" >&2
  exit 1
}

grep -q '선택 기준:' /tmp/aiops-e2e-session-guide.out || {
  printf '%s\n' "session-guide did not include role selection criteria" >&2
  exit 1
}

grep -q 'Lead Agent: Lead Role / Completion Role (active / Product Team)' /tmp/aiops-e2e-session-guide.out || {
  printf '%s\n' "session-guide did not include active agent role mapping" >&2
  cat /tmp/aiops-e2e-session-guide.out >&2
  exit 1
}

"$repo_root/bin/aiops" role prompt completion \
  --target "$tmpdir" \
  --task T-20260727-020 \
  >/tmp/aiops-e2e-completion-role-prompt.out

grep -q '^agent: Lead Agent$' /tmp/aiops-e2e-completion-role-prompt.out || {
  printf '%s\n' "completion prompt did not preserve the multi-role Agent identity" >&2
  cat /tmp/aiops-e2e-completion-role-prompt.out >&2
  exit 1
}

grep -q '^assigned_roles: Lead Role / Completion Role$' /tmp/aiops-e2e-completion-role-prompt.out || {
  printf '%s\n' "completion prompt did not include all assigned roles" >&2
  exit 1
}

grep -q '^active_role: Completion Role$' /tmp/aiops-e2e-completion-role-prompt.out || {
  printf '%s\n' "completion prompt did not identify the active role" >&2
  exit 1
}

grep -q '너의 Agent 정체성은 Lead Agent 하나다.' /tmp/aiops-e2e-completion-role-prompt.out || {
  printf '%s\n' "completion prompt split one multi-role Agent into separate identities" >&2
  exit 1
}

grep -q 'Execution Role과 Verification Role처럼 독립 분리가 필요한 조합' /tmp/aiops-e2e-completion-role-prompt.out || {
  printf '%s\n' "role prompt did not preserve the execution and verification separation" >&2
  exit 1
}

grep -q 'Release Agent: Release Role (deferred / Product Team)' /tmp/aiops-e2e-session-guide.out || {
  printf '%s\n' "session-guide did not include deferred agent role mapping" >&2
  cat /tmp/aiops-e2e-session-guide.out >&2
  exit 1
}

grep -q '현재 초점:' /tmp/aiops-e2e-session-guide.out || {
  printf '%s\n' "session-guide did not include current focus header" >&2
  exit 1
}

grep -q 'Session prompt validation을 실행 가능한 Task 흐름으로 점검' /tmp/aiops-e2e-session-guide.out || {
  printf '%s\n' "session-guide did not include current focus content" >&2
  cat /tmp/aiops-e2e-session-guide.out >&2
  exit 1
}

grep -q '추천 다음 세션:' /tmp/aiops-e2e-session-guide.out || {
  printf '%s\n' "session-guide did not include recommended next sessions" >&2
  exit 1
}

grep -q 'aiops role prompt direction' /tmp/aiops-e2e-session-guide.out || {
  printf '%s\n' "session-guide did not include direction prompt command" >&2
  exit 1
}

"$repo_root/bin/aiops" role prompt execution \
  --target "$tmpdir" \
  --task T-20260727-020 \
  --adapter claude \
  --agent "Dev Agent" \
  >/tmp/aiops-e2e-role-prompt.out

grep -q '너는 이 프로젝트의 Dev Agent / Execution Role 세션이야.' /tmp/aiops-e2e-role-prompt.out || {
  printf '%s\n' "role prompt did not identify execution session" >&2
  exit 1
}

grep -q 'task_id: T-20260727-020' /tmp/aiops-e2e-role-prompt.out || {
  printf '%s\n' "role prompt did not include task id" >&2
  exit 1
}

grep -q 'aiops task status T-20260727-020' /tmp/aiops-e2e-role-prompt.out || {
  printf '%s\n' "role prompt did not include task status command" >&2
  exit 1
}

grep -q 'aiops action plan --role "Execution Role"' /tmp/aiops-e2e-role-prompt.out || {
  printf '%s\n' "role prompt did not include action plan command" >&2
  exit 1
}

grep -q 'blocked_actions가 있으면 작업하지 말고' /tmp/aiops-e2e-role-prompt.out || {
  printf '%s\n' "role prompt did not include action plan blocker rule" >&2
  exit 1
}

grep -q "compact transition receipt" /tmp/aiops-e2e-role-prompt.out || {
  printf '%s\n' "role prompt did not include transition receipt reminder" >&2
  exit 1
}

grep -q 'CLAUDE.md의 AI Ops 지침' /tmp/aiops-e2e-role-prompt.out || {
  printf '%s\n' "role prompt did not include claude adapter note" >&2
  exit 1
}

if "$repo_root/bin/aiops" role prompt unknown --target "$tmpdir" >/tmp/aiops-e2e-role-prompt-invalid.out 2>&1; then
  printf '%s\n' "unknown role prompt should fail" >&2
  exit 1
fi

grep -q 'unknown role: unknown' /tmp/aiops-e2e-role-prompt-invalid.out || {
  printf '%s\n' "unknown role error missing" >&2
  exit 1
}

printf '%s\n' "ok: session role prompt"

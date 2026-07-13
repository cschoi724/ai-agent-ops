---
id: T-{{DATE_COMPACT}}-001
title: {{TASK_TITLE}}
status: proposed
type: {{TASK_TYPE}}
priority: {{PRIORITY}}
priority_reason: {{PRIORITY_REASON}}
org_unit: {{ORG_UNIT}}
team: {{TEAM}}
team_lead: {{TEAM_LEAD}}
workflow: {{WORKFLOW}}
target_agent: {{LEAD_AGENT}}
target_role: Lead Role
required_capabilities:
  - {{REQUIRED_CAPABILITY}}
ownership:
  paths:
    - {{OWNED_PATH}}
  domains: []
  documents:
    - {{OWNED_DOCUMENT}}
ownership_review:
  required: false
  reviewer:
depends_on: []
blocks: []
parallel_group:
allowed_paths:
  - {{ALLOWED_PATH}}
source_of_truth:
  - {{SOURCE_OF_TRUTH}}
created_by: {{CREATED_BY}}
approved_by:
locked_by:
locked_at:
lock_session:
lock_timeout_minutes: 240
created_at: {{DATE}}
updated_at: {{DATE}}
report_to: .ai_project/reports/T-{{DATE_COMPACT}}-001_task-report.md
qa_to: .ai_project/qa/T-{{DATE_COMPACT}}-001_qa-report.md
branch:
  name:
  base:
pr:
  url:
  status:
---

# {{TASK_TITLE}}

## 1. 배경

## 2. 작업 범위

## 3. 제외 범위

## 4. 우선순위와 Queue 영향

- 추천 priority: `{{PRIORITY}}`
- priority 근거:
- 기존 Queue 영향:
- 의존성:
- 기존 Task 변경 필요 여부:

## 5. Scope / Ownership

- org_unit:
- team:
- team_lead:
- allowed_paths:
- source_of_truth:
- ownership 영향:
- cross-team 영향:
- parallel 가능 여부:

## 6. 실행 지시

이 Task는 `workflow`, `status`, `target_agent`, `target_role` 조합에 맞는 Agent 또는 Role만 실행한다. `target_agent`는 기존 호환 라우팅 필드이고, `target_role`은 vNext Role 라우팅 필드다. 작업 완료 시 `status`, `target_agent`, `target_role`을 workflow에 정의된 다음 처리 상태로 갱신한다.

기본 workflow에서는 한 Agent가 한 번의 완료 처리에서 한 단계의 상태 전이만 수행한다. 상태 전이 후 `target_agent` 또는 `target_role`이 다른 Agent/Role이 되면 인계한다. workflow가 명시적으로 연속 전이를 허용하지 않는 한 다음 Role 단계를 이어서 처리하지 않으며, 다른 Agent 또는 Role 명의의 상태 전이 기록을 대신 작성하지 않는다.

기본 상태 흐름은 `proposed -> scoped -> approved -> in_progress -> verification_ready -> verification_in_progress -> verification_passed -> completion_review -> done`이다. `rework_requested`는 재작업 범위를 확인한 뒤 `scoped` 또는 `approved`로 되돌린다.

1. 
2. 
3. 

## 7. 검증 기준

- 

## 8. Branch / PR

- branch:
- PR:
- commit 권한:
- push 권한:
- merge owner:

## 9. 완료 후 산출물

- 작업 보고: `{{TASK_REPORT_PATH}}`
- 검증 보고: `{{QA_REPORT_PATH}}`
- 필요 시 갱신 문서:

## 10. Next Agent Handoff

Role 전환이 발생하면 `.ai/runtime/role_handoff.md` 기준으로 아래 블록을 갱신한다. 실제 다음 Role은 이 Task의 `workflow`, `status`, `target_agent`, `target_role`, 프로젝트별 override를 우선한다. 같은 내용은 현재 Agent의 최종 응답에도 포함한다.

```text
다음 Agent에게 전달할 말:

너는 {{NEXT_AGENT}} / {{NEXT_ROLE}}이야.
Task {{TASK_ID}}를 이어서 처리해줘.

- 현재 상태: {{CURRENT_STATUS}}
- 다음에 해야 할 일: {{NEXT_ACTION}}
- 기준 문서: {{SOURCE_OF_TRUTH}}
- 허용 경로: {{ALLOWED_PATHS}}
- 참고 산출물: {{REPORT_OR_QA_PATHS}}
- 변경/검토 대상: {{CHANGED_OR_AFFECTED_PATHS}}
- 남은 리스크: {{RISKS_OR_NONE}}
- 차단/결정 필요: {{BLOCKERS_OR_DECISIONS_OR_NONE}}
- 주의: 현재 Task의 workflow, status, target_agent, target_role이 네 Role과 맞는지 먼저 확인해줘.
```

## 11. 차단 조건

- 

## 12. 상태 전이 기록

| 날짜 | Agent | 이전 상태 | 다음 상태 | 사유 |
|---|---|---|---|---|
| {{DATE}} | {{CREATED_BY}} |  | proposed | Task 생성 |

## 13. Lock 기록

| 날짜 | Agent | 작업 | 사유 |
|---|---|---|---|
|  |  |  |  |

## 14. 변경 이력

| 날짜 | Agent | 변경 내용 |
|---|---|---|
| {{DATE}} | {{CREATED_BY}} | Task 생성 |

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

## 10. 차단 조건

- 

## 11. 상태 전이 기록

| 날짜 | Agent | 이전 상태 | 다음 상태 | 사유 |
|---|---|---|---|---|
| {{DATE}} | {{CREATED_BY}} |  | proposed | Task 생성 |

## 12. Lock 기록

| 날짜 | Agent | 작업 | 사유 |
|---|---|---|---|
|  |  |  |  |

## 13. 변경 이력

| 날짜 | Agent | 변경 내용 |
|---|---|---|
| {{DATE}} | {{CREATED_BY}} | Task 생성 |

---
id: T-{{DATE_COMPACT}}-001
title: {{TASK_TITLE}}
status: proposed
type: {{TASK_TYPE}}
priority: {{PRIORITY}}
priority_reason: {{PRIORITY_REASON}}
workflow: {{WORKFLOW}}
target_agent: PM Agent
required_capabilities:
  - {{REQUIRED_CAPABILITY}}
depends_on: []
allowed_paths:
  - {{ALLOWED_PATH}}
source_of_truth:
  - {{SOURCE_OF_TRUTH}}
created_by: PM Agent
approved_by:
locked_by:
locked_at:
lock_session:
lock_timeout_minutes: 240
created_at: {{DATE}}
updated_at: {{DATE}}
report_to: .ai_project/reports/T-{{DATE_COMPACT}}-001_task-report.md
qa_to: .ai_project/qa/T-{{DATE_COMPACT}}-001_qa-report.md
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

## 5. 실행 지시

이 Task는 `workflow`, `status`, `target_agent` 조합에 맞는 Agent만 실행한다. `target_agent`는 현재 `status`에서 Task를 처리할 Agent다. 작업 완료 시 `status`와 `target_agent`를 workflow에 정의된 다음 처리 상태로 갱신한다.

기본 workflow에서는 한 Agent가 한 번의 완료 처리에서 한 단계의 상태 전이만 수행한다. 상태 전이 후 `target_agent`가 다른 Agent가 되면 인계한다. workflow가 명시적으로 연속 전이를 허용하지 않는 한 다음 Agent 단계를 이어서 처리하지 않으며, 다른 Agent 명의의 상태 전이 기록을 대신 작성하지 않는다.

1. 
2. 
3. 

## 6. 검증 기준

- 

## 7. 완료 후 산출물

- 작업 보고: `{{TASK_REPORT_PATH}}`
- QA 보고: `{{QA_REPORT_PATH}}`
- 필요 시 갱신 문서:

## 8. 차단 조건

- 

## 9. 상태 전이 기록

| 날짜 | Agent | 이전 상태 | 다음 상태 | 사유 |
|---|---|---|---|---|
| {{DATE}} | PM Agent |  | proposed | Task 생성 |

## 10. Lock 기록

| 날짜 | Agent | 작업 | 사유 |
|---|---|---|---|
|  |  |  |  |

## 11. 변경 이력

| 날짜 | Agent | 변경 내용 |
|---|---|---|
| {{DATE}} | PM Agent | Task 생성 |

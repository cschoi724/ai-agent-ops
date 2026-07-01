---
id: T-{{DATE_COMPACT}}-001
title: {{TASK_TITLE}}
status: proposed
type: {{TASK_TYPE}}
priority: {{PRIORITY}}
priority_reason: {{PRIORITY_REASON}}
target_agent: {{TARGET_AGENT}}
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
report_to: .ai_project/reports/T-{{DATE_COMPACT}}-001_dev-report.md
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

이 Task는 `target_agent`와 일치하는 Agent만 실행한다. `required_capabilities`가 일부 일치하더라도 `target_agent`가 현재 Agent와 다르면 실행하지 않는다.

1. 
2. 
3. 

## 6. 검증 기준

- 

## 7. 완료 후 산출물

- 개발 보고: `{{DEV_REPORT_PATH}}`
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

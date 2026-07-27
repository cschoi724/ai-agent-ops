---
schema: aiops.task.v1
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

## Scope

- Goal:
- In scope:
- Out of scope:
- Acceptance criteria:

## Execution

- Allowed paths: `{{ALLOWED_PATHS}}`
- Source of truth: `{{SOURCE_OF_TRUTH}}`
- Dependencies:
- Validation required:

Follow `.ai/runtime/task_queue.md`, `.ai/runtime/workflow.md`, and the project workflow policy. Do not expand scope, change status, commit, push, PR, or merge beyond the approved task policy.

## Handoff

When the next Role should continue, update or create a handoff using `.ai/runtime/role_handoff.md`.

```text
너는 {{NEXT_AGENT}} / {{NEXT_ROLE}}이야.
Task {{TASK_ID}}를 이어서 처리해줘.

- 현재 상태: {{CURRENT_STATUS}}
- 다음에 해야 할 일: {{NEXT_ACTION}}
- 기준 문서: {{SOURCE_OF_TRUTH}}
- 허용 경로: {{ALLOWED_PATHS}}
- 참고 산출물: {{REPORT_OR_QA_PATHS}}
- 남은 리스크: {{RISKS_OR_NONE}}
- 차단/결정 필요: {{BLOCKERS_OR_DECISIONS_OR_NONE}}
```

## Activity

| 날짜 | Agent | 이전 상태 | 다음 상태 | 요약 |
|---|---|---|---|---|
| {{DATE}} | {{CREATED_BY}} |  | proposed | Task 생성 |

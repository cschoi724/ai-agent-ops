---
schema: aiops.handoff.v1
task_id: {{TASK_ID}}
from_role: {{FROM_ROLE}}
to_role: {{NEXT_ROLE}}
from_agent: {{FROM_AGENT}}
to_agent: {{NEXT_AGENT}}
current_status: {{CURRENT_STATUS}}
next_action: {{NEXT_ACTION}}
source_of_truth:
  - {{SOURCE_OF_TRUTH}}
allowed_paths:
  - {{ALLOWED_PATHS}}
report_paths:
  - {{REPORT_OR_QA_PATHS}}
changed_or_affected_paths:
  - {{CHANGED_OR_AFFECTED_PATHS}}
validation_result: {{VALIDATION_RESULT}}
risks:
  - {{RISKS_OR_NONE}}
blockers:
  - {{BLOCKERS_OR_DECISIONS_OR_NONE}}
open_questions: []
created_at: {{DATE}}
created_by: {{FROM_AGENT}}
---

# Handoff Message Template

Task ID: `{{TASK_ID}}`
작성 Role: `{{FROM_ROLE}}`
다음 Role: `{{NEXT_ROLE}}`
작성일: `{{DATE}}`

## 다음 Agent에게 전달할 말

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
- 주의: 현재 Task의 `workflow`, `status`, `target_agent`, `target_role`이 네 Role과 맞는지 먼저 확인해줘.

## 인계 기록

| 날짜 | From | To | 상태 | 요약 |
|---|---|---|---|---|
| {{DATE}} | {{FROM_ROLE}} | {{NEXT_ROLE}} | {{CURRENT_STATUS}} | {{SUMMARY}} |

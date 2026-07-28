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

# Handoff

너는 {{NEXT_AGENT}} / {{NEXT_ROLE}}이야.
Task {{TASK_ID}}를 이어서 처리해줘.

- 현재 상태: {{CURRENT_STATUS}}
- 다음에 해야 할 일: {{NEXT_ACTION}}
- 기준 문서: {{SOURCE_OF_TRUTH}}
- 허용 경로: {{ALLOWED_PATHS}}
- 참고 산출물: {{REPORT_OR_QA_PATHS}}
- 변경/검토 대상: {{CHANGED_OR_AFFECTED_PATHS}}
- 검증 결과: {{VALIDATION_RESULT}}
- 남은 리스크: {{RISKS_OR_NONE}}
- 차단/결정 필요: {{BLOCKERS_OR_DECISIONS_OR_NONE}}

먼저 확인:

- Task의 `workflow`, `status`, `target_agent`, `target_role`이 네 Role과 맞는지 확인한다.
- `allowed_paths` 밖 파일은 수정하지 않는다.
- 필요한 context pack이 있으면 `.ai_knowledge/context_packs/`에서 찾는다.
- 승인, commit, push, merge, deploy 권한은 프로젝트 정책을 따른다.

세션 시작 전 확인 명령:

```bash
aiops task status {{TASK_ID}}
aiops handoff validate {{TASK_ID}} --strict
```

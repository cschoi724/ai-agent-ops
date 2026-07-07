# AGENTS.md

이 문서는 Codex가 이 프로젝트에서 AI Agent 운영 방식을 따르기 위한 진입 지침이다.

## 1. 기본 원칙

- 모든 답변은 한국어로 제공한다.
- 먼저 `.ai/workflow.md`를 읽는다.
- Task Queue 운영 시 `.ai/task_queue.md`를 읽는다.
- `.ai/`는 운영 가이드북이며 사용자 승인 없이 수정하지 않는다.
- 프로젝트별 실행 Task와 협업 기록은 `.ai_project/`를 확인한다.
- 커밋, push, 배포, 외부 설정 변경은 사용자 승인 후 진행한다.

## 2. 역할 선택

현재 세션 역할에 따라 아래 문서를 읽는다.

| 역할 | 문서 |
|---|---|
| PM Agent | `.ai/agents/pm_agent.md` |
| Development Agent | `.ai/agents/development_agent.md` |
| QA Agent | `.ai/agents/qa_agent.md` |
| AI Ops Agent | `.ai/agents/ai_ops_agent.md` |

## 3. 프로젝트 상태 확인

프로젝트가 초기화되어 있으면 아래 문서를 확인한다.

1. `.ai_project/README.md`
2. `.ai_project/agent_registry.md`
3. `.ai_project/current_context.md`
4. `.ai_project/tasks/`
5. `.ai_project/task_board.md`
6. `.ai_project/source_of_truth.md`
7. `.ai_project/ops_decisions.md`
8. `.ai_project/ops_issues.md`
9. 필요한 report/qa 문서

## 4. PM Agent

PM Agent는 작업을 정의하고 `.ai_project/tasks/`에 Task를 생성한다.

PM Agent는 제품/일정 영향 검토, source of truth 최종 판단, Task 승인/완료 확정을 담당한다.

새 Task는 기본적으로 `.ai_project/tasks/active/` 또는 `.ai_project/tasks/backlog/`에 생성한다. 기존 프로젝트의 `.ai_project/tasks/` 루트 파일은 legacy Task로 인정한다.

새 요구사항을 받으면 기존 Task Queue와 비교해 추천 priority, 기존 Queue 영향, 의존성, 기존 Task 변경 필요 여부, 사용자 결정 필요 항목을 먼저 정리한다.

기존 Task의 priority, depends_on, 진행 순서를 바꾸기 전에는 사용자 승인을 받는다. `in_progress` Task를 자동으로 중단하거나 밀어내지 않는다.

다음 작업을 안내할 때는 Task ID, workflow, 상태, 담당 Agent, 담당 근거, 열 세션, 사용자 요청을 함께 표시한다. Task 이름만 말하지 않는다.

## 5. Development Agent

Development Agent는 `.ai_project/tasks/active/`에서 자신에게 할당된 `approved` Task를 확인하고 승인된 범위 안에서만 구현한다. 기존 프로젝트 호환을 위해 `.ai_project/tasks/` 루트의 legacy Task도 함께 확인할 수 있다. `backlog/`와 `archive/`는 실행 후보로 보지 않는다.

`target_agent`가 `Development Agent`가 아닌 Task는 실행하지 않는다. 현재 `workflow`와 `status`가 Development Agent 전이를 허용하지 않아도 실행하지 않는다. `required_capabilities`가 일부 일치해도 `target_agent` 불일치를 덮어쓸 수 없다.

실행 전 `approved_by`, `depends_on`, `locked_by`, `allowed_paths`, `source_of_truth`를 확인한다. 실행 가능한 Task면 lock을 획득하고 하나의 Task만 진행한다.

재작업 요청 상태의 Task는 현재 workflow의 재개 규칙을 확인한다. 기본 workflow에서는 PM Agent가 재개 여부와 범위를 확인한 뒤 `approved`로 전환한 Task를 실행한다.

작업 완료 후 변경 파일, 구현 내용, 검증 결과, 남은 리스크를 보고하고 Task 상태를 `ready_for_qa`, `target_agent: QA Agent`로 갱신한 뒤 lock을 비운다.

## 6. QA Agent

QA Agent는 `.ai_project/tasks/active/`에서 `ready_for_qa` Task를 확인하고 Development Agent 결과를 독립적으로 검증한다. 기존 프로젝트 호환을 위해 `.ai_project/tasks/` 루트의 legacy Task도 함께 확인할 수 있다. `backlog/`와 `archive/`는 검증 후보로 보지 않는다.

`target_agent`가 `QA Agent`가 아닌 Task는 검증하지 않는다. 현재 `workflow`와 `status`가 QA Agent 전이를 허용하지 않아도 검증하지 않는다. `required_capabilities`가 일부 일치해도 `target_agent` 불일치를 덮어쓸 수 없다.

QA 시작 전 `report_to` 경로의 작업 보고서, `depends_on`, `locked_by`, `source_of_truth`를 확인한다. 검증 가능한 Task면 lock을 획득하고 하나의 Task만 진행한다.

QA 결과는 `PASS`, `PASS_WITH_RISK`, `FAIL`, `BLOCKED` 중 하나로 분류한다. 상태 전이는 현재 Task의 `workflow`, `status`, `target_agent` 조합이 허용하는 범위에서만 수행한다. 다른 Agent 명의의 상태 전이 기록은 작성하지 않는다.

## 7. AI Ops Agent

AI Ops Agent는 제품 Task 실행 라인 밖에서 운영 프로세스를 점검한다.

새 프로젝트 또는 기존 프로젝트에 AI Agent 운영 체계를 도입할 때는 `.ai/workflows/ops_migration.md`를 기준으로 `.ai_project/` 초기 구조, 운영 문서, source of truth 매핑, AGENTS.md 병합안을 준비한다.

AI Ops Agent는 제품 Task 생성, 승인, 상태 변경, 코드 수정, QA 판정 변경을 하지 않는다.

## 8. 금지사항

- 사용자 승인 없이 `.ai/` 운영 문서를 수정하지 않는다.
- 사용자 승인 없이 커밋하지 않는다.
- 사용자 승인 없이 push하지 않는다.
- 민감정보를 로그나 문서에 남기지 않는다.

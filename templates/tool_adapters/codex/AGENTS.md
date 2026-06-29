# AGENTS.md

이 문서는 Codex가 이 프로젝트에서 AI Agent 운영 방식을 따르기 위한 진입 지침이다.

## 1. 기본 원칙

- 모든 답변은 한국어로 제공한다.
- 먼저 `.ai/workflow.md`를 읽는다.
- `.ai/`는 운영 가이드북이며 사용자 승인 없이 수정하지 않는다.
- 프로젝트별 진행 상태와 협업 기록은 `.ai_project/`를 확인한다.
- 커밋, push, 배포, 외부 설정 변경은 사용자 승인 후 진행한다.

## 2. 역할 선택

현재 세션 역할에 따라 아래 문서를 읽는다.

| 역할 | 문서 |
|---|---|
| PM Agent | `.ai/agents/pm_agent.md` |
| Development Agent | `.ai/agents/development_agent.md` |
| QA Agent | `.ai/agents/qa_agent.md` |

## 3. 프로젝트 상태 확인

프로젝트가 초기화되어 있으면 아래 문서를 확인한다.

1. `.ai_project/README.md`
2. `.ai_project/agent_registry.md`
3. `.ai_project/task_board.md`
4. `.ai_project/source_of_truth.md`
5. `.ai_project/ops_decisions.md`
6. 필요한 handoff/report/qa 문서

## 4. PM Agent

PM Agent는 작업을 정의하고, Development Agent와 QA Agent에게 전달할 지시서를 작성한다.

PM Agent는 사용자가 명시적으로 요청한 경우에만 `.ai_project/` 초기 구조를 생성할 수 있다.

## 5. Development Agent

Development Agent는 PM Agent가 승인한 범위 안에서만 구현한다.

작업 완료 후 변경 파일, 구현 내용, 검증 결과, 남은 리스크를 보고한다.

## 6. QA Agent

QA Agent는 Development Agent 결과를 독립적으로 검증한다.

QA 결과는 `PASS`, `PASS_WITH_RISK`, `FAIL`, `BLOCKED` 중 하나로 분류한다.

## 7. 금지사항

- 사용자 승인 없이 `.ai/` 운영 문서를 수정하지 않는다.
- 사용자 승인 없이 커밋하지 않는다.
- 사용자 승인 없이 push하지 않는다.
- 민감정보를 로그나 문서에 남기지 않는다.

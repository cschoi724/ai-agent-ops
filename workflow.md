# AI Agent Workflow

작성일: 2026-06-29  
상태: Draft v1  
범위: Codex 기준 AI Agent 운영 흐름

## 1. 목적

이 문서는 AI Agent가 PM, Development, QA 역할을 나누어 협업하는 기본 흐름을 정의한다.

`.ai/`는 운영 가이드북과 템플릿 프레임워크이고, 실제 프로젝트별 Task Queue와 협업 기록은 `.ai_project/`에 둔다.

## 2. 기본 원칙

- 모든 Agent는 한국어로 보고한다.
- 한 번에 하나의 Task 단위로 진행한다.
- `.ai/` 운영 문서는 사용자 승인 없이 수정하지 않는다.
- 프로젝트별 실행 지시는 `.ai_project/tasks/`에 기록한다.
- `task_board.md`는 현황 요약판이며 Task 파일을 대체하지 않는다.
- report/QA 문서는 Task 진행 과정의 보조 기록이다.
- 커밋, push, 배포, 외부 설정 변경은 사용자 승인 후 진행한다.
- 민감정보를 로그, 문서, 보고서에 남기지 않는다.

## 3. 초기 활성 Agent

초기 활성 Agent는 아래 3개다. 이 구성은 고정 상한이 아니라 기본 시작점이다.

| Agent | 역할 문서 | 핵심 책임 |
|---|---|---|
| PM Agent | `.ai/agents/pm_agent.md` | 작업 정의, 승인 게이트, 지시서, 통합 판단 |
| Development Agent | `.ai/agents/development_agent.md` | 승인된 범위의 구현과 개발 보고 |
| QA Agent | `.ai/agents/qa_agent.md` | 검증, 리스크 정리, 재작업 지시 |

보안, 문서, 릴리즈, 구조 검토는 초기에는 별도 Agent로 분리하지 않고 PM/Development/QA 책임 안에 포함한다. 운영 중 반복 부담이 생기면 PM Agent가 새 Agent 분리와 capability 위임을 제안한다.

## 4. 기본 흐름

```text
PM creates Task -> Development reads Task Queue -> QA reads ready Task -> PM closes Task
```

1. PM Agent가 `.ai_project/tasks/`에 Task를 생성하고 workflow를 선택한다.
2. Product Owner가 진행을 승인하면 Task 상태를 `approved`로 바꾼다.
3. Development Agent가 세션 시작 시 Task Queue에서 자기 역할 또는 capability와 맞는 `approved` Task를 찾는다.
4. Development Agent가 승인된 범위만 구현하고 Task 상태를 `ready_for_qa`로 바꾼다.
5. QA Agent가 `ready_for_qa` Task를 찾아 검증한다.
6. PM Agent가 `done`, `rework_requested`, `blocked`, 보류 여부를 판단한다.

## 5. 프로젝트 초기화

PM Agent는 사용자가 명시적으로 요청한 경우에만 `.ai_project/`를 생성한다.

초기 구조는 `.ai/project_workspace.md`를 따른다.

Task Queue 운영 기준은 `.ai/task_queue.md`를 따른다.

## 6. Workflow 선택

Task 유형별 흐름은 `.ai/workflows/`를 따른다.

| Task 유형 | Workflow |
|---|---|
| 신규 기능 또는 기능 확장 | `.ai/workflows/feature.md` |
| 버그 수정 | `.ai/workflows/bugfix.md` |
| 문서 작업 | `.ai/workflows/docs.md` |
| 배포 준비 | `.ai/workflows/release.md` |

## 7. Capability Hook

Workflow는 `.ai/capabilities.md`의 capability를 기준으로 확장한다.

예:

```text
Task가 인증/권한/개인정보/로그를 건드리면 QA Agent의 security_check 관점을 필수 검증 항목에 추가한다.
```

새 Agent는 실제 운영 중 반복 부담이나 독립 검토 필요성이 명확해진 뒤 사용자 승인으로 추가한다. 추가된 Agent는 `.ai/agent_registry.md`, `.ai/capabilities.md`, 관련 workflow에 연결한다.

## 8. 변경 이력

| 날짜 | 변경 내용 |
|---|---|
| 2026-06-29 | Codex 기준 기본 workflow v1 작성 |
| 2026-06-29 | Task Queue 기반 실행 흐름 추가 |

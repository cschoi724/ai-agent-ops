# Knowledge Model

작성일: 2026-07-21  
상태: Draft vNext

## 1. 목적

Knowledge Model은 AI Agent가 프로젝트 지식을 어떻게 축적, 요약, 연결, 갱신할지 정의한다.

이 모델은 LLM Wiki 개념을 AI Agent Ops에 맞게 적용한다. 목표는 Agent가 매 세션마다 모든 원본 문서를 다시 읽지 않아도, 프로젝트의 핵심 맥락과 주요 결정을 빠르게 파악하게 하는 것이다.

## 2. 계층 구분

```text
.ai/
  운영 헌법, Role, Workflow, Policy

.ai_project/
  운영 상태, Task, Board, Reports, QA

.ai_knowledge/
  LLM Wiki 기반 프로젝트 지식 요약, 연결, 온보딩

Docs/ and code
  제품/기술 source of truth
```

## 3. 핵심 원칙

- `.ai_knowledge/`는 source of truth가 아니다.
- source of truth는 코드, 제품 문서, 기술 계약 문서, ADR, 사용자 승인 기록이다.
- `.ai_knowledge/`는 Agent가 원본을 더 빨리 찾고 이해하게 돕는 지도다.
- Wiki와 원본이 충돌하면 원본이 우선한다.
- 충돌은 `.ai_project/ops_issues.md` 또는 관련 Task에 기록한다.

## 4. 기본 구조

```text
.ai_knowledge/
  README.md
  index.md
  log.md
  project_brief.md
  concepts/
    _template.md
  decisions/
    _template.md
  architecture/
    _template.md
  open_questions/
    _template.md
```

## 5. 문서 역할

| 문서 | 역할 |
|---|---|
| `README.md` | Knowledge workspace 사용 원칙 |
| `index.md` | 현재 Wiki 탐색 인덱스 |
| `log.md` | 지식 갱신 이력 |
| `project_brief.md` | 프로젝트 한눈 요약 |
| `concepts/` | 도메인 개념, 용어, 규칙 |
| `decisions/` | 여러 결정 기록을 종합한 현재 정책 설명 |
| `architecture/` | 시스템 구조 요약과 원본 링크 |
| `open_questions/` | 미해결 질문과 필요한 원본 확인 |

## 6. Agent 사용 기준

세션 시작 시 Agent는 아래 순서로 읽는다.

1. `AGENTS.md` 또는 `CLAUDE.md`
2. `.ai_project/current_context.md`
3. `.ai_knowledge/index.md` 또는 `.ai_knowledge/project_brief.md`
4. 현재 Task의 `source_of_truth`

중요한 결정이나 구현 변경 전에는 Wiki만 믿지 않고 반드시 source of truth를 확인한다.

## 7. Bootstrap 선택 후보

```text
knowledge_mode: none | minimal | full
```

| Mode | 생성 범위 | 권장 상황 |
|---|---|---|
| `none` | 생성하지 않음 | 문서가 거의 없거나 운영 상태만 필요한 경우 |
| `minimal` | README, index, log, project_brief | 기본 추천 |
| `full` | minimal + concepts, decisions, architecture, open_questions | 문서가 많거나 여러 Agent가 참여하는 경우 |

## 8. 변경 이력

| 날짜 | 변경 내용 |
|---|---|
| 2026-07-21 | LLM Wiki 기반 Knowledge Model 초안 추가 |

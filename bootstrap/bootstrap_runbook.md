# AI Ops Bootstrap Runbook

작성일: 2026-07-21  
상태: vNext Core Flow

## 1. 목적

이 문서는 Agent가 `AI Ops bootstrap 시작해줘.` 요청을 받았을 때 먼저 따라야 하는 핵심 실행 흐름이다.

상세 선택지, 질문 팩, mode별 예시는 `bootstrap/bootstrap_reference.md`를 따른다.

## 2. 원칙

- Discovery Phase에서는 파일을 수정하지 않는다.
- Apply Phase는 사용자가 최종 Draft와 파일 생성/수정 범위를 승인한 뒤에만 시작한다.
- 한 번에 전체 결론을 제안하지 않고, 질문과 답변을 Decision Stack에 쌓는다.
- 제품 아이디어 탐색은 bootstrap 중 깊게 진행하지 않는다. Apply 이후 PM Agent / Direction Role 첫 세션으로 넘긴다.
- `.ai_project/`는 운영 상태이고, `.ai_knowledge/`는 선택 가능한 Agent 온보딩용 LLM Wiki다.
- `.ai_knowledge/`는 source of truth가 아니다. 원본 문서와 코드가 우선한다.

## 3. 시작 구분

Install과 Bootstrap은 다르다.

| 요청 | 의미 | 수행 |
|---|---|---|
| `AI Ops 시드 구성해줘` | `.ai`와 adapter 지침 구성 | `aiops seed` 또는 수동 seed 안내 |
| `AI Ops bootstrap 시작해줘` | `.ai_project` 운영 구성 시작 | Discovery Phase 시작 |
| `AI Ops bootstrap 재검토해줘` | 기존 `.ai_project` 결정 재검토 | Decision Stack 기준 재검토 |

대상 프로젝트에 `.ai/`가 없으면 bootstrap을 진행하지 않는다. 먼저 seed 구성을 안내한다.

템플릿 저장소 자체에서 요청을 받은 경우, 실제 적용 대상 프로젝트인지 저장소 자체를 점검하려는 것인지 먼저 확인한다.

## 4. 첫 응답

첫 응답은 아래 정보를 짧게 보고한다.

```text
AI Ops bootstrap을 Discovery Phase로 시작합니다.
현재 단계에서는 파일을 수정하지 않습니다.

확인:
- 대상 경로:
- .ai:
- AGENTS.md:
- CLAUDE.md:
- .ai_project:
- Git:
- 추천 시작 방식:
```

그 다음 시작 방식을 묻는다.

```text
어떤 방식으로 진행할까요?

1. 빠른 시작
   - 쉬운 질문 몇 개와 안전 기본값으로 시작합니다.
   - 처음 쓰는 사용자, 비개발자, 작은 프로젝트에 적합합니다.

2. 세부 설정
   - Team, Role, Workflow, Ownership, Board, Branch/PR, Knowledge 구성을 직접 비교합니다.
```

## 5. Fast Track 기본값

Fast Track은 작게 시작하고 필요할 때 확장한다.

| 항목 | 기본값 |
|---|---|
| bootstrap_mode | `fast_track` |
| operating_mode | `solo_light` |
| team_pattern | `single_team` |
| workflow_policy | `skip_scoped_for_simple_tasks` |
| ownership_model | `path_plus_domain` |
| coordination | `single_active_task` |
| board_model | `project_board_only` |
| branch_pr | `pending_decision` |
| knowledge_mode | `minimal` |
| release_role | `inactive` |

Fast Track에서 Git/PR, 배포, multi-team, 상세 workflow override는 확정하지 않는다. 필요해지면 Guided Full로 확장한다.

## 6. Decision Stack

질문마다 아래 형식으로 갱신한다.

```text
Decision Stack

confirmed:
- target_project_path:
- bootstrap_mode:
- start_context:
- readiness_level:

pending:
- operating_mode:
- team_pattern:
- role_mapping:
- workflow_policy:
- ownership_model:
- board_model:
- branch_pr:
- knowledge_mode:
- source_of_truth:

deferred:
- release_role:
- multi_team:
- workflow_overrides:
```

필수 결정이 비어 있으면 Draft를 만들기 전에 추가 질문을 한다.

## 7. 핵심 질문 순서

Fast Track에서는 아래 질문만 사용한다.

1. 이 프로젝트는 새로 시작하는 건가요, 기존 프로젝트인가요?
2. 지금 단계는 아이디어, 기획, 구현 준비, 운영만 도입 중 어디에 가까운가요?
3. 당장 코드를 만들 계획이 있나요, 운영/기획부터 정리할까요?
4. 혼자 쓰는 작은 프로젝트인가요, 여러 Agent가 역할을 나눠야 하나요?
5. Git/PR 규칙까지 지금 정할까요, 나중에 정할까요?
6. Agent가 프로젝트 맥락을 빠르게 이해하도록 최소 Knowledge Wiki를 만들까요?

세부 설정 모드에서는 상세 질문 팩을 `bootstrap/bootstrap_reference.md`에서 필요한 단계만 꺼내 사용한다.

## 8. Draft

Decision Stack이 충분하면 최종 Draft를 제안한다.

```text
Operating Model Draft

Project:
Start Context:
Readiness Level:
Operating Mode:
Team:
Active Roles:
Agent Mapping:
Workflow Policy:
Ownership Policy:
Coordination Policy:
Board Policy:
Branch / PR Policy:
Knowledge Mode:
Source of Truth:

Files to create:
Files to update:
Files not touched:

Open Questions:
Risks:
```

Draft에는 반드시 Apply 범위를 명시한다.

## 9. Approval Gate

승인 전에는 아래 작업을 하지 않는다.

- `.ai_project/` 생성 또는 수정
- `.ai_knowledge/` 생성 또는 수정
- 제품 Task 등록
- 프로젝트 문서 수정
- branch 생성
- commit, push, PR, merge

승인 질문:

```text
위 Operating Model Draft 기준으로 아래 파일만 생성/수정하는 Apply Phase를 진행해도 될까요?
```

## 10. Apply 범위

Fast Track 기본 생성 후보:

```text
.ai_project/README.md
.ai_project/operating_model.md
.ai_project/agent_registry.md
.ai_project/current_context.md
.ai_project/source_of_truth.md
.ai_project/task_board.md
.ai_project/ops_decisions.md
.ai_project/ops_issues.md
.ai_project/tasks/active/
.ai_project/tasks/backlog/
.ai_project/tasks/archive/
.ai_project/reports/
.ai_project/qa/
.ai_knowledge/README.md
.ai_knowledge/index.md
.ai_knowledge/log.md
.ai_knowledge/project_brief.md
```

`.ai_knowledge/`는 `knowledge_mode: minimal` 이상을 사용자가 승인한 경우에만 생성한다.

Guided Full 생성 후보와 team별 확장 후보는 `bootstrap/bootstrap_reference.md`를 따른다.

## 11. Post-Apply Validation

Apply 후 아래를 실행하거나 안내한다.

```bash
aiops doctor --strict
aiops knowledge lint
```

검증 결과를 보고하고, 첫 Agent 세션 후보를 제안한다.

예:

```text
너는 PM Agent / Direction Role이야.
.ai_project/current_context.md와 .ai_knowledge/project_brief.md를 읽고 제품 방향 정리를 시작해줘.
```

## 12. 상세 Reference

아래 내용은 `bootstrap/bootstrap_reference.md`에서 확인한다.

- Start Context별 실행 차이
- Readiness 후보
- Operating Mode 후보
- Team / Role / Workflow / Ownership / Board / Branch 세부 질문
- 질문 팩
- Guided Full Apply 후보
- 예시 응답 문구

## 13. 완료 기준

- 사용자가 선택한 운영 구성이 `.ai_project/operating_model.md`에 기록된다.
- Agent / Role 매핑이 `.ai_project/agent_registry.md`에 기록된다.
- Task와 board 기준이 `.ai_project/task_board.md`와 `.ai_project/tasks/`에 연결된다.
- source of truth가 `.ai_project/source_of_truth.md`에 기록된다.
- 선택 시 `.ai_knowledge/` 최소 구조가 생성된다.
- `aiops doctor --strict`가 통과하거나 남은 문제를 명확히 보고한다.

## 14. 변경 이력

| 날짜 | 변경 내용 |
|---|---|
| 2026-07-21 | 핵심 실행 흐름으로 축소하고 상세 내용을 `bootstrap_reference.md`로 분리 |

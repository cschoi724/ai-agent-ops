# Board Model

작성일: 2026-07-10
상태: Draft vNext Slim Reference
범위: Project Board, Team Board 운영 기준

## 1. 목적

Board는 Task 현황을 빠르게 보기 위한 요약 view다.

Task의 source of truth는 `.ai_project/tasks/`의 Task 파일이다. Board는 Task 파일을 대체하지 않고, 우선순위와 상태를 한눈에 보여주는 인덱스 역할을 한다.

## 2. 기본 원칙

- Task 상태 변경은 Task 파일에 먼저 기록한다.
- Board는 Task 파일 기준으로 갱신한다.
- Board에만 있는 작업은 실행 가능한 Task가 아니다.
- 초기 프로젝트는 `project_board_only`를 기본값으로 둔다.
- Team이 둘 이상이면 Project Board와 Team Board의 관계를 명확히 한다.

## 3. Board Model

canonical 선택값은 `schemas/operating_model.schema.json`과 `runtime/bootstrap_options.json`을 따른다.

| Model | 의미 | 권장 상황 |
|---|---|---|
| `project_board_only` | 하나의 프로젝트 보드만 사용 | single team, solo_light, 초기 프로젝트 |
| `project_plus_team_board` | 전체 보드와 Team별 보드를 함께 사용 | multi-team, platform teams |
| `custom_views` | Role, domain, release 등 custom view 사용 | 복잡한 보고 체계 |

## 4. Project Board

기본 위치:

```text
.ai_project/task_board.md
```

Project Board는 아래 항목을 보여준다.

```text
active_tasks:
blocked_tasks:
verification_ready:
recently_done:
next_decisions:
cross_team_dependencies:
```

Project Board는 전체 우선순위와 병목을 보여주는 문서다.

## 5. Team Board

Team Board는 Team이 둘 이상이거나 Team별 병렬 작업이 있을 때 만든다.

기본 위치:

```text
.ai_project/teams/<team_id>/task_board.md
```

Team Board는 아래 항목을 보여준다.

```text
team_active_tasks:
team_blocked_tasks:
team_verification_ready:
owned_paths:
owned_domains:
handoff_needed:
```

Team Board가 있더라도 전체 우선순위는 Project Board에서 확인할 수 있어야 한다.

## 6. Board 갱신 책임

| 변경 | 책임 Role |
|---|---|
| Task 생성 | Lead Role |
| Task 실행 상태 변경 | 실행한 Role, 보통 Execution Role |
| 검증 상태 변경 | Verification Role |
| 완료 처리 | Completion Role 또는 Lead Role |
| 우선순위 재정렬 | Lead Role 또는 Direction Role |
| Board 구조 변경 | Ops Governance Role 또는 Lead Role |

자동 갱신 도구가 없으면 변경한 Role이 Task 파일과 Board를 함께 갱신한다.

## 7. 상태 요약

Board에는 긴 본문 대신 링크와 요약을 둔다.

권장 필드:

```text
task_id:
title:
status:
owner_role:
target_agent:
priority:
locked_paths:
next_action:
task_file:
```

상태값 정의는 `runtime/workflow.md`와 `schemas/workflow.schema.json`을 따른다.

## 8. Team Board 추가 기준

Team Board를 추가하는 조건:

- 활성 Team이 2개 이상이다.
- Team별 `owned_paths` 또는 `owned_domains`가 다르다.
- 동시에 진행되는 Task가 있고 충돌 가능성이 있다.
- Team별 검증 또는 branch 전략이 다르다.

조건을 만족하지 않으면 Project Board 하나로 유지한다.

## 9. 금지사항

- Board를 Task 파일 대신 사용하지 않는다.
- Board에 완료 처리만 하고 Task 파일을 갱신하지 않는다.
- Team Board를 만들고 Project Board와 연결하지 않는다.
- 모든 Role별 summary를 강제로 만들지 않는다.
- Board를 보고서나 회고 문서처럼 길게 쓰지 않는다.

## 10. 변경 이력

| 날짜 | 변경 내용 |
|---|---|
| 2026-07-10 | Project/Team Board 기준 추가 |
| 2026-07-27 | 중복 예시를 줄이고 slim reference로 압축 |

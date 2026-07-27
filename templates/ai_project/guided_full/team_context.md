# Team Context

작성일: {{DATE}}
프로젝트: {{PROJECT_NAME}}
Team: {{TEAM_NAME}}
상태: Draft

Team 기준은 `.ai/models/team_model.md`를 따른다. 이 파일은 프로젝트별 선택값만 기록한다.

## Identity

| 항목 | 값 |
|---|---|
| Team ID | {{TEAM_ID}} |
| Team Name | {{TEAM_NAME}} |
| Parent Division | {{PARENT_DIVISION}} |
| Team Pattern | {{TEAM_PATTERN}} |
| 상태 | active / planned / inactive |

## Role / Agent

| Role | Agent | Notes |
|---|---|---|
| Lead Role | {{TEAM_LEAD_AGENT}} | Coordination |
| Execution Role | {{EXECUTION_AGENT}} | Build/report |
| Verification Role | {{VERIFICATION_AGENT}} | QA/review |
| Completion Role | {{COMPLETION_AGENT}} | Lead may own |

## Ownership

| 유형 | 값 | Owner |
|---|---|---|
| Path | {{OWNED_PATH}} | {{OWNER}} |
| Domain | {{OWNED_DOMAIN}} | {{OWNER}} |
| Document | {{OWNED_DOCUMENT}} | {{OWNER}} |

## Operating Links

| 항목 | 경로 |
|---|---|
| Source of truth | {{SOURCE_OF_TRUTH}} |
| Team board | {{TEAM_BOARD_PATH}} |
| Project board | `.ai_project/task_board.md` |
| Branch strategy | {{BRANCH_STRATEGY_PATH}} |

## Escalation

| 상황 | 조율 주체 | 기록 위치 |
|---|---|---|
| ownership conflict | {{TEAM_LEAD_AGENT}} | Task, Board |
| cross-team dependency | {{TEAM_LEAD_AGENT}} | Task |
| blocked | Lead Role | Task |
| workflow ambiguity | AI Ops Agent | `.ai_project/ops_issues.md` |

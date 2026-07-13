# Team Context

작성일: {{DATE}}  
프로젝트: {{PROJECT_NAME}}  
Team: {{TEAM_NAME}}  
상태: Draft

## 1. 목적

이 문서는 현재 프로젝트에서 `{{TEAM_NAME}}`의 실제 운영 구성을 기록한다.

Team 구성의 일반 기준은 `.ai/models/team_model.md`를 따른다. 이 문서는 프로젝트별 선택값만 기록한다.

## 2. Team Identity

| 항목 | 값 |
|---|---|
| Team ID | {{TEAM_ID}} |
| Team Name | {{TEAM_NAME}} |
| Parent Division | {{PARENT_DIVISION}} |
| Team Pattern | {{TEAM_PATTERN}} |
| 상태 | active / planned / inactive |

## 3. Role / Agent Mapping

| Role | Agent | Capabilities | 비고 |
|---|---|---|---|
| Lead Role | {{TEAM_LEAD_AGENT}} | team_coordination, ownership_review, dependency_management | |
| Execution Role | {{EXECUTION_AGENT}} | implementation, developer_verification, task_reporting | |
| Verification Role | {{VERIFICATION_AGENT}} | qa_review, pr_review, test_execution, risk_review | |
| Completion Role | {{COMPLETION_AGENT}} | completion_review | Lead Role 겸임 가능 |

## 4. Ownership

| 유형 | 값 | Owner / Reviewer |
|---|---|---|
| Path | {{OWNED_PATH}} | {{OWNER}} |
| Domain | {{OWNED_DOMAIN}} | {{OWNER}} |
| Document | {{OWNED_DOCUMENT}} | {{OWNER}} |

## 5. Source of Truth

| 영역 | 기준 문서 |
|---|---|
| 현재 상태 | {{CURRENT_STATUS_DOC}} |
| 구현 계획 | {{IMPLEMENTATION_PLAN_DOC}} |
| 아키텍처 | {{ARCHITECTURE_DOC}} |
| QA 기준 | {{QA_DOC}} |

## 6. Board / Branch Strategy

| 항목 | 값 |
|---|---|
| Team board | {{TEAM_BOARD_PATH}} |
| Branch strategy | {{BRANCH_STRATEGY_PATH}} |
| Project board | `.ai_project/task_board.md` |
| Project branch strategy | `.ai_project/branch_pr_strategy.md` |

Team별 예외가 없으면 project board와 project branch strategy를 따른다.

## 7. Escalation

| 상황 | 조율 주체 | 기록 위치 |
|---|---|---|
| ownership conflict | {{TEAM_LEAD_AGENT}} | Task 파일, `.ai_project/task_board.md` |
| cross-team dependency | {{TEAM_LEAD_AGENT}} | Task 파일 |
| blocked | 현재 담당 Role / Lead Role | Task 파일 |
| workflow ambiguity | AI Ops Agent | `.ai_project/ops_issues.md` |

## 8. 변경 이력

| 날짜 | 변경 내용 |
|---|---|
| {{DATE}} | Team context 초기화 |

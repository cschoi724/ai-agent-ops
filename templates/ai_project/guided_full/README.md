# Guided Full AI Project Workspace

작성일: {{DATE}}
프로젝트: {{PROJECT_NAME}}
상태: Draft

## 1. 목적

이 템플릿 세트는 `guided_full` bootstrap mode에서 사용하는 상세 `.ai_project/` 구성이다.

## 2. 생성 문서

| 문서/폴더 | 역할 |
|---|---|
| `operating_model.md` | 프로젝트별 실제 운영 구성 |
| `agent_registry.md` | 현재 프로젝트 활성 Agent 구성 |
| `current_context.md` | 세션 시작 시 확인할 현재 운영 컨텍스트 |
| `source_of_truth.md` | 프로젝트 기준 문서와 충돌 처리 기준 |
| `task_board.md` | Task Queue 요약 보드 |
| `branch_pr_strategy.md` | 프로젝트별 branch / PR / merge 전략 |
| `workflow_overrides.md` | 프로젝트별 workflow 예외 |
| `ops_decisions.md` | Agent 운영 결정 기록 |
| `ops_issues.md` | AI Agent 운영 프로세스 이슈와 개선 제안 |
| `ops_migration_plan.md` | AI Agent 운영 체계 도입 계획 |
| `team_context.md` | Team별 운영 구성 템플릿 |

## 3. 적용 기준

Guided Full은 아래 상황에 사용한다.

- 사용자가 세부 설정을 선택했다.
- Team, Role, Workflow, Ownership, Board, Branch / PR 전략을 단계별로 결정했다.
- 프로젝트가 여러 Agent 또는 여러 Team으로 확장될 가능성이 높다.
- Git / PR / 검증 / 완료 판단을 명확히 문서화해야 한다.

## 4. Fast Track에서 확장

Fast Track으로 시작한 프로젝트도 아래 조건이 생기면 이 세트의 문서를 추가할 수 있다.

- `branch_pr_strategy.md`가 필요하다.
- `workflow_overrides.md`가 필요하다.
- Team별 `team_context.md` 또는 Team board가 필요하다.
- Execution / Verification / Release Role을 별도로 활성화한다.

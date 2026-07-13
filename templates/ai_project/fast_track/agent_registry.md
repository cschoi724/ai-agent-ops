# Project Agent Registry

작성일: {{DATE}}
프로젝트: {{PROJECT_NAME}}

## Active Roles

| 담당 | 상태 | Team | Role | 주요 capability |
|---|---|---|---|---|
| {{DIRECTION_AGENT}} | enabled | {{TEAM_NAME}} | Direction Role | planning, priority_management, approval |
| {{LEAD_AGENT}} | enabled | {{TEAM_NAME}} | Lead Role, Completion Role | scope_definition, ownership_review, completion_review |
| AI Ops Agent | enabled | AI Ops Governance | Ops Governance Role | process_governance, workflow_governance, ops_migration |

## Deferred / Inactive Roles

| Role | 상태 | 활성화 조건 |
|---|---|---|
| Execution Role | deferred | 구현 가능한 요구사항과 승인된 Task가 생김 |
| Verification Role | deferred | 독립 검증이 필요한 산출물이 생김 |
| Release Role | inactive | 실제 배포와 rollback 책임이 생김 |

Role 정의는 `.ai/models/role_model.md`를 따른다. 한 사람이 여러 Role을 겸하더라도 Task 상태별 책임 경계는 유지한다.

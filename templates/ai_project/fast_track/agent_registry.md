---
schema: aiops.agent_registry.v1
project: {{PROJECT_NAME}}
agents:
  - agent: {{DIRECTION_AGENT}}
    status: enabled
    team: {{TEAM_NAME}}
    roles:
      - Direction Role
    capabilities:
      - planning
      - priority_management
      - approval
  - agent: {{LEAD_AGENT}}
    status: enabled
    team: {{TEAM_NAME}}
    roles:
      - Lead Role
      - Completion Role
    capabilities:
      - scope_definition
      - ownership_review
      - completion_review
  - agent: AI Ops Agent
    status: enabled
    team: AI Ops Governance
    roles:
      - Ops Governance Role
    capabilities:
      - process_governance
      - workflow_governance
      - ops_migration
---

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

## Owner / Operator

- Owner Role은 사용자 본인만 가진다. 이 Registry에 등록하지 않는다.
- Operator Role은 기존 Role을 가진 Agent에게 Owner가 추가로 부여하는 한 세션 진행 권한이다. Operator Role만 단독으로 등록할 수 없다.
- 선택 필드: `provider`(codex, claude-code, any)는 Agent가 쓰는 도구, `runtime`(session, subagent)은 독립 세션인지 Operator 세션 안 subagent인지 나타낸다.
- 한 세션 진행 예: Lead Agent의 roles에 `Operator Role`을 추가하고, Execution과 Verification은 `runtime: subagent`인 별도 Agent(예: Dev Agent, QA Agent)로 등록한다.

---
schema: aiops.operating_model.v1
project: {{PROJECT_NAME}}
bootstrap_mode: guided_full
core_version: {{CORE_VERSION}}
core_source: {{CORE_SOURCE}}
core_update_policy: {{CORE_UPDATE_POLICY}}
start_context: {{START_CONTEXT}}
readiness_level: {{READINESS_LEVEL}}
operating_mode: {{OPERATING_MODE}}
team_pattern: {{TEAM_PATTERN}}
workflow_policy: standard_vnext
ownership_model: {{OWNERSHIP_MODEL}}
coordination: {{PARALLEL_CONTROL}}
board_model: {{BOARD_MODEL}}
branch_pr: {{BRANCH_STRATEGY_MODEL}}
knowledge_mode: {{KNOWLEDGE_MODE}}
release_role: deferred
active_roles:
  - Lead Role
  - Execution Role
  - Verification Role
  - Ops Governance Role
deferred_roles:
  - Release Role
---

# Project Operating Model

작성일: {{DATE}}
프로젝트: {{PROJECT_NAME}}
상태: Draft

## Summary

| 항목 | 선택값 |
|---|---|
| core_version | {{CORE_VERSION}} |
| core_source | {{CORE_SOURCE}} |
| core_update_policy | {{CORE_UPDATE_POLICY}} |
| start_context | {{START_CONTEXT}} |
| readiness_level | {{READINESS_LEVEL}} |
| operating_mode | {{OPERATING_MODE}} |
| team_pattern | {{TEAM_PATTERN}} |
| workflow_policy | standard_vnext |
| ownership_model | {{OWNERSHIP_MODEL}} |
| coordination | {{PARALLEL_CONTROL}} |
| board_model | {{BOARD_MODEL}} |
| branch_pr | {{BRANCH_STRATEGY_MODEL}} |
| knowledge_mode | {{KNOWLEDGE_MODE}} |
| release_role | deferred |

Canonical option definitions live in `.ai/runtime/bootstrap_options.json`.

## References

| 영역 | 기준 |
|---|---|
| 헌법 | `.ai/core/constitution.md` |
| Team | `.ai/models/team_model.md` |
| Role | `.ai/models/role_model.md` |
| Ownership | `.ai/policies/ownership_model.md` |
| Coordination | `.ai/policies/coordination_policy.md` |
| Board | `.ai/policies/board_model.md` |
| Branch / PR | `.ai/policies/branch_pr_policy.md` |
| Workflow | `.ai/runtime/workflow.md` |

## Organization

```text
{{PROJECT_ORG_STRUCTURE}}
```

## Active Team

| Team | ID | Pattern | Lead | Context |
|---|---|---|---|---|
| {{TEAM_NAME}} | {{TEAM_ID}} | {{TEAM_PATTERN}} | {{TEAM_LEAD}} | `.ai_project/teams/{{TEAM_ID}}/team_context.md` |

## Role / Agent Mapping

| Agent | Role | Notes |
|---|---|---|
| {{LEAD_AGENT}} | Lead / Direction / Completion | Scope, priority, completion review |
| {{EXECUTION_AGENT}} | Execution | Implementation and developer verification |
| {{VERIFICATION_AGENT}} | Verification | QA, review, risk check |
| {{OPS_AGENT}} | Ops Governance | Operating model governance |

Details live in `.ai_project/agent_registry.md`.

## Source Of Truth

| 영역 | 기준 문서 |
|---|---|
| 현재 상태 | {{CURRENT_STATUS_DOC}} |
| 구현 계획 | {{IMPLEMENTATION_PLAN_DOC}} |
| 아키텍처 | {{ARCHITECTURE_DOC}} |
| 결정 기록 | {{DECISIONS_DOC}} |
| 변경 이력 | {{CHANGELOG_DOC}} |

Unresolved sources remain in `.ai_project/source_of_truth.md`.

## Open Questions

| 질문 | 상태 | 결정 필요 시점 |
|---|---|---|
| {{OPEN_QUESTION}} | unresolved | {{DECISION_TIMING}} |

## Change Log

| 날짜 | 변경 내용 |
|---|---|
| {{DATE}} | Project operating model initialized |

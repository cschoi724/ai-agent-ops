---
schema: aiops.agent_registry.v1
project: {{PROJECT_NAME}}
agents:
  - agent: {{LEAD_AGENT}}
    status: enabled
    team: {{TEAM_NAME}}
    roles:
      - Lead Role
      - Direction Role
      - Completion Role
    capabilities:
      - planning
      - priority_management
      - scope_definition
      - team_coordination
      - ownership_review
      - dependency_management
      - merge_coordination
      - completion_review
  - agent: {{EXECUTION_AGENT}}
    status: enabled
    team: {{TEAM_NAME}}
    roles:
      - Execution Role
    capabilities:
      - implementation
      - refactoring
      - developer_verification
      - task_reporting
      - branch_management
      - pr_creation
  - agent: {{VERIFICATION_AGENT}}
    status: enabled
    team: {{TEAM_NAME}}
    roles:
      - Verification Role
    capabilities:
      - qa_review
      - pr_review
      - ci_check
      - test_execution
      - risk_review
      - rework_request
  - agent: {{OPS_AGENT}}
    status: enabled
    team: AI Ops Division
    roles:
      - Ops Governance Role
    capabilities:
      - ops_audit
      - process_governance
      - workflow_governance
      - agent_boundary_review
      - ops_migration
---

# Project Agent Registry

작성일: {{DATE}}
프로젝트: {{PROJECT_NAME}}

## Active Agents

| Agent | Team | Role | Notes |
|---|---|---|---|
| {{LEAD_AGENT}} | {{TEAM_NAME}} | Lead / Direction / Completion | Scope, priority, completion |
| {{EXECUTION_AGENT}} | {{TEAM_NAME}} | Execution | Build and report |
| {{VERIFICATION_AGENT}} | {{TEAM_NAME}} | Verification | Test, review, risk |
| {{OPS_AGENT}} | AI Ops Division | Ops Governance | Operating model only |

Role definitions live in `.ai/models/role_model.md`; capability definitions live in `.ai/models/capabilities.md`.

## Change Log

| 날짜 | 변경 내용 | 승인 |
|---|---|---|
| {{DATE}} | Agent / Role mapping initialized | {{APPROVER}} |

# Project Agent Registry

작성일: {{DATE}}  
프로젝트: {{PROJECT_NAME}}

## 1. 목적

이 문서는 현재 프로젝트에서 실제로 활성화된 Agent 구성을 기록한다.

사용 가능한 Agent와 기본 Role 정의는 `.ai/models/agent_registry.md`, `.ai/models/role_model.md`, `.ai/models/capabilities.md`를 따른다.

프로젝트별 실제 구성은 `.ai_project/operating_model.md`에서 선택한 Team / Role 구성을 기준으로 한다.

## 2. Active Agents

| Agent | 상태 | Team | 기본 Role | 역할 문서 | 비고 |
|---|---|---|---|---|---|
| {{LEAD_AGENT}} | `enabled` | {{TEAM_NAME}} | Lead Role, 일부 Direction/Completion Role | {{ROLE_DOC}} | |
| {{EXECUTION_AGENT}} | `enabled` | {{TEAM_NAME}} | Execution Role | {{ROLE_DOC}} | |
| {{VERIFICATION_AGENT}} | `enabled` | {{TEAM_NAME}} | Verification Role | {{ROLE_DOC}} | |
| {{OPS_AGENT}} | `enabled` | AI Ops Division | Ops Governance Role | `.ai/agents/ai_ops_agent.md` | 제품 Task 실행 라인 제외 |

## 3. Delegated Capabilities

기본 실행 capability는 프로젝트에서 선택한 Role 구성을 따른다. 운영체계 점검 capability는 Ops Governance Role이 담당한다.

| Capability | 현재 담당 | 비고 |
|---|---|---|
| `planning` | {{LEAD_AGENT}} | Direction Role 겸임 가능 |
| `priority_management` | {{LEAD_AGENT}} | |
| `scope_definition` | {{LEAD_AGENT}} | |
| `team_coordination` | {{LEAD_AGENT}} | |
| `ownership_review` | {{LEAD_AGENT}} | Owner 또는 별도 reviewer로 분리 가능 |
| `dependency_management` | {{LEAD_AGENT}} | |
| `merge_coordination` | {{LEAD_AGENT}} | branch/PR 전략에 따름 |
| `implementation` | {{EXECUTION_AGENT}} | |
| `refactoring` | {{EXECUTION_AGENT}} | |
| `developer_verification` | {{EXECUTION_AGENT}} | |
| `task_reporting` | {{EXECUTION_AGENT}} | |
| `branch_management` | {{EXECUTION_AGENT}} | task branch 범위 |
| `pr_creation` | {{EXECUTION_AGENT}} | branch/PR 전략에 따름 |
| `qa_review` | {{VERIFICATION_AGENT}} | |
| `pr_review` | {{VERIFICATION_AGENT}} | |
| `ci_check` | {{VERIFICATION_AGENT}} | |
| `test_execution` | {{VERIFICATION_AGENT}} | |
| `risk_review` | {{VERIFICATION_AGENT}} | |
| `rework_request` | {{VERIFICATION_AGENT}} | |
| `completion_review` | {{LEAD_AGENT}} | 별도 Completion Role로 분리 가능 |
| `ops_audit` | {{OPS_AGENT}} | 운영 문서와 실제 운영 상태 충돌 점검 |
| `process_governance` | {{OPS_AGENT}} | Task Queue/승인/lock/report/QA 흐름 점검 |
| `workflow_governance` | {{OPS_AGENT}} | workflow 상태와 Role 라우팅 개선 |
| `agent_boundary_review` | {{OPS_AGENT}} | Agent 역할/권한 경계와 확장 영향 검토 |
| `ops_migration` | {{OPS_AGENT}} | 새 프로젝트 또는 기존 프로젝트에 AI Agent 운영 체계 도입 |

## 4. Agent 변경 기록

| 날짜 | 변경 내용 | 승인 |
|---|---|---|
| {{DATE}} | 프로젝트 Agent / Role 매핑 초기화 | {{APPROVER}} |

# Project Agent Registry

작성일: {{DATE}}  
프로젝트: {{PROJECT_NAME}}

## 1. 목적

이 문서는 현재 프로젝트에서 실제로 활성화된 Agent 구성을 기록한다.

사용 가능한 Agent와 기본 역할 정의는 `.ai/agent_registry.md`와 `.ai/agents/`를 따른다.

## 2. Active Agents

| Agent | 상태 | 역할 문서 | 비고 |
|---|---|---|---|
| PM Agent | `enabled` | `.ai/agents/pm_agent.md` | 초기 활성 |
| Development Agent | `enabled` | `.ai/agents/development_agent.md` | 초기 활성 |
| QA Agent | `enabled` | `.ai/agents/qa_agent.md` | 초기 활성 |

## 3. Delegated Capabilities

초기에는 PM/Development/QA 기본 capability 구성을 따른다.

| Capability | 현재 담당 | 비고 |
|---|---|---|
| `planning` | PM Agent | 기본 |
| `task_routing` | PM Agent | 기본 |
| `approval_management` | PM Agent | 기본 |
| `handoff_management` | PM Agent | 기본 |
| `documentation` | PM Agent | 후속 분리 가능 |
| `release_planning` | PM Agent | 후속 분리 가능 |
| `technical_review` | PM Agent | 후속 분리 가능 |
| `implementation` | Development Agent | 기본 |
| `developer_verification` | Development Agent | 기본 |
| `dev_reporting` | Development Agent | 기본 |
| `qa_review` | QA Agent | 기본 |
| `risk_review` | QA Agent | 기본 |
| `security_check` | QA Agent | 후속 분리 가능 |
| `release_check` | QA Agent | 후속 분리 가능 |
| `rework_request` | QA Agent | 기본 |

## 4. Agent 변경 기록

| 날짜 | 변경 내용 | 승인 |
|---|---|---|
| {{DATE}} | PM/Development/QA 초기 활성 구성 | Product Owner |

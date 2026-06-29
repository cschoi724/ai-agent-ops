# Agent Registry

작성일: 2026-06-29  
상태: Draft v1  
범위: 사용 가능한 Agent와 프로젝트 활성 구성 기준

## 1. 목적

이 문서는 AI Agent 운영 템플릿에서 사용 가능한 Agent와 capability 연결 기준을 설명한다.

Agent 역할 정의는 `.ai/agents/`에 둔다. 실제 프로젝트에서 어떤 Agent를 활성화할지는 `.ai_project/agent_registry.md`에 기록한다.

초기 활성 Agent는 PM Agent, Development Agent, QA Agent 3개다. 이것은 고정 상한이 아니라 bootstrap 구성이다.

후속 단계에서 새 Agent가 필요해지면 이 문서와 `.ai/capabilities.md`에 추가한다. 새 Agent가 추가되기 전까지 분리되지 않은 책임은 PM Agent가 임시 소유하고, DEV/QA는 각자의 기본 책임을 유지한다.

## 2. 기본 원칙

- Agent 역할 정의와 프로젝트 활성화 상태를 분리한다.
- 초기 활성 구성은 PM/Development/QA지만, 프로젝트 중간에 Agent를 추가하거나 비활성화할 수 있다.
- 분리되지 않은 capability는 PM Agent가 임시 소유하고 필요 시 새 Agent로 위임한다.
- Agent 삭제보다 `disabled` 상태를 우선한다.
- Workflow는 Agent 이름보다 capability를 우선 참조한다.
- Task마다 실제 참여 Agent를 `.ai_project/handoffs/` 문서에 기록한다.
- `.ai/` 운영 문서는 `.ai/document_governance.md` 기준으로 보호한다.

## 3. 상태값

| 상태 | 의미 |
|---|---|
| `required` | 프로젝트 기본 운영에 필수 |
| `enabled` | 현재 프로젝트에서 사용 중 |
| `disabled` | 현재 사용하지 않음 |
| `planned` | 후속 도입 후보 |
| `deprecated` | 더 이상 사용하지 않지만 이력 보존 |

## 4. 초기 활성 Agents

| Agent | 상태 | 역할 문서 | Capabilities | 비고 |
|---|---|---|---|---|
| PM Agent | `required` | `.ai/agents/pm_agent.md` | `planning`, `task_routing`, `task_queue_management`, `approval_management`, `handoff_management` | 기본 진행관리와 미분리 책임 임시 소유 |
| Development Agent | `required` | `.ai/agents/development_agent.md` | `implementation`, `developer_verification`, `dev_reporting` | 구현 담당 |
| QA Agent | `required` | `.ai/agents/qa_agent.md` | `qa_review`, `risk_review`, `rework_request` | 검증 담당 |

## 5. 후속 확장 원칙

초기 템플릿에는 Optional Agent 역할 문서를 만들지 않는다.

아래 책임은 새 Agent로 분리되기 전까지 PM/Development/QA Agent 안에서 처리한다.

| 책임 영역 | v1 담당 |
|---|---|
| 구조/기술 판단 | PM Agent가 정리하고 Product Owner가 결정 |
| 문서 정리 | PM Agent가 작성, QA Agent가 검토 |
| 보안/개인정보/민감정보 로그 점검 | QA Agent 검증 관점에 포함 |
| 릴리즈/버전/배포 준비 | PM Agent가 관리, QA Agent가 검증 |
| 외부 SDK/API 조사 | PM Agent가 조사 항목 정리, Development Agent가 구현 관점 검토 |

새 Agent는 실제 운영 중 반복 부담이나 독립 검토 필요성이 명확해진 뒤 추가한다.

## 6. Agent 추가 절차

1. PM Agent가 현재 capability 소유자와 병목을 확인한다.
2. 새 Agent가 필요한 이유, 넘겨줄 책임, 기존 Agent와의 경계를 정리한다.
3. 사용자 승인을 받는다.
4. `.ai/agents/{name}_agent.md` 역할 문서를 추가한다.
5. `.ai/agent_registry.md`와 `.ai/capabilities.md`에 확장 항목과 capability 소유권 변경을 추가한다.
6. 필요한 workflow에 hook 또는 추가 검토 단계를 추가한다.
7. 첫 적용 Task의 `.ai_project/handoffs/` 문서에 활성 Agent로 기록한다.

## 7. Agent 비활성화 절차

1. `.ai_project/agent_registry.md`에서 상태를 `disabled`로 변경한다.
2. workflow에서 해당 Agent 이름이 직접 언급된 부분이 있으면 capability 기준으로 바꾼다.
3. 과거 handoff 문서는 수정하지 않는다.
4. 역할 문서는 삭제하지 않고 보관한다.
5. PM/Development/QA 비활성화는 일반적으로 권장하지 않지만, 프로젝트 특수 상황에서는 사용자 승인 후 `.ai_project/agent_registry.md`에 명시한다.

## 8. Task별 참여 Agent 기록 형식

`.ai_project/handoffs/` 문서에는 아래 항목을 포함한다.

```text
## Active Agents For This Task

- PM Agent
- Development Agent
- QA Agent
- [후속 확장 Agent가 실제 활성화된 경우에만 추가]

## Active Capabilities

- planning
- implementation
- qa_review
- [optional capability]
```

## 9. 변경 이력

| 날짜 | 변경 내용 |
|---|---|
| 2026-06-29 | Agent Registry v1 작성 |

# Agent Registry

작성일: 2026-06-29  
상태: Draft vNext  
범위: 사용 가능한 Agent, Role, capability 연결 기준

## 1. 목적

이 문서는 AI Agent 운영 템플릿에서 사용할 수 있는 기본 Agent 이름과 Role / capability 연결 기준을 설명한다.

vNext의 실행 기준은 Agent 문서가 아니라 Role 모델이다. 실제 프로젝트에서 어떤 Agent 이름을 쓸지는 `.ai_project/agent_registry.md`와 `.ai_project/operating_model.md`에 기록한다.

PM Agent, Development Agent, QA Agent는 더 이상 개별 운영 문서로 관리하지 않는다. 이 이름들은 bootstrap 예시일 뿐이며, 실제 프로젝트는 `Lead Agent`, `Execution Agent`, `Verification Agent`처럼 자유롭게 이름을 정할 수 있다.

AI Ops Agent만 특수 Agent 참고 문서로 유지한다. 이유는 제품 Task 실행 라인 밖에서 운영체계 자체를 점검하는 책임이 일반 실행 Role과 다르기 때문이다.

## 2. 기본 원칙

- Role 책임 정의와 프로젝트 활성 Agent 이름을 분리한다.
- 기본 실행 구성은 Lead / Execution / Verification Role이다.
- Agent 이름은 프로젝트별로 자유롭게 정할 수 있다.
- capability는 Agent 이름이 아니라 Role과 Team에 위임한다.
- 프로젝트 안에서 활성 Agent를 없앨 때는 삭제보다 `disabled` 상태 기록을 우선한다.
- Workflow는 Agent 이름보다 capability를 우선 참조한다.
- Task마다 실제 참여 Agent와 capability를 `.ai_project/tasks/` Task 파일에 기록한다.
- `.ai/` 운영 문서는 `.ai/policies/document_governance.md` 기준으로 보호한다.
- Ops Governance Role 또는 AI Ops Agent는 제품 Task의 `target_agent`가 되지 않으며 제품 Task 상태를 변경하지 않는다.

## 3. 상태값

| 상태 | 의미 |
|---|---|
| `required` | 프로젝트 기본 운영에 필수 |
| `enabled` | 현재 프로젝트에서 사용 중 |
| `disabled` | 현재 사용하지 않음 |
| `planned` | 후속 도입 후보 |
| `deprecated` | 더 이상 사용하지 않지만 이력 보존 |

## 4. 기본 Role / Agent 구성

| 기본 Agent 이름 | 상태 | 기본 Role | Capabilities | 비고 |
|---|---|---|---|---|
| {{LEAD_AGENT}} | `required` | Lead Role, 일부 Direction/Completion Role | `planning`, `priority_management`, `scope_definition`, `team_coordination`, `ownership_review`, `completion_review`, `merge_coordination` | 프로젝트별 이름 지정 |
| {{EXECUTION_AGENT}} | `required` | Execution Role | `implementation`, `refactoring`, `documentation`, `developer_verification`, `task_reporting`, `branch_management`, `pr_creation` | 프로젝트별 이름 지정 |
| {{VERIFICATION_AGENT}} | `required` | Verification Role | `qa_review`, `pr_review`, `ci_check`, `test_execution`, `risk_review`, `security_check`, `rework_request` | 프로젝트별 이름 지정 |
| AI Ops Agent | `enabled` 또는 `planned` | Ops Governance Role | `ops_audit`, `process_governance`, `workflow_governance`, `agent_boundary_review`, `ops_migration` | 제품 Task 실행 라인 밖의 운영체계 점검 |

## 5. 후속 확장 원칙

초기 템플릿에는 제품 실행 Agent 역할 문서를 만들지 않는다. 제품 실행 책임은 Role 모델로 처리한다.

아래 책임은 새 Role 또는 Team으로 분리되기 전까지 기본 Role 안에서 처리한다.

| 책임 영역 | 기본 담당 |
|---|---|
| 구조/기술 판단 | Lead Role이 정리하고 Product Owner가 결정 |
| 문서 정리 | Execution Role이 작성, Verification Role이 검토 |
| 보안/개인정보/민감정보 로그 점검 | Verification Role 검증 관점에 포함 |
| 릴리즈/버전/배포 준비 | Release Role 활성화 전까지 Lead/Verification/Completion Role이 분담 |
| 외부 SDK/API 조사 | Lead Role이 조사 항목 정리, Execution Role이 구현 관점 검토 |
| Agent 운영 프로세스 점검 | AI Ops Agent가 독립 점검, 제품 실행 Role 권한 변경 없음 |
| AI 운영 마이그레이션 | AI Ops Agent가 주도, Lead Role이 제품/일정 영향 검토 |

새 실행 Agent 이름은 프로젝트 bootstrap 또는 운영 중 사용자 승인으로 추가한다. AI Ops Agent는 실행 Agent가 아니라 운영 점검 Agent이므로 프로젝트 초기에 선택 활성화할 수 있다.

## 6. Agent 추가 절차

1. Lead Role이 현재 capability 소유자와 병목을 확인한다.
2. 새 Agent가 필요한 이유, 넘겨줄 책임, 기존 Agent와의 경계를 정리한다.
3. 사용자 승인을 받는다.
4. `.ai_project/agent_registry.md`와 `.ai_project/operating_model.md`에 Agent / Role 매핑을 기록한다.
5. 필요한 경우 `.ai/models/capabilities.md`에 일반 capability 확장 항목을 추가한다.
6. 필요한 workflow에 hook 또는 추가 검토 단계를 추가한다.
7. 첫 적용 Task의 `.ai_project/tasks/` Task 파일에 활성 Agent로 기록한다.

AI Ops Agent는 제품 Task 실행 라인에 포함하지 않는다. 프로젝트에서 활성화할 때는 `.ai_project/agent_registry.md`에 상태를 기록하고, 운영 점검 결과는 `.ai_project/ops_issues.md`에 남긴다. 새 프로젝트 또는 기존 프로젝트에 AI 운영 체계를 도입할 때는 `.ai/workflows/ops_migration.md`를 따른다.

## 7. Agent 비활성화 절차

1. `.ai_project/agent_registry.md`에서 상태를 `disabled`로 변경한다.
2. workflow에서 해당 Agent 이름이 직접 언급된 부분이 있으면 capability 기준으로 바꾼다.
3. 과거 Task/report/QA 문서는 수정하지 않는다.
4. 대체 Role 또는 Agent가 없으면 관련 Task를 승인하지 않는다.

## 8. Task별 참여 Agent 기록 형식

`.ai_project/tasks/` Task 파일에는 아래 항목을 포함한다.

```text
## Active Agents For This Task

- {{LEAD_AGENT}}
- {{EXECUTION_AGENT}}
- {{VERIFICATION_AGENT}}
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
| 2026-06-29 | 초기 Agent capability 목록을 Capabilities 문서와 정합화 |
| 2026-06-30 | AI Ops Agent 독립 운영 기준 추가 |
| 2026-07-01 | AI Ops Agent 운영 마이그레이션 책임 추가 |
| 2026-07-09 | vNext Role 기반 capability 매핑 반영 |
| 2026-07-09 | PM/Development/QA 개별 Agent 문서 제거 후 프로젝트별 Agent 이름 매핑 기준으로 개정 |

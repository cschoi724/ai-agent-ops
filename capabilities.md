# Capabilities

작성일: 2026-06-29  
상태: Draft v1  
범위: Agent가 제공하는 기능 단위 정의

## 1. 목적

이 문서는 Agent가 제공하는 capability와 초기 소유자를 정의한다.

초기 실행 Agent는 PM, Development, QA다. AI Ops Agent는 실행 흐름 밖에서 운영 프로세스를 독립 점검하는 선택 활성 Agent다. 새 실행 Agent가 추가되기 전까지 분리되지 않은 capability는 PM Agent가 임시 소유하거나 QA 검증 관점에 포함한다.

## 2. 기본 원칙

- Workflow는 Agent 이름보다 capability를 우선 참조한다.
- 하나의 Agent는 여러 capability를 가질 수 있다.
- 초기 capability는 PM/Development/QA 중 하나에 배정한다.
- 보안, 문서, 릴리즈, 기술 조사 같은 관점은 새 Agent가 생기기 전까지 PM/QA 검토 항목에 통합한다.
- 새 Agent가 추가되면 capability 소유권을 PM에서 해당 Agent로 위임할 수 있다.
- capability 추가/삭제는 `.ai/document_governance.md` 기준으로 사용자 승인 후 진행한다.
- AI Ops Agent의 capability는 제품 Task 실행 capability가 아니라 운영 프로세스 점검 capability다.

## 3. Core Capabilities

| Capability | 설명 | 초기 담당 Agent |
|---|---|---|
| `planning` | 현재 상태 파악, 다음 작업 후보 정리 | PM Agent |
| `task_routing` | Task 유형 분류와 workflow 선택 | PM Agent |
| `task_queue_management` | `.ai_project/tasks/` Task 생성, 상태 관리, 요약 갱신 | PM Agent |
| `approval_management` | 사용자 승인 게이트 관리 | PM Agent |
| `documentation` | Task 문서, 운영 문서, 변경 요약 작성 | PM Agent |
| `release_planning` | 버전, 릴리즈 범위, 배포 승인 항목 정리 | PM Agent |
| `technical_review` | 기술 선택지, 구조 영향, 외부 SDK/API 조사 항목 정리 | PM Agent |
| `implementation` | 승인된 범위의 코드/문서 구현 | Development Agent |
| `developer_verification` | 개발자가 수행하는 빌드/테스트 확인 | Development Agent |
| `dev_reporting` | 개발 완료 보고 작성 | Development Agent |
| `qa_review` | 변경 결과 검증 | QA Agent |
| `risk_review` | 회귀 위험과 잔여 리스크 정리 | QA Agent |
| `security_check` | 인증, 권한, 개인정보, 민감정보 로그 노출 점검 | QA Agent |
| `release_check` | 배포 전 검증 항목 확인 | QA Agent |
| `rework_request` | rework 요청 작성 | QA Agent |
| `ops_audit` | Agent 운영 문서와 실제 운영 상태의 충돌 점검 | AI Ops Agent |
| `process_governance` | Task Queue, 승인, lock, report/QA 흐름의 운영 규칙 점검 | AI Ops Agent |
| `agent_boundary_review` | Agent 역할/권한/책임 경계와 새 Agent 추가 영향 검토 | AI Ops Agent |

## 4. 후속 위임 기준

아래 상황이 반복되면 PM Agent가 새 Agent 분리 또는 capability 위임을 제안한다.

- PM Agent의 기획/조사/문서/릴리즈 책임이 과도하게 커진다.
- QA Agent의 보안/릴리즈 검증 책임이 반복적으로 커진다.
- 특정 책임이 여러 Task에서 독립 검토 단계로 계속 필요하다.
- Product Owner가 해당 역할을 별도 Agent로 분리하길 원한다.

후속 분리 후보는 역할 문서로 미리 만들지 않는다. 실제 필요가 생겼을 때 역할 문서, registry, capability 소유권, workflow hook을 함께 추가한다.

## 5. Capability Hook 예시

Workflow 문서에서는 아래처럼 capability hook을 사용한다.

```text
Task가 인증/권한/개인정보/로그를 건드리면 QA Agent의 security_check 관점을 필수 검증 항목에 추가한다.
```

초기에는 별도 전문 Agent를 만들지 않고 QA Agent의 검증 관점으로 처리한다. 이후 보안 검토가 반복 병목이 되면 해당 capability를 새 Agent로 위임할 수 있다.

## 6. Capability 추가 기준

새 capability는 아래 조건 중 하나 이상을 만족할 때 추가한다.

- 여러 workflow에서 반복적으로 필요하다.
- 특정 Agent의 핵심 책임을 명확히 분리해야 한다.
- 기존 capability로 표현하면 책임이 모호해진다.
- 프로젝트 중간에 Agent 교체 가능성을 열어둬야 한다.

## 7. 변경 이력

| 날짜 | 변경 내용 |
|---|---|
| 2026-06-29 | Capability 정의 v1 작성 |
| 2026-06-29 | Task Queue 관리 capability 추가 |
| 2026-06-30 | AI Ops Agent 운영 점검 capability 추가 |

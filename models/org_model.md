# Organization Model

작성일: 2026-07-09  
상태: Draft vNext  
범위: 조직형 AI Agent 운영체계의 Organization / Division / Team 모델

## 1. 목적

이 문서는 `ai-agent-ops` vNext에서 조직 단위를 정의한다.

조직 모델의 목적은 Task가 어느 책임 영역에 속하는지, 어느 팀이 ownership을 갖는지, 어떤 Lead Role이 조율해야 하는지를 명확히 하는 것이다.

조직 모델은 Agent 이름을 정의하지 않는다. Agent는 Role을 수행하는 실행자이고, 조직 모델은 책임 영역을 정의한다.

Team의 구성 패턴, 최소 계약, 프로젝트별 선택 기준은 `team_model.md`를 따른다.

## 2. 조직 계층

vNext 조직 계층은 아래를 기본으로 한다.

```text
Organization
  Division
    Team
      Role
        Capability
          Task
```

각 계층의 의미:

| 계층 | 의미 | 예시 |
|---|---|---|
| Organization | 운영체계 전체 | AI Agent Ops Organization |
| Division | 큰 책임 영역 | Development Division |
| Team | 실제 실행과 ownership의 기본 단위 | iOS Team |
| Role | 현재 세션 또는 Agent가 맡는 책임 | Execution Role, Selected Team Lead |
| Capability | Role이 수행할 수 있는 능력 | implementation, qa_review |
| Task | 실행 가능한 단위 작업 | T-YYYYMMDD-001 |

## 3. 장기 Division 구조

장기 목표 조직은 아래 Division을 포함한다.

```text
AI Agent Ops Organization
  Planning Division
  Design Division
  Development Division
  QA Division
  Release / Operations Division
  Business Division
  AI Ops Division
```

각 Division의 기본 책임:

| Division | 기본 책임 | 초기 상태 |
|---|---|---|
| Planning Division | 제품 방향, 요구사항, 우선순위, 로드맵, 의사결정 정리 | planned |
| Design Division | UX/UI, 사용자 흐름, 디자인 시스템, 디자인 QA | planned |
| Development Division | 구현, 기술 설계, 리팩터링, 빌드, 플랫폼별 개발 | active |
| QA Division | 테스트 전략, 검증, 회귀 위험, 릴리즈 리스크 | planned |
| Release / Operations Division | 배포 준비, 릴리즈 노트, 운영 체크리스트, 롤백 판단 | planned |
| Business Division | 시장, 정책, 수익화, 사용자/운영 전략 | planned |
| AI Ops Division | Agent 운영 규칙, workflow 개선, 역할 충돌, 운영체계 진화 | active |

`planned` Division은 문서상 책임 경계만 정의하고, 실제 Task 라우팅에는 기본 참여하지 않는다. 해당 책임이 반복적으로 필요해지면 활성화한다.

## 4. 초기 활성 조직

초기 실운영 범위는 프로젝트 bootstrap에서 선택한다.

단순한 PR 기반 개발 프로젝트는 아래 구성을 기본 후보로 사용할 수 있다.

```text
AI Agent Ops Organization
  Development Division
    Product Team 또는 Platform Team
  AI Ops Division
```

초기 활성 조직의 목적:

- 하나의 Team이 조직형 Task 흐름을 끝까지 실행할 수 있는지 검증한다.
- Team Lead와 Execution / Verification / Completion Role의 경계를 확인한다.
- `org_unit`, `team`, `team_lead`, `target_role`, `allowed_paths`, `source_of_truth` metadata가 실제 운영에 충분한지 검증한다.
- 운영 중 모호성을 AI Ops Division이 기록하고 모델을 개선한다.

초기 Team이 iOS Team, Product Team, Mobile Team 중 무엇인지는 이 문서가 고정하지 않는다. 실제 선택값은 `.ai_project/operating_model.md`에 기록한다.

## 5. Development Division

Development Division은 구현, 기술 설계, 리팩터링, 빌드, 플랫폼별 개발 책임을 가진다.

기본 구조:

```text
Development Division
  Development Lead
  Team...
```

Development Division은 여러 Team을 가질 수 있다. Team 구성 패턴과 활성화 기준은 `team_model.md`를 따른다.

### 5.1 Development Lead

Development Lead는 Development Division 안의 cross-team 조율 책임이다.

책임:

- 팀 간 우선순위 조율
- cross-platform dependency 관리
- 공통 아키텍처 영향 판단
- release 영향과 병렬 작업 가능 여부 조율
- 팀 간 ownership 충돌 조정
- 필요한 경우 Direction Role 또는 Product Owner에게 결정 항목 보고

Development Lead는 모든 구현을 직접 수행하지 않는다. 실제 구현은 각 Team의 Execution Role이 담당한다.

### 5.2 Team 후보

Development Division에서 선택할 수 있는 Team 후보:

- Product Team
- iOS Team
- Android Team
- Web Team
- Backend Team
- Infrastructure Team
- Feature Team
- Module Team
- Custom Team

이 목록은 예시다. 실제 프로젝트에서 활성화할 Team 이름, 책임, Role 매핑은 `.ai_project/operating_model.md`와 `.ai_project/agent_registry.md`에 기록한다.

## 6. AI Ops Division

AI Ops Division은 운영체계 자체를 관리한다.

책임:

- Agent 운영 규칙 점검
- workflow 개선
- Task metadata 표준화
- Role / Capability 경계 점검
- 병렬 작업 충돌과 ownership 정책 개선
- 운영 이슈 기록
- migration plan 작성

AI Ops Division은 기본 제품 Task 실행 라인에 참여하지 않는다. 운영체계 개선 Task는 별도 Task로 다룬다.

AI Ops 기록 위치:

```text
.ai_project/ops_issues.md
.ai_project/ops_decisions.md
.ai_project/ops_migration_plan.md
```

## 7. Planned Divisions

### 7.1 Planning Division

Planning Division은 제품 방향과 요구사항을 책임진다.

초기에는 Direction Role 또는 Lead Role이 이 책임을 bootstrap으로 수행한다. 제품 전략, 로드맵, 요구사항 분해가 반복 병목이 되면 별도 Division으로 활성화한다.

### 7.2 Design Division

Design Division은 UX/UI와 디자인 시스템을 책임진다.

초기에는 Design Task가 생기면 Direction Role이 Task를 정리하고, 필요한 경우 Execution Role 또는 외부 source of truth를 연결한다. 디자인 산출물이 반복적으로 workflow를 요구하면 활성화한다.

### 7.3 QA Division

QA Division은 테스트 전략, 검증 품질, 회귀 위험을 책임진다.

초기에는 Verification Role이 이 책임을 bootstrap으로 수행한다. 여러 팀의 검증 기준이 분산되거나 release risk가 커지면 별도 QA Division으로 활성화한다.

### 7.4 Release / Operations Division

Release / Operations Division은 배포 준비와 운영 인계를 책임진다.

초기에는 Release Role을 비활성으로 둘 수 있다. 배포, 롤백, 운영 체크리스트가 반복적으로 커지면 별도 Division과 workflow를 활성화한다.

### 7.5 Business Division

Business Division은 시장, 정책, 수익화, 운영 전략을 책임진다.

초기에는 Product Owner 또는 Direction Role의 판단으로 처리한다. 비즈니스 판단이 Task 흐름에 반복적으로 영향을 주면 활성화한다.

## 8. Task Metadata 연결

조직 모델은 Task metadata의 아래 필드로 연결된다.

```yaml
org_unit: Development Division
team: Selected Team
team_lead: Selected Team Lead
target_agent: Selected Execution Agent
target_role: Execution Role
required_capabilities:
  - implementation
allowed_paths:
  - path/to/project-area/
source_of_truth:
  - docs/current_status.md
```

필드 의미:

| 필드 | 의미 |
|---|---|
| `org_unit` | 상위 Division 책임 |
| `team` | 실제 실행과 ownership 책임 Team |
| `team_lead` | scope, dependency, ownership 조율 책임 |
| `target_agent` | 기존 호환 실행자 라우팅 |
| `target_role` | vNext 책임 Role 라우팅 |
| `required_capabilities` | 실행에 필요한 능력 |
| `allowed_paths` | 수정 가능한 범위 |
| `source_of_truth` | 판단 기준 문서 |

## 9. 활성화 기준

새 Division 또는 Team은 아래 조건 중 하나 이상을 만족할 때 활성화한다.

- 해당 책임이 여러 Task에서 반복된다.
- 기존 Role이 책임을 임시로 맡기 어려울 정도로 병목이 생긴다.
- ownership 충돌이 반복된다.
- 병렬 작업 조율이 필요하다.
- 별도 검증 또는 승인 게이트가 필요하다.
- Product Owner가 별도 조직 단위로 관리하길 원한다.

활성화할 때는 아래 문서를 함께 갱신한다.

- `.ai/models/agent_registry.md`
- `.ai/models/capabilities.md`
- `.ai/runtime/workflow.md` 또는 `.ai/workflows/*.md`
- `.ai_project/agent_registry.md`
- `.ai_project/task_board.md`
- 관련 ownership 문서

## 10. 금지사항

- Agent 이름을 조직 단위로 취급하지 않는다.
- PM/Development/QA만 존재한다고 가정하지 않는다.
- 모든 Task가 Development Division 소속이라고 가정하지 않는다.
- `team`이 비어 있는데 Team ownership이 필요한 작업을 승인하지 않는다.
- `allowed_paths` 없이 실행 Team을 지정하지 않는다.
- Planned Division을 실제 승인/완료 주체처럼 사용하지 않는다.

## 11. 변경 이력

| 날짜 | 변경 내용 |
|---|---|
| 2026-07-09 | 조직형 AI Agent 운영체계의 Organization / Division / Team 모델 초안 작성 |
| 2026-07-09 | Team 상세 구성 예시를 team_model.md로 분리하고 org_model은 Division/조직 책임 중심으로 정리 |

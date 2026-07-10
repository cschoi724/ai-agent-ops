# AI Agent Ops Constitution

작성일: 2026-07-09  
상태: Draft vNext  
범위: 조직형 AI Agent 운영체계의 최상위 원칙

## 1. 목적

`ai-agent-ops`는 AI Agent에게 개별 작업을 지시하기 위한 문서 묶음이 아니라, 여러 AI Agent를 하나의 조직처럼 운영하기 위한 운영체계다.

이 운영체계의 목적은 아래와 같다.

- Task를 실행 지시의 기준으로 삼는다.
- 조직, 팀, Role, Capability, Workflow, Task를 분리한다.
- 여러 Agent가 같은 프로젝트에서 충돌 없이 병렬 또는 순차 협업할 수 있게 한다.
- 프로젝트 코드 구조를 템플릿이 고정하지 않고, Task metadata와 프로젝트별 source of truth가 실제 범위를 정하게 한다.
- 현재 안정 운영모델을 참고하되, 차세대 조직형 모델에서는 PM/Development/QA 3분할에 갇히지 않는다.

## 2. 최상위 원칙

### 2.0 중심 흐름

조직형 운영체계의 기본 흐름은 작업자 순서가 아니라 책임 단계 순서다.

```text
Need
  -> Direction
  -> Coordination
  -> Execution
  -> Verification
  -> Completion
  -> Learning / Ops Improvement
```

기본 상태 흐름은 아래를 따른다.

```text
proposed
  -> scoped
  -> approved
  -> in_progress
  -> verification_ready
  -> verification_in_progress
  -> verification_passed
  -> completion_review
  -> done
```

개별 workflow가 더 짧거나 긴 흐름을 가져야 하면 `.ai/workflows/`에 명시한다.

### 2.1 Task 중심 운영

모든 실행 지시는 Task 파일을 기준으로 한다.

대화, 임시 메모, 구두 지시, 세션 히스토리는 Task 파일을 대체하지 않는다. Agent는 실행 전에 Task의 현재 상태, 담당 Role, workflow, 승인, 의존성, lock, 허용 경로, 기준 문서를 확인해야 한다.

### 2.2 조직과 실행의 분리

조직형 운영모델은 아래 개념을 분리한다.

```text
Organization = 운영체계 전체
Division     = 큰 책임 영역
Team         = 실제 실행과 ownership의 기본 단위
Role         = 현재 세션 또는 Agent가 맡은 책임
Capability   = Role이 수행할 수 있는 능력
Workflow     = Task 상태 전이 절차
Task         = 실행 가능한 단위 작업
```

Agent 이름은 조직 구조 자체가 아니다. Agent는 특정 Role을 수행하는 실행자다.

### 2.3 실행 판단 기준

Agent는 아래 조건을 기준으로 Task 실행 가능 여부를 판단한다.

- 현재 세션 Role이 사용자에 의해 부여되었는가
- Task의 `org_unit`과 `team`이 현재 운영 범위와 맞는가
- Task의 `workflow`와 `status`가 현재 Role의 전이를 허용하는가
- Task의 `target_agent` 또는 후속 `target_role`이 현재 Role과 맞는가
- Task의 `required_capabilities`를 현재 Role이 수행할 수 있는가
- `approved_by`가 필요한 상태에서 비어 있지 않은가
- `depends_on`이 모두 완료되었는가
- `locked_by`가 비어 있거나 현재 세션의 lock인가
- 실제 작업 범위가 `allowed_paths` 안에 있는가
- 판단 기준 문서가 `source_of_truth`에 명시되어 있는가

Capability가 맞더라도 `target_agent` 또는 `target_role`이 맞지 않으면 실행하지 않는다. 조직형 모델에서도 명시적 라우팅이 capability 추론보다 우선한다.

### 2.4 범위 제한

Agent가 수정할 수 있는 범위는 Task의 `allowed_paths`가 정한다.

Agent가 판단 기준으로 삼아야 하는 문서는 Task의 `source_of_truth`가 정한다.

조직형 모델은 프로젝트의 코드 디렉토리 구조, 플랫폼 경로, 문서 위치를 고정하지 않는다. 각 프로젝트의 실제 구조는 `.ai_project/`와 Task metadata가 기록한다.

### 2.5 한 단계 전이 원칙

기본값은 한 Agent가 한 번에 하나의 workflow 단계만 처리하는 것이다.

Workflow가 명시적으로 연속 전이를 허용하지 않는 한, Agent는 다음 Role의 단계까지 이어서 처리하지 않는다. 상태를 넘긴 뒤 `target_agent` 또는 `target_role`이 바뀌면 다음 Role에게 인계한다.

### 2.6 병렬 작업 안전성

여러 Agent가 동시에 작업하려면 아래 조건이 모두 충족되어야 한다.

- 각 Task의 `depends_on`이 완료되어 있다.
- `allowed_paths`가 충돌하지 않는다.
- 같은 ownership 영역을 동시에 수정하지 않는다.
- 같은 source of truth 문서를 동시에 수정하지 않는다.
- 각 Agent는 하나의 in-progress Task만 가진다.
- Team Lead 또는 coordination policy가 병렬 실행을 허용한다.

병렬성은 기본 권리가 아니라 조율된 실행 상태다.

## 3. 조직 모델

조직형 운영체계는 아래 Division을 장기 목표로 둔다.

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

각 Division의 기본 책임은 아래와 같다.

| Division | 기본 책임 |
|---|---|
| Planning Division | 제품 방향, 요구사항, 우선순위, 로드맵, 의사결정 정리 |
| Design Division | UX/UI, 사용자 흐름, 디자인 시스템, 디자인 QA |
| Development Division | 구현, 기술 설계, 리팩터링, 빌드, 플랫폼별 개발 |
| QA Division | 테스트 전략, 검증, 회귀 위험, 릴리즈 리스크 |
| Release / Operations Division | 배포 준비, 릴리즈 노트, 운영 체크리스트, 롤백 판단 |
| Business Division | 시장, 정책, 수익화, 사용자/운영 전략 |
| AI Ops Division | Agent 운영 규칙, workflow 개선, 역할 충돌, 운영체계 진화 |

## 4. 초기 운영 범위

처음부터 모든 Division을 활성화하지 않는다.

초기 실운영 범위는 프로젝트 bootstrap에서 선택한 최소 Team으로 제한한다.

```text
AI Agent Ops Organization
  Development Division
    Selected Team
  AI Ops Division
```

초기 목표는 하나의 Team이 조직형 모델로 안정적으로 작업을 받고, 실행하고, 검증하고, 보고할 수 있는지를 확인하는 것이다.

확장 순서는 아래를 권장한다.

```text
Phase 1: Development Division / Selected Team / AI Ops Division
Phase 2: Platform Team, Feature Team, Module Team 추가
Phase 3: Planning Division, Design Division, QA Division 분리
Phase 4: Business Division, Release / Operations Division 분리
```

## 5. Role 모델

Role은 현재 세션 또는 Agent가 맡는 책임이다.

초기 조직형 모델은 PM/Development/QA 고정 구성을 최상위 전제로 삼지 않는다. 대신 아래 범주를 사용한다.

| Role 범주 | 의미 |
|---|---|
| Direction Role | 방향, 우선순위, 승인, 범위 판단 |
| Lead Role | 팀 단위 조율, ownership, 의존성, 병렬 작업 판단 |
| Execution Role | 구현, 문서 작성, 리팩터링, 분석 등 실제 작업 |
| Verification Role | 검증, 테스트, 리스크, rework 판단 |
| Release Role | 배포 준비, 릴리즈 판단, 운영 인계 |
| Ops Governance Role | 운영 규칙, workflow, 역할 충돌, 문서 체계 개선 |

기존 PM Agent, Development Agent, QA Agent, AI Ops Agent는 이 Role 범주 위에 매핑되는 bootstrap Role로 본다.

## 6. Capability 모델

Capability는 Agent 이름이 아니라 수행 가능한 능력이다.

예시:

```text
planning
task_routing
scope_definition
team_coordination
ownership_review
implementation
developer_verification
qa_review
risk_review
release_check
completion_review
process_governance
workflow_governance
```

하나의 Role은 여러 capability를 가질 수 있고, 하나의 capability는 운영 성숙도에 따라 다른 Role로 위임될 수 있다.

Workflow는 가능하면 Agent 이름보다 capability와 Role 범주를 기준으로 설계한다. 단, 실제 실행 라우팅에서는 명시된 `target_agent` 또는 `target_role`을 우선한다.

## 7. Task 모델

조직형 Task는 기존 필드를 유지하면서 아래 metadata를 확장한다.

```yaml
org_unit: Development Division
team: Selected Team
team_lead: Selected Team Lead
target_agent: Selected Execution Agent
target_role:
workflow: feature
status: approved
priority: P1
depends_on: []
blocks: []
parallel_group:
required_capabilities:
  - implementation
allowed_paths:
  - path/to/project-area/
source_of_truth:
  - docs/current_status.md
```

`target_agent`는 기존 호환성을 위해 유지한다. 장기적으로 `target_role`을 도입할 수 있지만, migration plan 없이 기존 필드를 제거하지 않는다.

## 8. Ownership 모델

Ownership은 어떤 팀 또는 Role이 특정 영역의 변경 책임을 갖는지를 뜻한다.

초기 ownership은 path 기반으로 시작한다.

```text
path/to/ios/auth/       iOS Team / Auth Owner
path/to/ios/webview/    iOS Team / WebView Owner
docs/release/           Release Owner
```

필요하면 이후 domain ownership을 추가한다.

```text
Auth Domain             iOS Team + Android Team + Backend Team
Payment Domain          Business Division + Backend Team + QA Division
```

Cross-team 변경은 소유 팀 또는 Lead Role의 검토가 필요하다.

## 9. Board 모델

Task 파일은 source of truth이고, board는 요약판이다.

초기에는 단일 board를 유지한다.

```text
.ai_project/task_board.md
```

팀이 늘어나면 team board를 추가할 수 있다.

```text
.ai_project/
  task_board.md
  teams/
    ios/
      team_context.md
      task_board.md
    android/
      team_context.md
      task_board.md
```

Team board는 실행 편의를 위한 요약판이며, Task 파일을 대체하지 않는다.

## 10. 고정하지 않는 것

이 운영체계는 아래를 고정하지 않는다.

- 프로젝트 코드 디렉토리 구조
- iOS, Android, Web, Backend 같은 플랫폼 경로
- 모든 프로젝트가 같은 문서 구조를 갖는다는 가정
- 모든 Task가 Dev -> QA -> PM 흐름을 탄다는 가정
- PM/Development/QA만 존재한다는 가정
- 모든 팀이 하나의 Task Board만 사용한다는 가정
- 모든 검증이 QA Division에서만 수행된다는 가정

## 11. 개정 원칙

이 브랜치의 목적은 조직형 운영모델을 설계하는 것이다. 따라서 이 브랜치에서는 기존 v1 안정 모델을 보존하기보다, 차세대 운영체계에 맞도록 문서와 템플릿을 재구성할 수 있다.

다만 실제 프로젝트에 적용할 때는 아래 원칙을 따른다.

- 현재 운영 중인 프로젝트에는 자동 적용하지 않는다.
- 기존 `.ai_project/`를 자동 마이그레이션하지 않는다.
- 기존 Task metadata를 일괄 변경하지 않는다.
- migration plan과 사용자 승인을 거친 뒤 적용한다.
- main 안정 운영모델과 호환이 필요한 부분은 migration 문서에 명시한다.

## 12. 다음 개정 대상

이 헌법에 맞춰 다음 문서를 순서대로 개정한다.

1. `README.md`
2. `workflow.md`
3. `agent_registry.md`
4. `capabilities.md`
5. `task_queue.md`
6. `project_workspace.md`
7. `agents/`
8. `workflows/`
9. `templates/`

## 13. 변경 이력

| 날짜 | 변경 내용 |
|---|---|
| 2026-07-09 | 조직형 AI Agent 운영체계 헌법 초안 작성 |

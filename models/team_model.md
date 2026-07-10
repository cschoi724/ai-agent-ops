# Team Model

작성일: 2026-07-09  
상태: Draft vNext  
범위: 조직형 AI Agent 운영체계의 Team 구성 패턴과 선택 기준

## 1. 목적

이 문서는 `ai-agent-ops` vNext에서 Team을 어떻게 구성할 수 있는지 정의한다.

`team_model.md`는 실제 프로젝트의 Team 구성을 확정하지 않는다. 이 문서는 선택 가능한 Team 구성 패턴과 최소 계약을 제공한다. 실제 프로젝트에서 어떤 Team을 활성화할지는 `.ai_project/operating_model.md`에 기록한다.

## 2. Team의 의미

Team은 실행과 ownership의 기본 단위다.

Team은 아래 질문에 답해야 한다.

- 이 Team은 어떤 범위를 책임지는가?
- 이 Team의 Lead Role은 누구인가?
- 이 Team의 Execution Role은 누구인가?
- 이 Team의 Verification Role은 누구인가?
- 이 Team이 수정할 수 있는 기본 path는 어디인가?
- 이 Team이 기준으로 삼는 source of truth는 무엇인가?
- 다른 Team과 충돌할 때 누가 조율하는가?

Team 이름은 자유롭게 정할 수 있다. 단, Team이 유효하려면 Role, ownership, workflow 연결이 명확해야 한다.

## 3. Team 최소 계약

모든 활성 Team은 아래 항목을 가져야 한다.

| 항목 | 의미 |
|---|---|
| Team Name | 프로젝트 안에서 식별 가능한 Team 이름 |
| Parent Division | 상위 책임 Division |
| Team Lead | scope, ownership, dependency 조율 책임 |
| Active Roles | Team 안에서 활성화된 Role |
| Allowed Paths | 기본 수정 가능 경로 |
| Source of Truth | Team이 기준으로 삼는 문서 |
| Board Strategy | project board만 쓸지, team board를 둘지 |
| Branch Strategy | 프로젝트 공통 전략을 따를지, Team별 예외가 있는지 |
| Escalation Path | blocked, ownership conflict, cross-team 변경 시 조율 경로 |

최소 활성 Role:

```text
Lead Role
Execution Role
Verification Role
```

Completion Role은 작은 Team에서는 Lead Role이 겸할 수 있다. Release Role은 실제 배포/운영 인계가 반복적으로 필요할 때 활성화한다.

## 4. Team 구성 패턴

프로젝트 bootstrap 시 AI Ops Agent는 아래 후보를 제시할 수 있다.

| 패턴 | 설명 | 권장 상황 |
|---|---|---|
| `single_team` | 하나의 Team이 대부분의 실행을 담당 | 작은 프로젝트, 초기 운영 |
| `platform_team` | iOS, Android, Web, Backend처럼 플랫폼별 분리 | 플랫폼별 코드/빌드/검증이 다름 |
| `feature_team` | Auth, Payment처럼 기능 도메인별 분리 | 도메인 ownership이 중요함 |
| `module_team` | Design System, Networking처럼 모듈별 분리 | 공통 모듈 영향이 큼 |
| `qa_team` | 검증 책임을 별도 Team으로 분리 | 여러 Team의 QA 기준을 통합 |
| `release_ops_team` | 배포와 운영 인계를 별도 Team으로 분리 | 실제 release gate가 있음 |
| `custom_team` | 사용자가 직접 Team을 정의 | 프로젝트 특수 구조 |

## 5. Single Team

하나의 Team이 대부분의 실행을 담당한다.

```text
Development Division
  Product Team
    Lead Role
    Execution Role
    Verification Role
```

권장 상황:

- 작은 프로젝트
- 초기 실험
- 플랫폼이 하나이거나 변경 범위가 작음
- Team 간 ownership 충돌이 거의 없음

특징:

- project board 하나로 충분하다.
- branch/PR 전략도 프로젝트 공통 전략 하나를 따른다.
- Team별 board는 기본적으로 만들지 않는다.

## 6. Platform Team

플랫폼 또는 기술 영역별로 Team을 나눈다.

```text
Development Division
  iOS Team
  Android Team
  Web Team
  Backend Team
```

권장 상황:

- 플랫폼별 코드 경로가 분리되어 있음
- 플랫폼별 빌드/테스트/검증 방식이 다름
- 같은 기능도 플랫폼별 구현 책임이 다름

특징:

- path ownership이 명확하다.
- API contract, shared design system, release gate는 cross-team 조율이 필요하다.
- Team이 늘어나면 team board를 추가할 수 있다.

## 7. Feature Team

기능 도메인별로 Team을 나눈다.

```text
Development Division
  Auth Team
  Payment Team
  Search Team
```

권장 상황:

- 기능 도메인이 플랫폼보다 더 강한 ownership 기준임
- 한 기능이 여러 코드 경로를 함께 수정함
- domain ownership과 source of truth가 중요함

특징:

- domain ownership을 반드시 정의해야 한다.
- path ownership만으로 충돌을 판단하기 어렵다.
- 여러 플랫폼을 수정할 수 있으므로 Lead Role의 `scoped` 단계가 중요하다.

## 8. Module Team

모듈, 패키지, 라이브러리 단위로 Team을 나눈다.

```text
Development Division
  Design System Team
  Networking Team
  Persistence Team
  Analytics Team
```

권장 상황:

- 공통 모듈 변경이 여러 기능에 영향을 줌
- shared component나 internal library가 있음
- 코드 재사용 단위가 운영상 중요함

특징:

- downstream 영향을 Task에 기록해야 한다.
- Verification Role은 영향받는 Team의 검증 필요 여부를 확인한다.
- source of truth 문서 ownership이 중요하다.

## 9. QA Team

검증 책임을 별도 Team으로 분리한다.

```text
QA Division
  QA Team
    QA Lead
    Verification Role
```

권장 상황:

- 여러 Development Team의 검증 기준을 일관되게 관리해야 함
- 회귀 테스트, release risk, 품질 기준이 커짐
- Verification Role이 단일 Team 안에서 감당하기 어려움

초기에는 별도 QA Team을 만들지 않아도 된다. 작은 프로젝트에서는 각 Team의 Verification Role이 검증을 맡는다.

## 10. Release / Ops Team

배포와 운영 인계를 별도 Team으로 분리한다.

```text
Release / Operations Division
  Release Team
    Release Role
    Completion Role
```

권장 상황:

- 실제 배포가 반복적으로 있음
- release checklist, rollback, 운영 인계가 필요함
- 여러 Team의 완료 결과를 하나의 release gate로 묶어야 함

현재 배포할 대상이 없으면 활성화하지 않는다. Release Role은 필요해질 때 켠다.

## 11. Custom Team

사용자가 프로젝트 상황에 맞게 Team을 직접 정의한다.

예:

```text
Mobile Core Team
Growth Experiment Team
Internal Tools Team
AI Ops Team
```

Custom Team도 아래 계약을 지켜야 한다.

- Parent Division이 있어야 한다.
- Lead / Execution / Verification 책임이 있어야 한다.
- allowed paths와 source of truth가 있어야 한다.
- ownership 충돌 시 조율 경로가 있어야 한다.
- Task metadata에서 `team`, `team_lead`, `target_role`로 라우팅 가능해야 한다.

## 12. Role 구성 옵션

Team 안의 Role은 프로젝트 규모에 따라 합치거나 분리할 수 있다.

### 12.1 Minimal 3 Role

```text
Team
  Lead Role
  Execution Role
  Verification Role
```

초기 기본값이다.

역할:

- Lead Role: 요구사항 정리, Task 등록, 우선순위, ownership, dependency, merge 판단
- Execution Role: 실제 작업, 개발자 검증, task branch commit, PR 생성
- Verification Role: 검증, PR review, CI/test 확인, merge 준비 상태 판단

Completion Role은 Lead Role이 겸할 수 있다.

### 12.2 Expanded Team

```text
Team
  Team Lead
  Development Agent
  Test Agent
  QA Agent
  Release Agent
```

권장 상황:

- 테스트 작성과 QA 판단을 분리해야 함
- release gate가 있음
- 작업량이 많아 Role을 분리해야 함

주의:

- Test Agent와 QA Agent를 반드시 분리할 필요는 없다.
- Release Agent는 실제 release workflow가 없으면 만들지 않는다.
- Role 분리는 복잡도를 늘리므로 반복 병목이 생겼을 때 확장한다.

### 12.3 Custom Agent Names

Agent 이름은 사용자가 자유롭게 정할 수 있다.

예:

```text
iOS Captain      -> Lead Role
iOS Builder      -> Execution Role
iOS Inspector    -> Verification Role
Ops Curator      -> Ops Governance Role
```

이름보다 중요한 것은 Role 계약이다. Agent가 어떤 이름을 쓰더라도 `target_role`, capability, 상태 전이 책임을 따라야 한다.

## 13. Team Board 기준

Team board는 선택 사항이다.

기본 선택지:

| 옵션 | 설명 | 권장 상황 |
|---|---|---|
| `project_board_only` | `.ai_project/task_board.md`만 사용 | single team, 초기 운영 |
| `project_plus_team_board` | project board + Team별 board 사용 | 여러 Team이 병렬 작업 |
| `custom_views` | Team, Role, ownership view를 필요에 따라 구성 | 대형 프로젝트 |

Team board를 만들면 위치는 아래를 권장한다.

```text
.ai_project/teams/{team_id}/task_board.md
```

Board는 view다. 실행 지시와 상태의 source of truth는 Task 파일이다.

## 14. Team Branch / PR 기준

Team은 기본적으로 프로젝트 공통 branch/PR 전략을 따른다.

기본 전략:

```text
.ai_project/branch_pr_strategy.md
```

Team별 예외가 필요하면 아래에 기록할 수 있다.

```text
.ai_project/teams/{team_id}/branch_pr_strategy.md
```

Team별 예외가 필요한 경우:

- 특정 Team만 별도 CI가 있음
- 특정 Team만 release branch를 사용함
- 특정 Team만 외부 repo 또는 submodule을 다룸
- ownership review 기준이 다른 Team보다 엄격함

예외가 없으면 Team별 branch 전략 문서를 만들지 않는다.

## 15. Team Metadata

Task는 Team 라우팅을 위해 아래 필드를 사용한다.

```yaml
org_unit: Development Division
team: iOS Team
team_lead: iOS Team Lead
target_agent: iOS Development Agent
target_role: Execution Role
required_capabilities:
  - implementation
allowed_paths:
  - ios/App/
source_of_truth:
  - docs/ios/current_status.md
```

Team scoped 단계에서 확인할 항목:

- `team`이 활성 Team인가?
- `team_lead`가 지정되어 있는가?
- `target_role`이 Team 안에서 활성화되어 있는가?
- `allowed_paths`가 ownership과 충돌하지 않는가?
- `source_of_truth`가 지정되어 있는가?
- cross-team 검토가 필요한가?

## 16. Team 활성화 절차

새 Team은 아래 순서로 활성화한다.

```text
1. Team 필요성 확인
2. Team pattern 선택
3. Parent Division 지정
4. Role / Agent 매핑
5. allowed_paths 지정
6. source_of_truth 지정
7. ownership 영역 지정
8. board strategy 선택
9. branch/PR strategy 확인
10. .ai_project/operating_model.md 반영
```

AI Ops Agent는 활성화 전에 선택지를 제시하고 사용자 승인을 받아야 한다.

## 17. iOS Team 예시

초기 iOS 프로젝트는 아래처럼 단순하게 시작할 수 있다.

```text
Development Division
  iOS Team
    iOS Team Lead       -> Lead Role
    iOS Dev Agent       -> Execution Role
    iOS QA Agent        -> Verification Role
```

별도 Test Agent는 당장 필요하지 않다. Execution Role이 개발자 검증과 기본 테스트를 수행하고, Verification Role이 독립 검증과 PR review를 담당한다.

별도 Release Agent도 당장 필요하지 않다. 실제 release workflow가 생기기 전까지 Release Role은 비활성 상태로 둔다.

PR 기반 운영을 선택한 경우 기본 흐름:

```text
Lead Role
  요구사항 정리
  Task 등록
  scope / priority / owner 지정

Execution Role
  task branch 생성
  구현
  개발자 검증
  commit
  PR 생성
  verification_ready 인계

Verification Role
  PR review
  테스트 / 빌드 / 문서 정합성 검증
  verification_passed 또는 rework_requested 기록

Lead Role
  merge 준비 상태 확인
  merge
  completion_review / done 처리
```

## 18. 프로젝트 적용 위치

`.ai/models/team_model.md`는 일반 모델이다.

실제 프로젝트 선택 결과는 아래 문서에 기록한다.

```text
.ai_project/operating_model.md
```

Team별 세부 문서가 필요하면 아래 구조를 사용한다.

```text
.ai_project/teams/
  ios/
    team_context.md
    task_board.md
    branch_pr_strategy.md
```

## 19. 변경 이력

| 날짜 | 변경 내용 |
|---|---|
| 2026-07-09 | Team 구성 패턴과 프로젝트 적용 기준 초안 작성 |

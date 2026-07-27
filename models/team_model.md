# Team Model

작성일: 2026-07-10
상태: Draft vNext Slim Reference
범위: AI Ops의 Team 구성 기준

## 1. 목적

Team은 같은 운영 목표와 ownership 아래에서 Task를 수행하는 실행 단위다.

이 문서는 Team을 어떻게 나눌지, Team별 최소 계약에 무엇을 기록할지, 언제 Team을 확장할지를 정의한다. 실제 프로젝트별 선택값은 `.ai_project/operating_model.md`와 `.ai_project/teams/`에 기록한다.

## 2. 핵심 원칙

- Team은 사람 수가 아니라 책임 경계로 나눈다.
- Role은 Team 안에서 수행되는 책임이고, Agent는 그 Role을 맡는 실행 주체다.
- Team 이름은 자유롭게 정할 수 있지만 Role, ownership, workflow 계약은 유지해야 한다.
- 초기 프로젝트는 `single_team`으로 시작해도 된다.
- iOS, Android, Web, Backend처럼 코드와 검증 기준이 분리되면 Team 분리를 검토한다.
- QA Team이나 Release Team은 실제 검증 병목이나 릴리즈 게이트가 있을 때만 분리한다.

## 3. Team 최소 계약

Team을 만들 때 아래 항목을 기록한다.

```yaml
team_id:
team_name:
team_pattern:
purpose:
owned_paths:
owned_domains:
source_of_truth:
active_roles:
default_lead:
board_path:
branch_pr_override:
coordination_notes:
```

필수값은 `team_id`, `purpose`, `owned_paths` 또는 `owned_domains`, `active_roles`다.

## 4. Team Pattern

운영모델의 canonical 값은 `schemas/operating_model.schema.json`과 `runtime/bootstrap_options.json`을 따른다.

| Pattern | 의미 | 권장 상황 |
|---|---|---|
| `single_team` | 하나의 Team이 대부분의 작업을 처리 | 초기 프로젝트, 작은 앱, 개인 프로젝트 |
| `functional_teams` | Product, Development, QA처럼 기능별 분리 | 역할 전문성이 중요할 때 |
| `platform_teams` | iOS, Android, Web, Backend처럼 플랫폼별 분리 | 코드 경로와 빌드/검증 기준이 다를 때 |
| `cross_functional` | 기능 단위로 여러 역할이 함께 소유 | 제품 도메인 중심 개발 |
| `custom` | 프로젝트 특수 구조 | 기존 조직 구조를 유지해야 할 때 |

기존 문서나 대화에서 `platform_team`, `feature_team`, `module_team`, `custom_team` 같은 표현이 나오면 bootstrap 단계에서 canonical 값으로 매핑한다.

## 5. Role 구성

Team은 Role을 직접 대체하지 않는다. Team 안에 필요한 Role을 활성화한다.

기본 조합:

| 구성 | 활성 Role | 권장 상황 |
|---|---|---|
| Minimal | Lead / Execution / Verification | 대부분의 개발 Team |
| Planning | Direction / Lead / Ops Governance | 아이디어, 기획, discovery |
| Recovery | Lead / Verification / Ops Governance | 복구, 점검, 안정화 |
| Release Ready | Lead / Verification / Release / Ops Governance | 실제 배포 책임이 있을 때 |

작은 Team에서는 한 Agent가 여러 Role을 맡을 수 있지만, Task 상태 전이와 보고서에서는 Role 책임을 구분한다.

## 6. Team Board

Board는 현황판이고 Task 파일이 source of truth다.

| Board 방식 | 사용 기준 |
|---|---|
| `project_board_only` | single team 또는 초기 운영 |
| `project_plus_team_board` | Team이 둘 이상이고 병렬 작업이 있을 때 |
| `custom_views` | Role, domain, release별 view가 필요할 때 |

Team Board가 생기면 `.ai_project/task_board.md`는 전체 우선순위와 cross-team dependency를 보여야 한다.

## 7. Branch / PR

Team별 branch 전략은 프로젝트 기본 정책을 우선 따른다.

Team별 override는 아래 경우에만 둔다.

- 플랫폼별 저장소나 기본 branch가 다르다.
- CI, build, test 명령이 Team별로 다르다.
- 특정 Team에 더 엄격한 review 또는 release gate가 있다.

기록 위치:

```text
.ai_project/branch_pr_strategy.md
.ai_project/teams/<team_id>/branch_pr_strategy.md
```

## 8. 활성화 절차

Team 추가는 Lead Role 또는 Ops Governance Role이 제안하고 사용자가 승인한다.

절차:

1. Team을 나누는 이유를 확인한다.
2. owned path/domain/source of truth를 정한다.
3. active Role과 default Lead를 정한다.
4. board와 branch override 필요 여부를 정한다.
5. `.ai_project/operating_model.md` 또는 `.ai_project/teams/<team_id>/team_context.md`에 기록한다.

## 9. 충돌 처리

Team 간 충돌은 `policies/ownership_model.md`와 `policies/coordination_policy.md`를 따른다.

원칙:

- 같은 path를 여러 Team이 동시에 수정하면 Lead Role이 coordination을 확정한다.
- 같은 domain을 여러 Team이 건드리면 source of truth와 owner를 먼저 확인한다.
- 충돌이 해소되지 않으면 Task는 `blocked` 또는 `rework_requested`로 돌린다.

## 10. 금지사항

- Team 이름만 만들고 ownership을 비워두지 않는다.
- QA 또는 Release Team을 실제 필요 없이 기본 생성하지 않는다.
- Team Board를 만들었는데 Project Board와 연결하지 않는 구조를 피한다.
- Team 구성을 바꿨는데 `.ai_project/agent_registry.md`와 Task owner를 갱신하지 않는 것을 금지한다.

## 11. 변경 이력

| 날짜 | 변경 내용 |
|---|---|
| 2026-07-10 | Team 구성 패턴과 최소 계약 추가 |
| 2026-07-27 | schema/runtime 중복 내용을 줄이고 slim reference로 압축 |

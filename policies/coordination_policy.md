# Coordination Policy

작성일: 2026-07-09  
상태: Draft vNext  
범위: 조직형 AI Agent 운영체계의 병렬 작업, 의존성, 충돌 조율 정책

## 1. 목적

이 문서는 여러 Agent, Role, Team이 동시에 작업할 때 적용할 조율 정책을 정의한다.

Ownership model이 "누가 무엇을 책임지는가"를 정한다면, coordination policy는 "어떤 순서와 조건으로 같이 일할 것인가"를 정한다.

## 2. 기본 원칙

- 병렬성은 기본 권리가 아니라 조율된 실행 상태다.
- Task는 `scoped` 단계에서 실행 가능성, ownership, dependency, 병렬 가능 여부가 정리되어야 한다.
- 같은 Agent는 하나의 `in_progress` 또는 `verification_in_progress` Task만 가진다.
- `depends_on`이 완료되지 않은 Task는 실행하지 않는다.
- 같은 ownership 영역이나 source of truth 문서를 동시에 수정하지 않는다.
- 불확실하면 병렬 실행보다 순차 실행을 선택한다.

## 3. Coordination 책임

Coordination은 Lead Role의 책임이다.

Lead Role이 확인할 항목:

- `org_unit`
- `team`
- `team_lead`
- ownership
- `allowed_paths`
- `source_of_truth`
- `depends_on`
- `blocks`
- `parallel_group`
- cross-team 영향
- release / migration / security 영향

Lead Role은 이 항목이 충분히 정리된 경우에만 `proposed` Task를 `scoped`로 전환한다.

## 4. 병렬 작업 허용 조건

두 Task는 아래 조건을 모두 만족할 때 병렬 가능하다.

- 두 Task의 `depends_on`이 모두 완료되어 있다.
- 두 Task 사이에 직접적인 `depends_on` / `blocks` 관계가 없다.
- `allowed_paths`가 겹치지 않는다.
- ownership 영역이 겹치지 않는다.
- 같은 source of truth 문서를 동시에 수정하지 않는다.
- 같은 Agent가 두 Task를 동시에 맡지 않는다.
- release, migration, schema, API contract 같은 순차 gate가 아니다.
- Lead Role이 병렬 가능하다고 기록했다.

병렬 가능 기록 예시:

```text
Parallel Review:
- Compared Task:
- allowed_paths overlap: no
- ownership overlap: no
- source_of_truth overlap: no
- dependency: none
- decision: parallel allowed
- reviewer: {{TEAM_LEAD}}
```

## 5. 병렬 작업 금지 조건

아래 조건 중 하나라도 해당하면 병렬 작업은 기본 금지다.

- 같은 파일 또는 같은 좁은 디렉토리를 수정한다.
- 같은 ownership 영역을 수정한다.
- 같은 domain ownership을 수정하고 결과가 서로 영향을 줄 수 있다.
- 같은 source of truth 문서를 수정한다.
- 한 Task가 다른 Task의 선행 조건이다.
- 한 Task의 결과가 다른 Task의 검증 기준을 바꾼다.
- release, migration, schema, API contract 변경이다.
- 같은 Agent가 두 Task를 맡아야 한다.
- Lead Role이 충돌 가능성을 기록했다.

병렬 금지 시 처리:

- 순서를 정하고 `depends_on`을 추가한다.
- 후속 차단 관계가 명확하면 `blocks`를 추가한다.
- 같은 충돌 묶음이면 `parallel_group`을 같게 둔다.
- 범위를 나눌 수 있으면 Task를 분리한다.
- 불확실하면 `blocked`로 전환한다.

## 6. Dependency 정책

`depends_on`은 이 Task가 실행되기 전에 완료되어야 하는 선행 Task를 기록한다.

```yaml
depends_on:
  - T-YYYYMMDD-001
```

규칙:

- `depends_on`에 있는 Task가 모두 `done`이 아니면 실행하지 않는다.
- 선행 Task가 `verification_passed`여도 `done`이 아니면 기본적으로 실행하지 않는다.
- workflow가 명시적으로 허용하면 `verification_passed` 이후 후속 검증 Task를 준비할 수 있지만, 실제 변경 실행은 Lead Role 판단을 따른다.
- `depends_on` 변경은 Queue 영향이 있으므로 Direction Role 또는 Lead Role이 기록한다.

## 7. Blocks 정책

`blocks`는 이 Task가 완료되기 전 막는 후속 Task를 기록한다.

```yaml
blocks:
  - T-YYYYMMDD-003
```

규칙:

- `blocks`는 후속 영향 추적용이다.
- 실제 실행 차단 판단은 후속 Task의 `depends_on`을 우선한다.
- 중요한 차단 관계는 양쪽 Task에 함께 기록하는 것을 권장한다.
- `blocks`가 있는 Task의 priority 변경은 후속 Task 영향을 함께 설명한다.

## 8. Parallel Group 정책

`parallel_group`은 충돌 가능성이 있는 작업 묶음을 표현한다.

```yaml
parallel_group: ios-auth
```

기본 규칙:

- 같은 `parallel_group`의 Task는 기본적으로 병렬 금지다.
- Lead Role이 병렬 가능 사유를 명시하면 예외적으로 허용할 수 있다.
- 서로 다른 `parallel_group`이어도 ownership 또는 source of truth가 겹치면 병렬 금지다.
- `parallel_group`이 비어 있어도 병렬 가능을 뜻하지 않는다.

권장 group 이름:

```text
ios-auth
ios-release
backend-api-contract
docs-source-of-truth
ops-workflow
```

## 9. Scoped 기준

`scoped`는 실행 전 조율이 끝났다는 뜻이다.

`scoped`로 전환하기 전 Lead Role은 아래를 확인한다.

- Task 목적과 제외 범위가 충분히 명확하다.
- `org_unit`과 `team`이 명시되어 있다.
- `team_lead`가 명시되어 있다.
- `allowed_paths`가 실제 작업 범위를 표현한다.
- `source_of_truth`가 판단 기준을 표현한다.
- ownership 충돌이 없거나 검토 결과가 기록되어 있다.
- `depends_on`, `blocks`, `parallel_group`이 필요한 만큼 기록되어 있다.
- 병렬 가능 여부가 판단되어 있다.
- cross-team review 필요 여부가 기록되어 있다.

하나라도 불명확하면 `scoped`로 넘기지 않고 `proposed`에 남기거나 `blocked`로 전환한다.

## 10. Rework 조율

`rework_requested`는 재작업 필요 상태다.

재작업은 두 경로 중 하나로 돌아간다.

```text
rework_requested -> scoped -> approved -> in_progress
```

또는 범위가 이미 명확하면:

```text
rework_requested -> approved -> in_progress
```

`scoped`로 돌아가야 하는 경우:

- 수정 범위가 바뀐다.
- ownership이 바뀐다.
- `allowed_paths`가 추가된다.
- source of truth가 바뀐다.
- 다른 Task와 dependency가 생긴다.
- 병렬 작업 충돌 가능성이 생긴다.

바로 `approved`로 갈 수 있는 경우:

- 재작업 범위가 기존 승인 범위 안에 있다.
- `allowed_paths`가 그대로다.
- ownership 충돌이 없다.
- 추가 dependency가 없다.
- Direction Role 또는 Product Owner가 승인했다.

## 11. Blocked 조율

`blocked`는 현재 상태에서 진행할 수 없다는 뜻이다.

Blocked 사유 예시:

- 외부 결정 필요
- credential, 계정, 장비, 서버 접근 필요
- source of truth 부재
- ownership 충돌
- dependency 미완료
- release gate 미확정
- workflow 또는 Role 라우팅 불명확

차단 해소 후 경로:

```text
blocked -> scoped
```

또는 범위가 그대로이고 승인만 다시 필요하면:

```text
blocked -> approved
```

Blocked 해제는 현재 담당 Agent가 임의로 하지 않는다. Lead Role 또는 Direction Role이 해소 근거를 기록한다.

## 12. Cross-Team 조율

Cross-team Task는 기본적으로 `scoped` 단계가 필수다.

Cross-team 조율 항목:

- 관련 Team 목록
- primary Team
- supporting Team
- Owner 또는 reviewer
- dependency
- source of truth
- release 영향
- 검증 책임

예시:

```yaml
org_unit: Development Division
team: {{TEAM_NAME}}
team_lead: {{TEAM_LEAD}}
cross_team:
  required: true
  teams:
    - {{PRIMARY_TEAM}}
    - {{DEPENDENT_TEAM}}
  primary_team: {{PRIMARY_TEAM}}
  reviewers:
    - {{REVIEWER}}
```

초기 Task 템플릿에 `cross_team` 필드가 없어도 된다. 필요 시 Task 본문에 기록한다.

## 13. Source of Truth 조율

같은 source of truth 문서를 수정하거나 기준으로 삼는 Task는 충돌 가능성이 있다.

규칙:

- 같은 source of truth 문서를 동시에 수정하지 않는다.
- 같은 source of truth를 읽기만 하는 것은 병렬 가능할 수 있다.
- 한 Task가 source of truth를 수정하고 다른 Task가 그 문서를 기준으로 실행하면 순서를 정한다.
- source of truth가 불명확하면 `scoped`로 전환하지 않는다.

## 14. Release / Migration 조율

Release와 migration은 기본적으로 순차 gate로 본다.

아래 Task는 병렬 허용에 보수적으로 접근한다.

- release preparation
- deployment
- rollback
- schema migration
- API contract 변경
- `.ai/` 운영체계 문서 변경
- `.ai_project/` 구조 migration

Release 또는 migration Task가 활성 상태이면 같은 ownership 영역의 feature/bugfix Task는 Lead Role 판단 전까지 병렬 금지다.

## 15. Coordination 기록 형식

Task 본문에 아래 형식으로 조율 결과를 기록할 수 있다.

```text
Coordination Review:
- Lead Role:
- Ownership:
- allowed_paths:
- source_of_truth:
- depends_on:
- blocks:
- parallel_group:
- parallel decision:
- cross-team review:
- release/migration impact:
```

## 16. 금지사항

- `depends_on`이 완료되지 않은 Task를 실행하지 않는다.
- 같은 ownership 영역을 Lead Role 판단 없이 병렬 실행하지 않는다.
- 같은 source of truth 문서를 동시에 수정하지 않는다.
- `parallel_group`이 비어 있다는 이유만으로 병렬 가능하다고 판단하지 않는다.
- blocked Task를 근거 없이 approved로 되돌리지 않는다.
- rework 범위가 바뀌었는데 `scoped` 단계를 건너뛰지 않는다.
- 한 Agent가 여러 active Task를 동시에 진행하지 않는다.

## 17. 변경 이력

| 날짜 | 변경 내용 |
|---|---|
| 2026-07-09 | 조직형 AI Agent 운영체계의 coordination policy 초안 작성 |

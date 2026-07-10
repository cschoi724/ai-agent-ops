# AI Agent Workflow

작성일: 2026-06-29  
상태: Draft vNext  
범위: 조직형 AI Agent 운영체계의 중심 실행 흐름

## 1. 목적

이 문서는 조직형 AI Agent 운영체계의 기본 실행 흐름을 정의한다.

vNext workflow는 PM -> Development -> QA 순서가 아니라 책임 단계의 순서로 Task를 처리한다.

```text
Need
  -> Direction
  -> Coordination
  -> Execution
  -> Verification
  -> Completion
  -> Learning / Ops Improvement
```

기존 PM Agent, Development Agent, QA Agent, AI Ops Agent는 이 흐름 위에 매핑되는 bootstrap Role이다. 새 Division, Team, Role, Capability가 추가되어도 중심 흐름은 유지한다.

최상위 원칙은 `.ai/core/constitution.md`를 따른다.

## 2. 기본 원칙

- 모든 Agent는 한국어로 보고한다.
- 한 번에 하나의 Task 단위로 진행한다.
- 프로젝트별 실행 지시는 `.ai_project/tasks/`에 기록한다.
- Task 파일은 실행 지시의 source of truth다.
- `task_board.md`는 현황 요약판이며 Task 파일을 대체하지 않는다.
- Task 실행은 Agent 이름보다 세션 Role과 Task의 `workflow`, `status`, `target_agent` 또는 `target_role` 조합을 우선한다.
- `target_agent`는 현재 `status`에서 Task를 처리할 기존 호환 Role 또는 Agent 이름을 뜻한다.
- `target_role`은 vNext에서 도입할 명시적 Role 라우팅 필드다.
- `target_agent`가 존재하면 기존 호환성을 위해 `target_role`보다 우선한다.
- Capability가 맞더라도 `target_agent` 또는 `target_role`이 현재 Role과 맞지 않으면 실행하지 않는다.
- report/QA 문서는 Task 진행 과정의 보조 기록이다.
- 커밋, push, 배포, 외부 설정 변경은 사용자 승인 후 진행한다.
- 민감정보를 로그, 문서, 보고서에 남기지 않는다.

## 3. 중심 흐름

vNext 기본 흐름은 아래 상태 전이를 따른다.

```text
Need
  -> proposed
  -> scoped
  -> approved
  -> in_progress
  -> verification_ready
  -> verification_in_progress
  -> verification_passed
  -> completion_review
  -> done
```

예외 흐름:

```text
any executable state
  -> blocked

verification_in_progress
  -> rework_requested
  -> scoped or approved

proposed or scoped or approved
  -> cancelled
```

이 흐름은 모든 workflow의 기본 뼈대다. 특정 workflow가 더 짧거나 긴 흐름을 가져야 하면 `.ai/workflows/`의 개별 workflow 문서가 명시한다.

## 4. 책임 단계

| 단계 | 상태 | 담당 Role 범주 | 핵심 책임 |
|---|---|---|---|
| Need | 없음 | 누구나 | 요구, 문제, 아이디어, 리스크 발견 |
| Direction | `proposed` | Direction Role | 목적, 우선순위, 승인 필요 여부, 성공 기준, 상위 책임 조직 정리 |
| Coordination | `scoped` | Lead Role | Team, ownership, dependency, allowed paths, source of truth, 병렬 가능 여부 정리 |
| Approval | `approved` | Direction Role 또는 Product Owner | 진행 승인, 첫 실행 Role 지정 |
| Execution | `in_progress` | Execution Role | lock 획득, 허용 범위 내 작업, 작업 보고 작성 |
| Verification Ready | `verification_ready` | Execution Role | 검증 가능한 산출물과 보고 경로 인계 |
| Verification | `verification_in_progress` | Verification Role | 테스트, 검증, 리스크, rework 여부 판단 |
| Verification Passed | `verification_passed` | Verification Role | PASS 또는 PASS_WITH_RISK 결과 기록 |
| Completion Review | `completion_review` | Completion Role | 완료 확정, 잔여 리스크 수용, 후속 Task 판단 |
| Done | `done` | Completion Role | Task 완료 확정, board 갱신 |
| Learning / Ops Improvement | 별도 기록 | Ops Governance Role | 운영 충돌, workflow 개선, Role/Capability 개선점 기록 |

## 5. 단계별 기준

### 5.1 Need

Need는 아직 실행 가능한 Task가 아니다.

아래 항목은 Need가 될 수 있다.

- 기능 요청
- 버그
- 리팩터링 필요성
- 문서 정리
- 릴리즈 준비
- 운영 규칙 충돌
- 팀 간 의존성
- ownership 충돌

Need는 Direction Role이 Task 후보로 정리한 뒤에만 Task Queue에 들어간다.

### 5.2 Direction

Direction Role은 Need를 `proposed` Task로 정리한다.

정리 기준:

- 무엇을 하려는가
- 왜 필요한가
- 우선순위는 무엇인가
- 승인자가 필요한가
- 성공 기준은 무엇인가
- 어느 Division 책임인가
- 어떤 workflow가 적절한가

`proposed` Task는 아직 실행 대상이 아니다.

### 5.3 Coordination

Lead Role은 `proposed` Task를 실행 가능한 형태로 조율하고 `scoped`로 전환한다.

`scoped` 상태가 되려면 아래 항목이 정리되어야 한다.

- `org_unit`
- `team`
- `team_lead`
- `target_agent` 또는 `target_role`
- `required_capabilities`
- `allowed_paths`
- `source_of_truth`
- `depends_on`
- ownership 충돌 여부
- 병렬 실행 가능 여부

Ownership 판단은 `.ai/policies/ownership_model.md`, 병렬과 dependency 조율은 `.ai/policies/coordination_policy.md`를 따른다.

기존 단순 운영에서 `scoped` 단계가 필요 없으면 개별 workflow가 `proposed -> approved` 직접 전이를 허용할 수 있다.

### 5.4 Approval

Approval 단계는 Task 실행을 허가한다.

승인 기준:

- `scoped` 정보가 충분하다.
- 작업 범위와 제외 범위가 명확하다.
- 승인자가 `approved_by`에 기록되어 있다.
- 첫 실행 Role이 `target_agent` 또는 `target_role`에 지정되어 있다.

승인 후 Task는 `approved` 상태가 된다.

### 5.5 Execution

Execution Role은 `approved` Task를 처리한다.

실행 전 확인:

- 현재 세션 Role이 사용자에게 부여되었다.
- `workflow`와 `status`가 현재 Role의 실행을 허용한다.
- `target_agent` 또는 `target_role`이 현재 Role과 맞다.
- `required_capabilities`가 현재 Role과 맞다.
- `depends_on`이 모두 완료되었다.
- `locked_by`가 비어 있다.
- 작업 범위가 `allowed_paths` 안에 있다.
- 기준 문서가 `source_of_truth`에 있다.

작업을 시작하면 lock을 획득하고 `in_progress`로 전환한다.

작업 완료 후에는 작업 보고를 작성하고 `verification_ready`로 넘긴다.

### 5.6 Verification

Verification Role은 `verification_ready` Task를 검증한다.

검증 기준:

- 작업 보고가 존재한다.
- Task의 검증 기준이 확인 가능하다.
- 변경이 `allowed_paths` 안에 있다.
- source of truth와 결과가 충돌하지 않는다.
- 회귀 위험, 보안/개인정보, 릴리즈 영향이 필요한 만큼 확인되었다.

검증 중에는 `verification_in_progress` 상태를 사용한다.

검증 결과:

- 통과: `verification_passed`
- 리스크 수용 가능: `verification_passed` with risk note
- 수정 필요: `rework_requested`
- 외부 차단: `blocked`

### 5.7 Completion

Completion Role은 `verification_passed` Task를 최종 검토한다.

`completion_review`에서 확인할 항목:

- 검증 결과를 수용할 수 있는가
- 잔여 리스크가 기록되어 있는가
- 후속 Task가 필요한가
- release 영향이 있는가
- board 갱신이 필요한가
- 운영 이슈 기록이 필요한가

완료 확정 후 `done`으로 전환한다.

Workflow에 따라 Completion Role은 Direction Role, Team Lead, Release Role, AI Ops Division 등으로 달라질 수 있다.

### 5.8 Learning / Ops Improvement

Ops Governance Role은 모든 Task에 개입하지 않는다.

아래 문제가 발견될 때만 운영 이슈로 기록한다.

- Role 경계가 애매하다.
- Task metadata가 부족하다.
- `allowed_paths`가 부정확하다.
- `source_of_truth`가 없다.
- workflow 상태가 부족하다.
- 병렬 작업 충돌 위험이 있다.
- 새 Role 또는 Capability가 반복적으로 필요하다.

운영 이슈는 `.ai_project/ops_issues.md`에 기록하고, 확정된 운영 결정은 `.ai_project/ops_decisions.md`에 기록한다.

## 6. Bootstrap Role 매핑

기존 v1 Agent는 vNext 책임 단계에 아래처럼 매핑한다.

| vNext Role 범주 | Bootstrap Agent | 비고 |
|---|---|---|
| Direction Role | PM Agent | 작업 정의, 우선순위, 승인 게이트 |
| Lead Role | PM Agent 또는 Development Lead | 초기에는 PM Agent가 임시 수행 가능, 조직형 모델에서는 Team Lead로 분리 |
| Execution Role | Development Agent | 구현, 문서, 리팩터링 등 실행 |
| Verification Role | QA Agent | 검증, 리스크, rework 판단 |
| Completion Role | PM Agent 또는 Team Lead | workflow별 완료 주체가 다를 수 있음 |
| Ops Governance Role | AI Ops Agent / AI Ops Division | 제품 Task 실행 라인 밖에서 운영체계 점검 |

AI Ops Agent는 기본적으로 제품 Task의 실행 Role이 아니다. 운영체계 개선 Task는 AI Ops Division의 별도 Task로 다룰 수 있다.

## 7. Workflow 선택

Task 유형별 세부 흐름은 `.ai/workflows/`를 따른다.

| Task 유형 | Workflow |
|---|---|
| 신규 기능 또는 기능 확장 | `.ai/workflows/feature.md` |
| 버그 수정 | `.ai/workflows/bugfix.md` |
| 문서 작업 | `.ai/workflows/docs.md` |
| 운영체계 개선 또는 마이그레이션 | `.ai/workflows/ops_migration.md` |

새 Role이나 Agent가 추가되면 Agent별 권한표를 크게 늘리기보다 필요한 workflow에 상태 전이와 전이 후 `target_agent` 또는 `target_role`을 추가한다.

## 8. Capability Hook

Workflow는 `.ai/models/capabilities.md`의 capability를 기준으로 확장한다.

예:

```text
Task가 인증/권한/개인정보/로그를 건드리면 security_check capability를 가진 Verification Role의 검증을 필수 항목에 추가한다.
```

새 실행 Role은 실제 운영 중 반복 부담이나 독립 검토 필요성이 명확해진 뒤 사용자 승인으로 추가한다. 추가된 Role은 `.ai/models/agent_registry.md`, `.ai/models/capabilities.md`, 관련 workflow에 연결한다.

## 9. 변경 이력

| 날짜 | 변경 내용 |
|---|---|
| 2026-06-29 | Codex 기준 기본 workflow v1 작성 |
| 2026-06-29 | Task Queue 기반 실행 흐름 추가 |
| 2026-06-29 | QA 통과 후 PM 완료 확정 단계를 명확화 |
| 2026-06-30 | AI Ops Agent를 실행 흐름 밖의 독립 운영 Agent로 추가 |
| 2026-07-01 | 프로젝트 초기화와 운영 마이그레이션 주체를 AI Ops Agent로 정리 |
| 2026-07-02 | `workflow`, `status`, `target_agent` 기반 실행 흐름으로 개정 |
| 2026-07-09 | vNext 책임 단계 기반 중심 흐름으로 개정 |

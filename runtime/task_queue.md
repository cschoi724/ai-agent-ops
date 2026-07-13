# Task Queue Policy

작성일: 2026-06-29  
상태: Draft vNext  
범위: `.ai_project/tasks/` 기반 조직형 Task Queue 운영 기준

## 1. 목적

이 문서는 Agent들이 복사/붙여넣기 지시에 의존하지 않고, 공유 Task Queue를 통해 자기 작업을 찾고 실행하는 기준을 정의한다.

`.ai_project/tasks/`의 Task 파일은 Agent 실행 지시의 source of truth다. `.ai_project/task_board.md`는 현황 요약판이며, `reports/`, `qa/`는 Task 진행 과정의 보조 기록이다.

Task 실행 흐름은 Agent별 고정 권한보다 세션 Role과 Task의 `workflow`, `status`, `target_agent` 또는 `target_role` 조합을 우선한다.

## 2. 기본 원칙

- Agent Role은 세션 시작 시 사용자가 부여한다.
- PM/Development/QA Agent는 vNext 책임 단계 위에 매핑되는 bootstrap Role이다.
- Agent는 세션 시작 또는 재개 시 `.ai_project/current_context.md`와 `.ai_project/tasks/`를 확인한다.
- `workflow`는 Task의 상태 전이 규칙을 정한다.
- 기존 Task에 `workflow`가 없으면 `type` 값을 같은 이름의 workflow로 해석한다.
- `target_agent`는 기존 호환 라우팅 필드이며, 현재 `status`에서 이 Task를 처리할 Role 또는 Agent 이름을 뜻한다.
- `target_role`은 vNext 명시적 Role 라우팅 필드다.
- `target_agent`가 존재하면 기존 호환성을 위해 `target_role`보다 우선한다.
- Agent는 Task의 `workflow`에 정의된 현재 `status`의 허용 전이만 수행한다.
- Agent는 작업 완료 시 `status`, `target_agent`, `target_role`을 workflow에 정의된 다음 처리 상태로 갱신한다.
- 기본 workflow에서는 Agent가 한 번의 완료 처리에서 한 단계의 상태 전이만 수행한다.
- 상태 전이 후 `target_agent` 또는 `target_role`이 자신이 아니면 다음 Role에게 인계한다.
- Role이 바뀌는 인계에는 `.ai/runtime/role_handoff.md`의 `다음 Agent에게 전달할 말` 블록을 Task 파일과 최종 응답에 남긴다. 실제 다음 Role은 현재 Task의 workflow와 프로젝트별 override가 우선한다.
- workflow가 명시적으로 연속 전이를 허용하지 않는 한 다음 Role 단계까지 이어서 처리하지 않는다.
- Agent는 다른 Agent 또는 Role 명의의 상태 전이 기록을 작성하지 않는다.
- Capability가 맞더라도 `target_agent` 또는 `target_role`이 현재 Role과 맞지 않으면 실행하지 않는다.
- `target_agent`와 `target_role`이 모두 비어 있거나 `any`인 경우에만 capability 기준으로 라우팅한다.
- 실행 가능한 Task는 `status: approved`, `status: verification_ready`, `status: completion_review`처럼 명확한 상태를 가져야 한다.
- 실행 가능한 Task는 필요한 경우 `approved_by`가 비어 있지 않아야 한다.
- Task는 `depends_on`이 모두 완료된 경우에만 실행한다.
- Agent는 잠금 필드가 비어 있는 Task만 시작할 수 있다.
- Agent는 Task를 시작하기 전 상태를 갱신하고, 완료 후 공통 작업 보고서 경로를 Task 파일에 기록한다.
- 동시에 여러 Task를 병렬 실행하지 않는다. 같은 Agent는 하나의 `in_progress` 또는 `verification_in_progress` Task만 가진다.

## 3. Task 상태값

| 상태 | 의미 | 기본 담당 Role 범주 |
|---|---|---|
| `proposed` | Need가 Task 후보로 정리됨 | Direction Role |
| `scoped` | 실행 가능한 형태로 범위, 팀, ownership, 경로, 기준 문서가 정리됨 | Lead Role |
| `approved` | 실행 승인 완료, 첫 실행 Role 지정됨 | Direction Role / Product Owner |
| `in_progress` | 실행 Role이 lock을 잡고 작업 중 | Execution Role |
| `verification_ready` | 실행 완료, 검증 가능한 산출물과 보고가 준비됨 | Execution Role |
| `verification_in_progress` | 검증 Role이 lock을 잡고 검증 중 | Verification Role |
| `verification_passed` | 검증 통과 또는 수용 가능한 리스크로 통과 | Verification Role |
| `completion_review` | 완료 확정 전 최종 검토 중 | Completion Role |
| `done` | 완료 확정 | Completion Role |
| `blocked` | 외부 요인이나 의존성 문제로 진행 불가 | 현재 담당 Role / Lead Role |
| `rework_requested` | 검증 또는 완료 검토 중 재작업 필요 | Verification Role / Completion Role |
| `cancelled` | Task 취소 | Direction Role / Product Owner |

## 4. 허용 상태 전이

Agent는 아래 상태 전이만 수행한다. 이 표에 없는 전이는 검토 Role이 사용자 확인 후 처리한다.

| 현재 상태 | 다음 상태 | 수행 주체 | 조건 |
|---|---|---|---|
| `proposed` | `scoped` | Lead Role | `org_unit`, `team`, ownership, `allowed_paths`, `source_of_truth`, dependency 정리 |
| `proposed` | `approved` | Direction Role | 단순 workflow에서 scope 단계 생략을 명시하고 사용자 승인 완료 |
| `scoped` | `approved` | Direction Role / Product Owner | 사용자 승인 완료, 첫 실행 `target_agent` 또는 `target_role` 지정 |
| `approved` | `in_progress` | Execution Role | 실행 가능 조건 충족, lock 획득 |
| `in_progress` | `verification_ready` | Execution Role | 작업 보고 작성 완료, 검증 Role로 인계 |
| `verification_ready` | `verification_in_progress` | Verification Role | 검증 가능 조건 충족, lock 획득 |
| `verification_in_progress` | `verification_passed` | Verification Role | `PASS` 또는 `PASS_WITH_RISK` 보고 작성 완료, lock 해제 |
| `verification_passed` | `completion_review` | Verification Role | 완료 확정 Role로 인계 |
| `completion_review` | `done` | Completion Role | 검증 결과와 잔여 리스크 수용, 완료 확정 |
| `verification_in_progress` | `rework_requested` | Verification Role | 수정 필요 |
| `completion_review` | `rework_requested` | Completion Role | 완료 검토 중 수정 필요 확인 |
| `rework_requested` | `scoped` | Lead Role | 재작업 범위, ownership, 경로 재조율 필요 |
| `rework_requested` | `approved` | Direction Role / Product Owner | 재작업 범위가 명확하고 승인 완료 |
| `blocked` | `scoped` | Lead Role | 차단 해소 후 범위, dependency, ownership 재확인 필요 |
| `blocked` | `approved` | Direction Role / Product Owner | 차단 해소 후 재승인 완료 |
| `approved` | `blocked` | 현재 담당 Role | 외부 차단 발견 |
| `in_progress` | `blocked` | Execution Role | 외부 차단 발견 |
| `verification_ready` | `blocked` | Verification Role | 검증 차단 발견 |
| `verification_in_progress` | `blocked` | Verification Role | 검증 중 차단 발견 |
| `completion_review` | `blocked` | Completion Role | 완료 확정 차단 발견 |
| `proposed` | `cancelled` | Direction Role / Product Owner | 취소 |
| `scoped` | `cancelled` | Direction Role / Product Owner | 취소 |
| `approved` | `cancelled` | Direction Role / Product Owner | 취소 |
| `blocked` | `cancelled` | Direction Role / Product Owner | 취소 |

## 5. 실행 가능 조건

Agent가 Task를 실행하려면 아래 공통 조건을 모두 만족해야 한다.

- 현재 세션 Role이 사용자에 의해 부여됨
- `workflow`가 현재 `status`에서 현재 Role의 전이를 허용함
- 필요한 상태에서 `approved_by`가 비어 있지 않음
- `target_agent` 또는 `target_role`이 현재 Role과 일치함
- `required_capabilities`가 현재 Role의 capability와 일치함
- `allowed_paths`가 명시됨
- `source_of_truth`가 명시됨
- `depends_on`에 있는 Task가 모두 `done`
- `locked_by`가 비어 있음

Lead Role이 `scoped`로 전환하려면 아래 조건을 확인한다.

- `org_unit`과 `team`이 명시됨
- `team_lead` 또는 동등한 Lead Role이 명시됨
- ownership 충돌이 없거나 검토 필요성이 기록됨
- 병렬 실행 가능 여부가 판단됨
- `allowed_paths`와 `source_of_truth`가 명시됨
- 필요한 경우 `depends_on`, `blocks`, `parallel_group`이 명시됨

Ownership 판단은 `.ai/policies/ownership_model.md`, 병렬과 dependency 조율은 `.ai/policies/coordination_policy.md`를 따른다.

Verification Role이 Task를 실행하려면 아래 조건을 추가로 확인한다.

- `workflow`가 현재 `status`에서 검증 전이를 허용함
- 작업 보고서가 `report_to` 경로에 존재함
- 검증 기준이 Task 파일 또는 source of truth에 명시됨

Completion Role이 `done`으로 전환하려면 아래 조건을 확인한다.

- 검증 결과가 `verification_passed`임
- 잔여 리스크가 수용 가능하거나 별도 후속 Task로 분리됨
- 필요한 board 갱신 또는 후속 Task가 정리됨

## 6. 잠금 규칙

Agent는 Task를 시작하기 전에 아래 필드를 갱신한다.

```yaml
locked_by: <Current Role>
locked_at: YYYY-MM-DDTHH:mm:ss+09:00
lock_session: session-id
```

잠금 규칙:

- `locked_by`가 비어 있지 않으면 다른 Agent는 실행하지 않는다.
- 같은 Agent라도 이미 `in_progress` 또는 `verification_in_progress` Task가 있으면 새 Task를 시작하지 않는다.
- 작업을 정상 완료하면 다음 상태로 넘기면서 lock을 비운다.
- Agent 세션이 중단되어 lock이 오래 남으면 Lead Role 또는 Direction Role이 사용자 확인 후 lock을 해제한다.
- lock 해제 사유는 Task 변경 이력에 기록한다.

권장 stale lock 기준:

```yaml
lock_timeout_minutes: 240
```

## 7. 우선순위와 의존성

Task 선택 순서:

1. `priority`가 높은 Task
2. `depends_on`이 모두 `done`인 Task
3. `created_at`이 오래된 Task
4. `id`가 앞선 Task

권장 priority 값:

| 값 | 의미 |
|---|---|
| `P0` | 즉시 처리, 차단/장애/긴급 |
| `P1` | 현재 우선 작업 |
| `P2` | 일반 작업 |
| `P3` | 낮은 우선순위 |

`depends_on`은 Task ID 배열로 기록한다.

```yaml
depends_on:
  - T-YYYYMMDD-001
```

`blocks`는 이 Task가 완료되기 전 막는 후속 Task를 기록한다.

```yaml
blocks:
  - T-YYYYMMDD-002
```

## 8. 새 요구사항 우선순위 조정

새 요구사항이 들어오면 Direction Role은 기존 Task Queue를 먼저 확인하고 priority와 의존성을 제안한다.

확인 대상:

- `proposed` Task
- `scoped` Task
- `approved` Task
- `in_progress` Task
- `verification_ready` Task
- `blocked` Task
- 기존 `depends_on`과 `blocks`

규칙:

- 새 요구사항은 기본적으로 `proposed` Task 후보로 정리한다.
- 기존 Task의 `priority`, `depends_on`, 진행 순서를 바꾸기 전에는 사용자 승인을 받는다.
- `in_progress` Task는 자동으로 중단하거나 밀어내지 않는다.
- 새 요구사항이 릴리즈 차단, 장애, 정책 리스크, 보안/개인정보 리스크를 만들면 Direction Role이 우선순위 상승을 제안할 수 있다.
- 우선순위 변경 이유와 기존 Queue 영향을 함께 보고한다.
- Execution Role과 Verification Role은 승인된 상태와 priority 기준으로만 실행한다.

## 9. Task 파일 위치와 보관 구조

새 프로젝트의 Task 파일은 아래 구조를 권장한다.

```text
.ai_project/tasks/
  active/
  backlog/
  archive/
    YYYY-MM/
```

역할:

| 경로 | 용도 |
|---|---|
| `.ai_project/tasks/active/` | 실행 중이거나 실행/검증/완료 판단이 필요한 Task |
| `.ai_project/tasks/backlog/` | 아직 승인되지 않은 후보, 보류 후보, 가까운 실행 후보 |
| `.ai_project/tasks/archive/YYYY-MM/` | 완료, 취소, 오래된 후보 Task 보관 |
| `.ai_project/tasks/` 루트 | 기존 프로젝트 호환용 legacy 위치 |

파일명은 아래 형식을 권장한다.

```text
T-YYYYMMDD-001_task-slug.md
```

새 Task 생성 위치:

- `scoped`, `approved`, `in_progress`, `verification_ready`, `verification_in_progress`, `verification_passed`, `completion_review`, `rework_requested`, `blocked`처럼 실행 또는 판단 대상이면 `active/`에 둔다.
- `proposed` 또는 보류 후보는 `backlog/`에 둔다.
- `done`, `cancelled`, 오래된 `proposed`는 별도 정리 작업에서 `archive/YYYY-MM/`로 이동할 수 있다.
- 기존 프로젝트에 이미 `.ai_project/tasks/` 루트 파일이 있으면 바로 이동하지 않고 legacy Task로 인정한다.
- archive 이동은 상태 변경이 아니라 보관 위치 변경이다. 이동 전후에도 Task ID는 유지한다.

## 10. Task 메타데이터

Task 파일 상단에는 YAML front matter를 둔다.

생성 직후 `proposed` Task 예시:

```yaml
---
id: T-YYYYMMDD-001
title: Task title
status: proposed
type: feature | bugfix | docs | release | ops
priority: P1
priority_reason: Current priority rationale
org_unit: Development Division
team:
team_lead:
workflow: feature
target_agent: {{LEAD_AGENT}}
target_role: Lead Role
required_capabilities:
  - planning
depends_on: []
blocks: []
parallel_group:
allowed_paths:
  - path/to/project-area/
source_of_truth:
  - docs/current_status.md
created_by: {{CREATED_BY}}
approved_by:
locked_by:
locked_at:
lock_session:
lock_timeout_minutes: 240
created_at: YYYY-MM-DD
updated_at: YYYY-MM-DD
report_to: .ai_project/reports/T-YYYYMMDD-001_task-report.md
qa_to: .ai_project/qa/T-YYYYMMDD-001_qa-report.md
---
```

생성 직후 `proposed` Task의 `target_agent` 또는 `target_role`은 scope를 정리할 Lead Role로 둔다. bootstrap 예시에서는 PM Agent가 Lead Role을 겸할 수 있지만, 실제 값은 `.ai_project/agent_registry.md`의 프로젝트별 매핑을 따른다.

Lead Role이 실행 범위를 정리하면 `status: scoped`로 전환하고 `org_unit`, `team`, `team_lead`, `allowed_paths`, `source_of_truth`, `depends_on`, `parallel_group`을 갱신한다.

승인을 확인하면 `status: approved`, `approved_by: Product Owner`, `target_agent: <첫 실행 Agent>`, `target_role: Execution Role`을 함께 갱신한다.

## 11. Role별 Queue 확인 규칙

아래 PM/Development/QA는 bootstrap Role 예시다. 프로젝트별 workflow에 따라 Role은 추가, 삭제, 분리될 수 있다.

공통 기준:

1. Agent는 현재 세션에 부여된 Role을 먼저 확인한다.
2. `active/`에서 현재 Role이 `workflow`와 `status`상 처리 가능한 Task를 찾는다.
3. Task의 `target_agent` 또는 `target_role`이 현재 Role과 맞는지 확인한다.
4. `approved_by`, `depends_on`, `locked_by`, `allowed_paths`, `source_of_truth`를 확인한다.
5. 프로젝트 디렉토리 구조는 고정하지 않는다. 실제 파일 수정, 빌드, 테스트 범위는 `allowed_paths`가 결정한다.
6. `backlog/`와 `archive/`는 workflow가 별도로 허용하지 않는 한 실행 후보로 보지 않는다.

Direction Role:

1. `active/`를 먼저 확인하고, 후보 정리가 필요하면 `backlog/`를 확인한다.
2. `proposed`, `scoped`, `blocked`, `rework_requested`, `completion_review` Task를 확인한다.
3. 사용자 승인이 필요한 Task는 `approved`로 바꾸기 전에 확인을 받는다.
4. `task_board.md`를 Task 상태 요약으로 갱신한다.
5. 다음 작업을 안내할 때 Task ID, workflow, status, `target_agent`, `target_role`, `required_capabilities`, 열 세션, 사용자 요청을 함께 표시한다.

Lead Role:

1. `proposed`, `rework_requested`, `blocked` Task 중 scope 조율이 필요한 Task를 확인한다.
2. `org_unit`, `team`, `team_lead`, ownership, dependency, 병렬 실행 가능 여부를 정리한다.
3. 실행 가능 범위가 정리되면 `scoped`로 전환한다.
4. 조율이 불가능하면 `blocked`로 전환하고 사유를 기록한다.
5. 승인된 Task를 다음 Role로 넘길 때는 `.ai/runtime/role_handoff.md`의 필수 인계 필드를 남긴다. 기본 workflow에서 Execution Role로 넘길 때는 Lead -> Execution 문구를 사용할 수 있다.

Execution Role:

1. `active/`에서 `workflow`가 현재 Role의 전이를 허용하고 `target_agent` 또는 `target_role`이 현재 Role인 Task를 찾는다.
2. `approved` Task만 실행 후보로 본다.
3. `backlog/`와 `archive/`는 실행 후보로 보지 않는다.
4. 우선순위와 의존성 기준으로 하나만 선택한다.
5. 작업 시작 전 lock을 획득하고 Task 상태를 `in_progress`로 바꾼다.
6. 완료 후 작업 보고서를 `reports/`에 작성하고 Task 상태를 `verification_ready`, `target_role: Verification Role`로 바꾸며 lock을 비운다.
7. 다음 Role이 바로 시작할 수 있도록 Task 파일과 최종 응답에 인계 문구를 남긴다. 기본 workflow에서 Verification Role로 넘길 때는 Execution -> Verification 문구를 사용할 수 있다.

Verification Role:

1. `active/`에서 `workflow`가 현재 Role의 전이를 허용하고 `target_agent` 또는 `target_role`이 현재 Role인 Task를 찾는다.
2. `verification_ready` Task만 검증 후보로 본다.
3. `backlog/`와 `archive/`는 검증 후보로 보지 않는다.
4. 우선순위와 의존성 기준으로 하나만 선택한다.
5. 검증 시작 전 lock을 획득하고 Task 상태를 `verification_in_progress`로 바꾼다.
6. 검증 결과에 따라 QA 또는 verification 보고서를 `qa/`에 작성한다.
7. 결과가 `PASS` 또는 `PASS_WITH_RISK`면 Task 상태를 `verification_passed`, `target_role: Completion Role`로 바꾸고 완료 확정 Role에게 인계한다.
8. 결과가 `FAIL`이면 `rework_requested`, `BLOCKED`면 `blocked`로 갱신한다.
9. 완료 또는 차단 처리 시 lock을 비운다.
10. 다음 Role로 넘길 때는 검증 결과와 남은 리스크가 포함된 인계 문구를 남긴다. 기본 workflow에서 Completion Role 또는 Lead Role로 넘길 때는 해당 표준 문구를 사용할 수 있다.

Completion Role:

1. `verification_passed` Task를 확인하고 `completion_review`로 전환한다.
2. 검증 결과, 잔여 리스크, 후속 Task, 릴리즈 영향, board 갱신 필요 여부를 확인한다.
3. 완료 확정이 가능하면 `done`으로 전환한다.
4. 수정이 필요하면 `rework_requested`로 전환한다.
5. 외부 결정이 필요하면 `blocked`로 전환한다.
6. `rework_requested` 또는 `blocked`로 되돌릴 때는 Lead Role이 재조율할 수 있도록 인계 문구를 남긴다.

## 12. Workflow Routing

`target_agent`는 현재 `status`에서 Task 실행 권한의 기존 호환 라우팅 필드다. 필드명은 호환성을 위해 유지하지만, 값은 현재 Task를 처리할 Role 또는 Agent 이름으로 해석한다.

`target_role`은 조직형 모델의 명시적 Role 라우팅 필드다. `target_agent`가 비어 있거나 `any`인 경우 `target_role`이 우선 라우팅 기준이 된다.

`workflow`는 `status`, `target_agent`, `target_role`이 어떻게 다음 처리 상태로 갱신되는지 정한다. 새 Agent를 추가할 때는 Agent 문서에 고정 권한표를 크게 늘리기보다, 필요한 workflow에 해당 Agent가 맡을 상태 전이와 전이 후 `target_agent` 또는 `target_role`을 추가한다.

규칙:

- `target_agent`가 현재 세션 Role과 다르면 실행하지 않는다.
- `target_agent`가 비어 있거나 `any`이면 `target_role`을 확인한다.
- `target_role`도 비어 있거나 `any`인 경우에만 `required_capabilities`로 담당 Role을 판단한다.
- `status: approved`여도 라우팅 필드가 다르면 실행하지 않는다.
- `status`와 라우팅 필드가 맞아도 현재 Task의 `workflow`가 허용하지 않는 다음 전이는 수행하지 않는다.
- `required_capabilities`가 일부 일치해도 라우팅 불일치를 덮어쓸 수 없다.
- 담당 Role이 애매하면 실행하지 않고 Direction Role 또는 Lead Role에게 라우팅 확인을 요청한다.
- 다음 전이 후 `target_agent` 또는 `target_role`이 다른 Role로 바뀌면, workflow가 명시적으로 연속 전이를 허용하지 않는 한 그 Role의 단계까지 이어서 처리하지 않는다.
- 다음 전이 후 담당 Role이 바뀌면 `.ai/runtime/role_handoff.md` 기준으로 `다음 Agent에게 전달할 말`을 남긴다.
- 상태 전이 기록의 `Agent` 값은 실제로 현재 세션에 부여된 역할만 사용한다.

예:

```yaml
target_agent: {{VERIFICATION_AGENT}}
target_role: Verification Role
required_capabilities:
  - release_check
```

위 Task는 프로젝트별 Verification Agent 또는 동등하게 라우팅된 Verification Role만 실행한다. Execution Role이 `release_check`와 관련된 검증 capability를 일부 가질 수 있더라도 이 Task를 실행하지 않는다.

## 13. 충돌 처리

- Task 파일과 `task_board.md`가 다르면 Task 파일을 우선한다.
- Task 파일과 report/QA 문서가 다르면 Task 파일을 우선한다.
- Task 파일과 프로젝트 기술 문서가 다르면 `.ai_project/source_of_truth.md`에 지정된 프로젝트 문서를 확인한다.
- Task 상태 변경이 애매하면 Direction Role 또는 Lead Role이 사용자에게 확인한다.
- lock 상태가 애매하면 Lead Role 또는 Direction Role이 사용자 확인 후 해제 또는 유지한다.

## 14. 변경 이력

| 날짜 | 변경 내용 |
|---|---|
| 2026-06-29 | Task Queue 정책 v1 작성 |
| 2026-06-29 | 상태 전이, 실행 가능 조건, lock, priority, dependency 규칙 추가 |
| 2026-06-29 | QA 통과 후 PM 확정 대기 상태 `qa_passed` 추가 |
| 2026-06-29 | 생성 직후 Task의 `approved_by` 기본값 기준 명확화 |
| 2026-07-01 | `target_agent` 불일치 실행 차단 규칙 추가 |
| 2026-07-01 | 새 요구사항 우선순위 조정 규칙 추가 |
| 2026-07-02 | PM Agent 다음 작업 안내에 담당 Agent 표시 기준 추가 |
| 2026-07-02 | `workflow`, `status`, `target_agent` 기반 상태 전이 기준 추가 |
| 2026-07-02 | `report_to` 기본값을 공통 Task Report로 일반화 |
| 2026-07-02 | 기본 workflow의 단일 상태 전이와 workflow별 예외 가능성 추가 |
| 2026-07-03 | 기본 workflow의 `rework_requested` 재개 판단 기준 추가 |
| 2026-07-07 | Task active/backlog/archive 보관 구조 기준 추가 |
| 2026-07-09 | vNext 상태 체계와 책임 단계 기반 Task Queue로 개정 |

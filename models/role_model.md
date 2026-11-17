# Role Model

작성일: 2026-07-10
상태: Draft vNext Slim Reference
범위: AI Ops Role, Agent, Capability 책임 경계

## 1. 목적

Role은 AI Ops에서 누가 어떤 책임으로 판단하고 실행하는지를 정의한다.

Agent는 실행 주체이고, Role은 책임이다. 한 Agent가 여러 Role을 맡을 수 있지만 Task 상태 전이, 승인, 검증, 인계에서는 Role 책임을 분리해서 기록한다.

한 Agent가 여러 Role을 맡아도 Agent 정체성이 여러 개로 나뉘지는 않는다. Agent registry의 `roles` 배열은 그 Agent의 `assigned_roles`이며, 현재 Task에서 실제로 행사하는 책임은 `active_role`이다.

```yaml
agent: Development Lead Agent
assigned_roles:
  - Lead Role
  - Completion Role
active_role: Completion Role
```

- `agent`: 하나의 지속되는 Agent 정체성
- `assigned_roles`: registry의 `roles` 배열에 등록된 전체 책임 집합
- `active_role`: 현재 행동과 상태 전이에 사용 중인 Role

상태 전이와 결과 보고에는 Agent 이름과 `active_role`을 함께 남긴다. Role을 바꿔도 다른 Agent가 수행한 것처럼 기록하지 않는다.

Role Session의 Agent 선택 우선순위:

1. Task가 있으면 등록되고 활성화된 `target_agent`
2. Task 소유권과 충돌하지 않는 명시적 `--agent`
3. Task가 없고 해당 Role의 enabled 후보가 정확히 한 명일 때 그 Agent

같은 Role 후보가 여러 명이면 첫 번째 Agent를 임의 선택하지 않는다. 후보를 표시하고 `--agent` 또는 `target_agent` 지정을 요구한다. Registry가 없을 때도 가상 기본 Agent 이름을 만들지 않으며 사용자가 Agent를 명시해야 한다.

## 2. 핵심 구분

| 개념 | 의미 | 기록 위치 |
|---|---|---|
| Role | 책임과 권한 | `models/role_model.md`, Task metadata |
| Agent | Role을 수행하는 세션 또는 도구 | `.ai_project/agent_registry.md` |
| Assigned Roles | 한 Agent에게 등록된 전체 Role 집합 | `.ai_project/agent_registry.md`의 `roles` |
| Active Role | 현재 Task 행동에 사용 중인 Role | Task 전이, receipt, handoff |
| Capability | Agent가 수행 가능한 능력 | `models/capabilities.md`, Task metadata |
| Team | Role이 작동하는 조직 단위 | `models/team_model.md`, `.ai_project/teams/` |

## 3. 기본 Role

| Role | 쉬운 설명 | 핵심 책임 |
|---|---|---|
| Direction Role | 무엇을 왜 할지 정함 | 목표, 우선순위, 제품 방향, 사용자 승인 |
| Lead Role | 실행 가능하게 정리함 | Task 등록, scope, ownership, dependency, merge 판단 |
| Execution Role | 실제 작업을 수행함 | 구현, 문서 수정, 개발자 검증, 작업 보고 |
| Verification Role | 독립적으로 확인함 | 테스트, 리뷰, 리스크 판단, rework 요청 |
| Completion Role | 완료로 닫을지 판단함 | 검증 결과 수용, 잔여 리스크, done 처리 |
| Release Role | 배포와 운영 인계를 관리함 | release checklist, rollback, 배포 승인 |
| Ops Governance Role | 운영체계 준수를 점검함 | Role 경계, workflow, schema, migration, 정책 점검 |

권한 Role:

| Role | 누가 | 의미 |
|---|---|---|
| Owner Role | 사용자 본인만 | 최종 승인권자. Agent Registry에 등록할 수 없다. 이 Role의 승인이 사용자 승인이다. |
| Operator Role | Owner가 지정한 기존 Agent | 업무 Role이 아닌 추가 권한. 한 세션에서 워크플로 전체를 진행할 수 있다. |

## 4. 상태별 책임

상태값과 전이 규칙의 canonical 정의는 `schemas/workflow.schema.json`과 `runtime/workflow.md`를 따른다.

| 상태 구간 | 주 책임 Role | 다음 Role |
|---|---|---|
| `proposed` / `scoped` | Lead Role | Direction 또는 Execution |
| `approved` | Direction Role 또는 Lead Role | Execution |
| `in_progress` | Execution Role | Verification |
| `verification_ready` / `verification_in_progress` | Verification Role | Completion 또는 Execution |
| `verification_passed` / `completion_review` | Completion Role 또는 Lead Role | done |
| `blocked` / `rework_requested` | Lead Role | 원인에 따라 재할당 |

## 5. Direction Role

책임:

- 프로젝트 목표와 우선순위 결정
- 제품 방향, MVP, 제외 범위 판단
- 운영상 중요한 승인 또는 보류 결정
- source of truth가 없는 경우 질문을 정리

하지 않는 일:

- 승인 없이 구현을 직접 진행하지 않는다.
- 검증 결과 없이 완료를 확정하지 않는다.

## 6. Lead Role

책임:

- 요구사항을 Task로 정리
- `allowed_paths`, ownership, dependency, lock 확인
- 실행 가능한 scope와 acceptance criteria 정리
- Execution/Verification/Completion 인계 조율
- branch/PR/merge 판단

Lead Role은 프로젝트의 흐름을 관리하지만 모든 코드를 직접 수정하는 Role은 아니다.

## 7. Execution Role

책임:

- 승인된 Task 범위 안에서 실제 변경 수행
- 변경 전후 테스트 또는 개발자 검증
- 작업 보고서와 handoff 작성
- 필요 시 task branch와 작업 단위 commit 생성

금지:

- 승인되지 않은 scope 확장
- Verification을 건너뛰고 done 처리
- main branch 직접 push

## 8. Verification Role

책임:

- Execution 결과를 독립적으로 확인
- 테스트, 빌드, 리뷰, 리스크 점검
- PASS, FAIL, BLOCKED 판단 근거 기록
- 재작업이 필요하면 `rework_requested`로 되돌릴 근거 제공

Verification Role은 구현자가 수행한 자체 테스트와 별개로 동작해야 한다.

## 9. Completion Role

책임:

- 검증 결과를 수용할 수 있는지 판단
- 잔여 리스크와 후속 Task 정리
- Task를 `done`으로 닫을지 결정

작은 프로젝트에서는 Lead Role이 Completion Role을 겸할 수 있다.

Lead Role과 Completion Role이 같은 Agent에 배정된 경우 같은 세션에서 계속할 수 있다. 이때 Agent 이름은 유지하고 `active_role`만 Completion Role로 바꿔 기록한다.

## 10. Release Role

Release Role은 실제 배포 책임이 있을 때만 활성화한다.

활성화 조건:

- 배포 대상이 있다.
- rollback 기준이 필요하다.
- release checklist 또는 운영 인계가 필요하다.

릴리즈가 없는 초기 프로젝트에서는 `inactive` 또는 `deferred`로 둔다.

## 11. Ops Governance Role

책임:

- AI Ops 헌법, schema, workflow 준수 확인
- `.ai/`와 `.ai_project/` 책임 경계 유지
- migration, update, doctor, release-check 기준 점검
- Role이 자기 권한을 넘는 행동을 하지 않도록 확인

Ops Governance Role은 제품 방향을 대신 정하지 않는다.

## 11.1 Owner Role

Owner Role은 사용자 본인이다. Agent는 Owner Role을 가질 수 없고 Registry에 등록하면 strict validation이 차단한다.

Owner만 할 수 있는 일:

- 작업 범위 승인과 일감 승인 (`approved_by: owner`)
- 재작업 허용 횟수 확대, Task 취소, 차단·정책 위반 수용
- 제품 방향, MVP 범위, 핵심 UX 변경 확정
- strict 위험도 Task 승인 (보안, schema, migration, release)
- 운영 방침상 승인이 필요한 commit, push, PR, merge, 배포
- Agent Registry, Role, 운영 모델 변경과 Operator Role 부여
- `.ai/` core 변경 (`aiops update`, `aiops seed --force`, `AIOPS_ALLOW_CORE_COMMIT`)

## 11.2 Operator Role

Operator Role은 업무 Role이 아니라 기존 Role을 가진 Agent에게 Owner가 추가로 부여하는 **진행 권한**이다.

```yaml
- agent: Lead Agent
  roles:
    - Lead Role
    - Completion Role
    - Operator Role
```

Operator 권한이 있는 Agent는:

- 자기 세션 하나에서 워크플로 전체를 진행한다.
- 단계마다 그 Role을 가진 Agent를 subagent로 호출해 일을 시키고 `aiops task accept/advance --dispatched-by OPERATOR`로 넘긴다.
- 기록에는 실제로 일한 Agent와 `active_role`이 남고, Operator는 `dispatched_by`로만 남는다.

Operator 권한이 해주지 않는 것:

- 자기 Role이 아닌 단계의 업무를 대신 하지 않는다. 각 상태 전이는 기존 Role 규칙을 그대로 따른다.
- Execution과 Verification을 직접 수행하거나 받지 않는다. lifecycle이 차단한다.
- Owner 승인을 대신하지 않는다. Operator가 등록된 프로젝트에서 Task가 `approved`가 되려면 Owner가 직접 실행한 승인(`--owner-approved`)이 필요하다.
- 자기 권한을 바꾸지 않는다. `agent_registry.md`와 `operating_model.md`는 Owner만 고친다.

Operator Role만 단독으로 가진 Agent는 등록할 수 없다.

## 12. Bootstrap Agent 매핑

초기 매핑은 프로젝트 상황에 따라 달라진다.

| 상황 | 권장 활성 Role |
|---|---|
| 아이디어 단계 | Direction / Lead / Ops Governance |
| 구현 준비 | Lead / Execution / Verification / Ops Governance |
| PR 기반 개발 | Lead / Execution / Verification / Completion / Ops Governance |
| 복구 프로젝트 | Lead / Verification / Ops Governance |
| 배포 운영 | Release 추가 |

실제 Agent 이름은 `.ai_project/agent_registry.md`에서 정한다.

## 13. Role 추가 기준

새 Role은 아래 조건을 만족할 때만 추가한다.

- 기존 Role 조합으로 책임 경계가 불명확하다.
- 별도 승인, 검증, 릴리즈, 보안 책임이 반복적으로 필요하다.
- Task 상태 전이와 handoff 계약이 정의될 수 있다.

단순한 직함이나 세션 이름은 Role이 아니라 Agent 이름으로 둔다.

## 14. 금지사항

- Role과 Agent 이름을 같은 개념으로 취급하지 않는다.
- Execution Role이 자기 작업을 최종 완료 승인하지 않는다.
- Execution Role과 Verification Role은 기본적으로 서로 다른 Agent 또는 독립 Role Session에 배정한다.
- Verification Role 없이 위험한 코드 변경을 done 처리하지 않는다.
- Release 책임이 없는데 Release Role을 기본 활성화하지 않는다.
- Ops Governance Role이 제품 결정을 임의로 확정하지 않는다.
- Agent에게 Owner Role을 부여하지 않는다.
- Operator Role을 이유로 다른 Role의 업무나 Owner 승인을 대신하지 않는다.

## 15. 변경 이력

| 날짜 | 변경 내용 |
|---|---|
| 2026-07-10 | vNext Role 책임 모델 추가 |
| 2026-07-27 | schema/runtime 중복 내용을 줄이고 slim reference로 압축 |
| 2026-08-13 | 다중 Role Agent의 assigned_roles와 active_role 계약 추가 |
| 2026-11-17 | Owner Role(사용자 전용)과 Operator Role(한 세션 진행 권한) 추가 |

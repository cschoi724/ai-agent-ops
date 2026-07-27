# Role Model

작성일: 2026-07-10
상태: Draft vNext Slim Reference
범위: AI Ops Role, Agent, Capability 책임 경계

## 1. 목적

Role은 AI Ops에서 누가 어떤 책임으로 판단하고 실행하는지를 정의한다.

Agent는 실행 주체이고, Role은 책임이다. 한 Agent가 여러 Role을 맡을 수 있지만 Task 상태 전이, 승인, 검증, 인계에서는 Role 책임을 분리해서 기록한다.

## 2. 핵심 구분

| 개념 | 의미 | 기록 위치 |
|---|---|---|
| Role | 책임과 권한 | `models/role_model.md`, Task metadata |
| Agent | Role을 수행하는 세션 또는 도구 | `.ai_project/agent_registry.md` |
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
- Verification Role 없이 위험한 코드 변경을 done 처리하지 않는다.
- Release 책임이 없는데 Release Role을 기본 활성화하지 않는다.
- Ops Governance Role이 제품 결정을 임의로 확정하지 않는다.

## 15. 변경 이력

| 날짜 | 변경 내용 |
|---|---|
| 2026-07-10 | vNext Role 책임 모델 추가 |
| 2026-07-27 | schema/runtime 중복 내용을 줄이고 slim reference로 압축 |

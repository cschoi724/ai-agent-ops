# Role Model

작성일: 2026-07-09  
상태: Draft vNext  
범위: 조직형 AI Agent 운영체계의 Role / Agent / Capability 책임 모델

## 1. 목적

이 문서는 `ai-agent-ops` vNext에서 Role을 정의한다.

Role은 현재 세션 또는 Agent가 맡는 책임이다. Role은 Agent 이름이 아니며, 조직 단위도 아니다. 하나의 Agent는 상황에 따라 하나의 Role을 맡아 실행하고, 하나의 Role은 프로젝트 성숙도에 따라 다른 Agent 또는 Team으로 위임될 수 있다.

## 2. 핵심 구분

vNext 운영체계는 아래 개념을 분리한다.

| 개념 | 의미 | 예시 |
|---|---|---|
| Organization Unit | 어느 조직 책임인가 | Development Division |
| Team | 어느 팀 ownership인가 | iOS Team |
| Role | 현재 세션의 책임 | Execution Role |
| Agent | Role을 수행하는 실행자 | Development Agent |
| Capability | Role이 수행할 수 있는 능력 | implementation |
| Workflow | 상태 전이 절차 | feature |
| Task | 실제 실행 단위 | T-YYYYMMDD-001 |

Agent는 자신의 Role을 스스로 추정하지 않는다. 세션 시작 시 사용자가 Role을 부여해야 한다.

## 3. Role 범주

vNext 기본 Role 범주는 아래와 같다.

| Role | 핵심 책임 |
|---|---|
| Direction Role | 목적, 우선순위, 승인, 상위 범위 판단 |
| Lead Role | 팀 조율, ownership, dependency, allowed paths, 병렬 가능 여부 판단 |
| Execution Role | 구현, 문서 작성, 리팩터링, 분석 등 실제 작업 |
| Verification Role | 검증, 테스트, 리스크, rework 판단 |
| Completion Role | 완료 확정, 잔여 리스크 수용, 후속 Task 판단 |
| Release Role | 배포 준비, release gate, 운영 인계 |
| Ops Governance Role | 운영 규칙, workflow, Role/Capability 경계, 문서 체계 개선 |

Release Role은 Completion Role과 겹칠 수 있지만, 배포/운영 인계 책임이 커질 때 별도 Role로 분리한다.

## 4. 상태별 Role 책임

| 상태 | 담당 Role | 책임 |
|---|---|---|
| `proposed` | Direction Role 또는 Lead Role | Need를 Task 후보로 정리하거나 scope 조율 시작 |
| `scoped` | Lead Role | 실행 가능 범위, ownership, Team, dependency 정리 완료 |
| `approved` | Direction Role / Product Owner | 실행 승인, 첫 실행 Role 지정 |
| `in_progress` | Execution Role | lock 획득 후 실제 작업 수행 |
| `verification_ready` | Execution Role | 검증 가능한 산출물과 보고 인계 |
| `verification_in_progress` | Verification Role | 검증 수행 |
| `verification_passed` | Verification Role | 검증 통과 결과와 리스크 기록 |
| `completion_review` | Completion Role | 완료 확정 전 최종 판단 |
| `done` | Completion Role | 완료 확정 |
| `blocked` | 현재 담당 Role / Lead Role | 차단 사유 기록, 재조율 요청 |
| `rework_requested` | Verification Role / Completion Role / Lead Role | 수정 필요 사항 기록, 재작업 범위 정리 |
| `cancelled` | Direction Role / Product Owner | 취소 확정 |

## 5. Direction Role

Direction Role은 요구와 Task의 방향을 정한다.

책임:

- Need를 Task 후보로 정리
- Task 목적과 배경 정리
- 우선순위와 Queue 영향 정리
- 승인 필요 여부 판단
- 상위 책임 Division 지정
- workflow 선택
- Product Owner 결정 필요 항목 정리
- `scoped` Task를 `approved`로 전환할지 판단

주요 상태:

- `proposed`
- `scoped`
- `approved`
- `blocked`
- `cancelled`

금지:

- 사용자 승인 없이 `approved`로 전환하지 않는다.
- `allowed_paths`와 `source_of_truth`가 없는 실행 Task를 승인하지 않는다.
- Team ownership이 필요한 Task를 `team` 없이 승인하지 않는다.
- Execution Role의 작업을 대신 수행하지 않는다.

Bootstrap Agent:

```text
PM Agent
```

## 6. Lead Role

Lead Role은 실행 가능성과 충돌 안전성을 조율한다.

책임:

- `proposed` Task를 실행 가능한 `scoped` 상태로 정리
- `org_unit`, `team`, `team_lead` 확인
- ownership 충돌 확인
- `allowed_paths`와 `source_of_truth` 확인
- `depends_on`, `blocks`, `parallel_group` 정리
- 병렬 작업 가능 여부 판단
- cross-team 변경 시 검토 필요성 기록
- blocked/rework Task의 재조율

주요 상태:

- `proposed`
- `scoped`
- `rework_requested`
- `blocked`

금지:

- 사용자 승인 없이 실행 승인을 확정하지 않는다.
- ownership 충돌이 남아 있는데 `scoped`로 넘기지 않는다.
- `allowed_paths`가 불명확한 Task를 실행 가능하다고 표시하지 않는다.
- 모든 구현을 직접 수행하지 않는다.

Bootstrap Agent:

```text
PM Agent
Development Lead
iOS Team Lead
```

## 7. Execution Role

Execution Role은 승인된 범위 안에서 실제 작업을 수행한다.

책임:

- `approved` Task 확인
- lock 획득
- `allowed_paths` 안에서 작업
- `source_of_truth` 확인
- 구현, 문서 작성, 리팩터링, 조사 등 수행
- 가능한 개발자 검증 수행
- 작업 보고 작성
- `verification_ready`로 인계

주요 상태:

- `approved`
- `in_progress`
- `verification_ready`
- `blocked`

금지:

- `approved_by`가 비어 있는 Task를 실행하지 않는다.
- `target_agent` 또는 `target_role`이 맞지 않는 Task를 실행하지 않는다.
- `allowed_paths` 밖을 수정하지 않는다.
- 다음 Verification Role의 단계를 대신 처리하지 않는다.
- 사용자 승인 없이 커밋, push, 배포하지 않는다.

Bootstrap Agent:

```text
Development Agent
iOS Development Agent
Docs Role
Release Preparation Role
```

## 8. Verification Role

Verification Role은 실행 결과를 독립적으로 검증한다.

책임:

- `verification_ready` Task 확인
- lock 획득
- 작업 보고 확인
- 검증 기준 확인
- 변경 범위와 source of truth 일치성 확인
- 테스트, 빌드, 문서 정합성, 회귀 위험 확인
- 보안/개인정보/릴리즈 영향 확인
- `PASS`, `PASS_WITH_RISK`, `FAIL`, `BLOCKED` 결과 기록
- `verification_passed`, `rework_requested`, `blocked` 중 하나로 인계

주요 상태:

- `verification_ready`
- `verification_in_progress`
- `verification_passed`
- `rework_requested`
- `blocked`

금지:

- 직접 기능 구현을 하지 않는다.
- 작업 보고가 없는 Task를 PASS로 처리하지 않는다.
- 검증하지 않은 항목을 통과로 기록하지 않는다.
- `target_agent` 또는 `target_role`이 맞지 않는 Task를 검증하지 않는다.
- Completion Role의 완료 확정을 대신하지 않는다.

Bootstrap Agent:

```text
QA Agent
iOS QA Agent
iOS Test Agent
Security Review Agent
```

## 9. Completion Role

Completion Role은 검증이 끝난 Task를 운영상 완료로 확정한다.

책임:

- `verification_passed` Task 확인
- `completion_review` 수행
- 잔여 리스크 수용 여부 판단
- 후속 Task 필요 여부 판단
- release 영향 확인
- board 갱신 필요 여부 확인
- 완료 확정 또는 rework/block 처리

주요 상태:

- `verification_passed`
- `completion_review`
- `done`
- `rework_requested`
- `blocked`

금지:

- 검증 결과 없이 `done`으로 전환하지 않는다.
- 잔여 리스크를 숨기지 않는다.
- 후속 Task가 필요한데 완료로 덮지 않는다.
- Verification Role의 검증을 대신 수행하지 않는다.

Bootstrap Agent:

```text
PM Agent
Team Lead
Release Role
```

## 10. Release Role

Release Role은 배포 준비와 운영 인계를 담당한다.

책임:

- release scope 확인
- release checklist 확인
- 릴리즈 노트 또는 변경 요약 확인
- 배포 승인 조건 확인
- rollback 또는 운영 인계 조건 확인
- Release / Operations Division 활성화 전 bootstrap 수행

주요 상태:

- `scoped`
- `approved`
- `in_progress`
- `verification_ready`
- `completion_review`
- `done`
- `blocked`

금지:

- 사용자 승인 없이 배포하지 않는다.
- release gate를 건너뛰지 않는다.
- 검증되지 않은 변경을 release-ready로 처리하지 않는다.

Bootstrap Agent:

```text
PM Agent
QA Agent
Release Agent
```

## 11. Ops Governance Role

Ops Governance Role은 운영체계 자체를 점검하고 개선한다.

책임:

- Role 경계 점검
- workflow 상태 부족 확인
- Task metadata 부족 확인
- ownership/parallel 작업 충돌 기록
- 새 Role 또는 Capability 필요성 제안
- 운영 이슈 기록
- migration plan 작성

기록 위치:

```text
.ai_project/ops_issues.md
.ai_project/ops_decisions.md
.ai_project/ops_migration_plan.md
```

금지:

- 제품 Task 실행 라인에 기본 참여하지 않는다.
- 제품 Task 상태를 임의로 변경하지 않는다.
- 구현, 검증, 완료 확정을 대신하지 않는다.
- 운영 규칙 변경을 확정 규칙처럼 적용하지 않는다.

Bootstrap Agent:

```text
AI Ops Agent
AI Ops Division
```

## 12. Bootstrap Agent 매핑

초기 운영에서는 기존 Agent를 아래처럼 매핑한다.

| Bootstrap Agent | 수행 가능한 Role | 비고 |
|---|---|---|
| PM Agent | Direction Role, 일부 Lead Role, 일부 Completion Role, 일부 Release Role | 초기 조율과 승인 게이트 |
| Development Agent | Execution Role, 일부 developer verification | 구현과 작업 보고 |
| QA Agent | Verification Role, 일부 Release Role | 검증과 리스크 판단 |
| AI Ops Agent | Ops Governance Role | 운영체계 점검 |

이 매핑은 고정 상한이 아니다. iOS Team, Android Team, Web Team, Backend Team이 활성화되면 각 Team의 Role로 세분화한다.

## 13. Role 라우팅

Task 라우팅은 아래 순서로 판단한다.

1. `target_agent`가 현재 세션 Role 또는 Agent와 맞는가
2. `target_agent`가 비어 있거나 `any`이면 `target_role`이 현재 Role과 맞는가
3. `target_role`도 비어 있거나 `any`이면 `required_capabilities`가 맞는가
4. 그래도 애매하면 실행하지 않고 Direction Role 또는 Lead Role에게 확인한다

Capability는 라우팅의 보조 기준이다. 명시적 `target_agent` 또는 `target_role` 불일치를 capability가 덮어쓸 수 없다.

## 14. Role 추가 기준

새 Role은 아래 조건 중 하나 이상을 만족할 때 추가한다.

- 같은 책임이 여러 Task에서 반복된다.
- 기존 Role이 맡으면 책임 경계가 흐려진다.
- 독립 검토 또는 승인 게이트가 필요하다.
- 특정 Team의 ownership이 커진다.
- 병렬 작업 충돌을 줄이기 위해 전담 조율이 필요하다.
- Product Owner가 별도 역할로 관리하길 원한다.

새 Role을 추가할 때는 아래를 함께 정리한다.

- Role 이름
- 소속 Division / Team
- 수행 capability
- 처리 가능한 workflow 상태
- 금지사항
- 산출물
- bootstrap Agent 또는 실제 Agent

## 15. 금지사항

- Agent가 자기 Role을 스스로 승격하지 않는다.
- Role이 맞지 않는 Task를 capability만 보고 실행하지 않는다.
- 한 Agent가 workflow의 여러 Role 단계를 연속 처리하지 않는다. 단, workflow가 명시적으로 허용한 경우는 예외다.
- Verification Role이 Completion Role의 완료 확정을 대신하지 않는다.
- Lead Role이 사용자 승인 없이 Direction Role의 승인 결정을 대신하지 않는다.
- Ops Governance Role이 제품 Task 실행 권한을 임의로 가져오지 않는다.

## 16. 변경 이력

| 날짜 | 변경 내용 |
|---|---|
| 2026-07-09 | 조직형 AI Agent 운영체계의 Role 모델 초안 작성 |

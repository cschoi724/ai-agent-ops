# Boss Automation Mode Discussion

상태: 논의 초안 / 구현 미승인 / 계속 갱신 예정
대상: 사용자 권한 위임, 상위 Agent 지휘, Task Queue 자동 운영
작성일: 2026-08-18

이 문서는 Boss Automation Mode에 관한 현재 논의를 보존하기 위한 메모다. 확정된 구현 계획이나 승인된 정책이 아니며, 실제 구현 전에 사용자와 계속 논의하면서 수정한다.

## 1. 사용자 의도

사용자는 일상적인 프로젝트 운영에서 직접 수행하던 아래 역할을 상위 Agent에게 위임하고자 한다.

- 프로젝트 목표와 제약 전달
- 진행할 Task와 우선순위 관리
- 적절한 Role Agent 배정과 작업 지시
- 상태 전이와 인계 흐름의 지속적인 진행
- 검증 실패 시 재작업 지시
- 일반적인 운영 판단과 승인
- 중대한 결정만 사용자에게 보고

자동화 모드를 시작하면 정책, 제품 방향, 법적·보안적 위험 같은 중대한 결정이 발생하지 않는 한 작업을 멈추지 않고 계속 진행하는 것이 목표다.

## 2. 핵심 정정: Boss는 다중 Role Agent가 아니다

Boss Agent는 Direction, Lead, Execution, Verification, Completion, Release Role을 직접 겸하는 Agent가 아니다.

Boss는 각 Role Agent 위에서 동작하는 상위 지휘자이며, 사용자의 Product Owner 권한을 제한적으로 위임받는 별도 supervisor다.

```text
사용자
  -> 목표, 제약, 위임 범위
Boss Agent
  -> Direction Agent
  -> Lead Agent
  -> Execution Agent
  -> Verification Agent
  -> Completion Agent
  -> Release Agent
```

Boss가 Completion 판단을 직접 수행하지 않는다. Completion Agent가 완료 여부를 판단하고, Verification Agent가 독립 검증하며, Lead Agent가 scope와 merge를 조율한다. Boss는 이들에게 작업을 지시하고 결과를 받아 다음 행동을 결정한다.

## 3. 개념적 정체성

Boss는 기존 workflow Role이 아니라 상위 제어 계층의 Agent다.

```yaml
agent: Boss
kind: supervisor
authority: product_owner_delegate

can:
  - prioritize_tasks
  - dispatch_agents
  - approve_routine_actions
  - resolve_operational_decisions
  - request_rework
  - pause_or_resume_automation

cannot_act_as:
  - Execution Role
  - Verification Role
  - Completion Role
```

사용자 화면에서는 `Boss Mode`, 내부 기계 계약에서는 `Supervisor Automation` 같은 명칭을 후보로 둔다. 명칭은 아직 확정하지 않는다.

## 4. 수행자와 지휘자 분리

Task의 `target_agent`, lock, 상태 전이 actor, 검증 결과에는 실제 수행 Agent와 Role을 기록한다. Boss가 지시하거나 승인했다는 이유로 Boss를 수행자로 기록하지 않는다.

```yaml
actor:
  agent: Completion Agent
  role: Completion Role

authorized_by:
  agent: Boss
  authority: product_owner_delegate
```

필요한 경우 아래 책임을 분리해서 기록한다.

- `actor`: 실제 행동을 수행한 Agent와 active Role
- `dispatched_by`: 해당 Agent에게 작업을 지시한 supervisor
- `authorized_by`: 사용자 대신 일상 승인을 제공한 권한 주체
- `verified_by`: 독립 검증을 수행한 Agent
- `accepted_by`: workflow상 결과를 수용한 Role Agent

## 5. Boss의 책임 후보

Boss가 담당할 수 있는 일:

- 사용자의 목표와 제한사항을 automation session에 기록
- Project Snapshot, policy, Task Queue 확인
- Task 우선순위와 실행 순서 결정
- Direction/Lead Agent에게 Task 구체화 지시
- Execution Agent 배정
- 독립 Verification Agent 호출
- 검증 실패 시 재작업 지시
- Completion Agent에게 완료 판단 요청
- Lead/Release Agent에게 PR, merge, release 절차 지시
- 완료 후 branch/worktree cleanup 지시
- 다음 Task 선택과 자동 진행
- 운영상 경미한 결정을 내리고 결정 근거 기록
- 중대한 결정만 사용자에게 escalation

Boss가 하지 않아야 할 일:

- 실제 구현을 수행하고 Execution Agent로 기록
- 자신이 지시한 구현을 독립 검증했다고 기록
- Completion Agent의 완료 판단을 대신 수행
- Release Agent의 배포 책임을 대신 수행
- 다른 Agent 이름이나 Role을 사용해 상태 전이 기록 작성
- 위임 범위를 스스로 확대
- 차단 정책이나 검증 실패를 임의로 무시

## 6. 목표 자동 운영 흐름

```text
1. 사용자가 Boss에게 목표와 제한사항 전달
2. Boss가 현재 프로젝트 상태, policy, Task Queue 확인
3. 다음 Task 선택
4. Direction/Lead Agent에게 scope와 소유권 정리 지시
5. Execution Agent에게 작업 지시
6. Task lifecycle과 receipt 확인
7. Verification Agent에게 독립 검증 지시
8. 실패하면 원인에 맞춰 재작업 지시
9. 통과하면 Completion Agent에게 완료 판단 요청
10. Lead/Release Agent에게 PR, merge, release 절차 지시
11. 완료된 branch와 worktree 정리 지시
12. 다음 Task로 계속 진행
13. 중대한 결정이 발생하면 사용자에게 질문하고 일시정지
```

Boss는 각 Role의 결과를 직접 만들어내는 것이 아니라, 결과 계약과 receipt를 확인하면서 다음 Agent를 호출하는 방식으로 동작해야 한다.

## 7. 상시 위임권 논의

현재 아이디어의 핵심은 자동화 모드를 시작할 때 반복적인 사용자 승인을 Boss에게 위임하는 것이다.

단순히 모든 승인 검사를 제거하기보다, 기간과 범위가 명시된 standing authorization을 기록하는 방식을 우선 후보로 둔다.

```yaml
automation_mode: managed
delegate: Boss
expires_at: 2026-08-19T09:00:00Z

allowed_actions:
  - edit_paths
  - task_transition
  - commit
  - push
  - create_pr
  - merge
  - cleanup_branch

limits:
  max_tasks: 5
  max_parallel_tasks: 2
  allowed_branches: ["task/*"]
  deploy_environments: []
```

Action Plan의 승인 항목을 없애는 것이 아니라, 유효한 automation authorization이 사용자 승인을 대신 충족했다는 evidence를 남기는 방식이 적합하다.

아직 결정하지 않은 항목:

- 기본 허용 action 범위
- merge 자동 승인 여부
- release와 production deploy 위임 가능 여부
- 위임권 유효 기간
- Task 수, 비용, 시간, 재시도 제한
- 프로젝트별 허용 branch와 environment
- 위임권 철회와 즉시 중단 방식

## 8. Boss가 자체 결정할 수 있는 후보

- 승인된 목표 안에서 Task 순서 변경
- 담당 Agent 선택
- Task 분해와 병렬화
- 기존 architecture와 source of truth 안의 일반 기술 판단
- 검증 실패 후 제한된 횟수의 재작업
- CI와 독립 검증 통과 후 다음 단계 지시
- 완료된 branch 정리
- 경미한 경고를 후속 Task로 등록
- 허용 범위 안의 dependency 업데이트

이 목록은 아직 권한 정책으로 확정되지 않았다.

## 9. 사용자에게 escalation할 후보

- 제품 방향, 핵심 UX, MVP 범위 변경
- 가격, 수익화, 사업 정책
- 개인정보, 보안, 법무, 결제 정책
- 데이터 삭제, migration 실패 위험, 호환성 파괴
- 새로운 유료 서비스나 설정된 예산 초과
- 검증 실패 또는 보안 위험 수용
- source of truth 간 충돌
- ownership이 불명확한 대규모 범위 확장
- production 배포 또는 rollback 불가 변경
- force push, protected branch 정책 변경, secret 접근
- automation 권한 자체 확대
- 사용자가 설정한 시간, 비용, Task 수, 재시도 제한 초과

중대한 결정의 정확한 분류 기준과 severity는 후속 논의가 필요하다.

## 10. Risk Profile과 자동화 후보

기존 Light, Standard, Strict Profile을 자동화 강도와 연결할 수 있다.

| Profile | 자동화 후보 |
|---|---|
| Light | 실행, 검증, 완료, PR/merge, cleanup까지 자동 진행 후보 |
| Standard | 별도 Verification과 CI 통과 후 자동 진행 후보 |
| Strict | 실행과 검증은 자동화하되 위험 수용, merge 또는 release에서 사용자 확인 후보 |

Strict Task를 항상 사용자 승인 대상으로 둘지, 프로젝트별 위임권으로 일부 허용할지는 아직 결정하지 않는다.

## 11. 현재 기반에서 활용 가능한 기능

현재 구현된 아래 기능은 Boss Automation의 하위 실행 엔진으로 재사용할 수 있다.

- Project Snapshot, health, policy evaluation
- Action Plan과 승인 필요 action 판정
- Role/Agent/active_role 계약
- `task accept`, `task advance` 상태 전이 자동화
- transition receipt와 handoff
- Light/Standard/Strict Task Risk Profile
- 독립 Verification과 Completion 책임 분리
- PR merge 후 `task close` cleanup
- provider-aware Model Advisor
- dashboard와 Local Serve 상태 관찰

현재 구현되지 않은 핵심 영역:

- Boss supervisor identity와 session 계약
- 사용자의 standing authorization 계약
- 여러 Role Agent를 실제로 호출하는 dispatch protocol
- Task Queue 반복 실행 loop
- 중대한 결정 분류와 decision inbox
- 실행 중 pause, resume, stop, lease expiration
- 실패 재시도, 중단 복구, idempotency
- 시간, 비용, concurrency budget
- supervisor decision과 Role receipt 연결

## 12. 후보 사용자 명령

아래 명령은 논의를 위한 후보일 뿐 확정된 CLI가 아니다.

```sh
aiops boss plan
aiops boss start
aiops boss status
aiops boss decisions
aiops boss pause
aiops boss resume
aiops boss stop
```

대안으로 사용자용 명령은 `aiops automate ...`, 내부 supervisor 이름만 `Boss`로 두는 방식도 검토한다.

## 13. 외부 실행 권한과의 구분

AI Ops의 사용자 승인 계약과 Codex, Claude Code, GitHub, 운영체제, 배포 플랫폼의 도구 실행 권한은 서로 다르다.

Boss에게 AI Ops 내부 권한을 위임해도 외부 실행 환경의 보안 승인을 자동으로 해제할 수는 없다. 실제 무인 실행을 위해서는 각 provider와 실행 환경에서 허용된 permission profile, credential scope, repository protection, deployment policy가 별도로 필요하다.

## 14. 구현 전 계속 논의할 항목

1. Boss가 Product Owner 권한 중 어디까지 대신할 수 있는가?
2. Boss가 merge를 승인할 수 있는 조건은 무엇인가?
3. production deploy는 항상 사용자에게 물을 것인가?
4. Strict Task의 자동 진행 경계는 어디인가?
5. 중대한 결정과 일반 운영 판단을 어떻게 분류할 것인가?
6. 한 번의 Boss session이 처리할 수 있는 Task, 시간, 비용 한도는 무엇인가?
7. 재작업을 몇 번까지 자동 반복할 것인가?
8. 여러 Agent session을 어떤 provider API 또는 실행 adapter로 호출할 것인가?
9. 사용자가 중간에 목표를 변경하면 진행 중 Task를 어떻게 정리할 것인가?
10. Boss의 결정과 실제 Role Agent의 결과를 dashboard에서 어떻게 구분할 것인가?

## 15. 현재 합의와 비합의

현재 합의된 방향:

- Boss는 사용자의 명령을 받아 Role Agent를 지휘하는 상위 Agent다.
- Boss는 Completion/Lead 등 기존 workflow Role을 직접 맡지 않는다.
- 실제 수행, 검증, 완료 판단은 각각의 Role Agent가 담당한다.
- Boss는 Product Owner 대리 권한으로 일상적인 운영 판단과 승인을 처리한다.
- 정책적이거나 중대한 결정은 사용자에게 escalation한다.
- 자동화 중에도 실제 actor와 supervisor/authorizer 기록을 분리한다.

아직 합의하지 않은 내용:

- 정확한 권한 범위와 자동 승인 action
- CLI 명칭과 schema 이름
- 중대한 결정 분류 기준
- merge, release, deploy 자동화 경계
- 실행 provider와 multi-agent dispatch 구현 방식
- 단계별 구현 순서와 일정

이 문서는 위 미결정 사항을 논의하면서 계속 수정한다.

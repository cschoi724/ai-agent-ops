# Session Orchestration Policy

작성일: 2026-07-23  
상태: Draft vNext  
범위: Agent 세션 분리, Role 세션 운영, 보조 위임 기준

## 1. 목적

이 문서는 Agent 작업을 어떤 세션 단위로 나누고 조율할지 정의한다.

Role 모델은 책임을 정의하고, 이 문서는 그 책임을 한 세션에서 처리할지 별도 세션으로 넘길지 정한다.

## 2. 세션 유형

| 유형 | 의미 |
|---|---|
| `role_session` | 사용자가 특정 Role을 부여한 독립 Agent 세션 |
| `orchestration_session` | Lead 또는 Direction Role이 Task, 우선순위, 인계를 조율하는 세션 |
| `delegated_worker` | 현재 세션 안에서 호출되는 보조 작업자 또는 subagent |
| `operated_session` | Operator Role을 가진 Agent의 세션 하나에서 Role Agent들을 subagent로 호출해 워크플로를 진행하는 세션 |

`delegated_worker`는 독립 `role_session`을 대체하지 않는다.

예외: `operated_session`에서 Registry에 등록된 Role Agent를 subagent로 호출하고 `--dispatched-by`로 기록하면, 그 subagent는 해당 Role의 독립 세션으로 인정한다. 조건은 다음과 같다.

- 호출되는 subagent는 Registry에 등록된 별도 Agent이고 해당 Role을 가진다.
- Verification subagent에게는 Task, 변경 diff, 작업 보고서만 넘기고 Execution의 추론 과정은 넘기지 않는다.
- Operator Agent 자신은 Execution과 Verification을 수행하거나 받지 않는다.
- `approved` 진입은 Owner 승인(`--owner-approved`)이 있어야 한다. `--dispatched-by` 유무와 관계없이 다음 경우에 적용된다: Task `team`에 enabled Operator가 있음, 담당 Agent가 Operator이거나 Operator가 있는 팀 소속, Task에 `team`이 없음, `team`이 없는 Operator가 있음. Operator가 없는 다른 팀은 기존 승인 흐름을 그대로 쓴다.
- Owner는 `aiops approve [TASK_ID|끝자리]`로 승인한다(Claude Code 대화창에서는 `! aiops approve 007`). 프로젝트 폴더, 팀 Operator, Task ID를 알아서 채워 `--owner-approved` 전이를 실행한다. `aiops approve`와 `--owner-approved`는 Agent 도구 호출로는 guard가 차단한다.
- 승인 여부와 재작업 허용 횟수는 Owner 승인이 기록된 transition receipt로 판단한다. Task의 `approved_by`, `rework_limit`, CLI 기록은 표시용이다. 재작업 횟수가 허용 횟수(기본 1) 이내면 처음 승인을 유지하고, 넘으면 Owner가 다시 승인한다.
- 진행 순서는 `aiops orchestrate plan TASK_ID --operator AGENT --json`이 계산한다. Operator는 plan의 `state`가 `needs_owner` 또는 `stopped`이면 멈추고 Owner에게 보고한다.
- 프로젝트에서 처음 `operated_session`을 시작할 때 Owner에게 commit 범위, push·PR·merge 방침, 재작업 횟수를 묻고 `.ai_project/ops_decisions.md`에 `aiops:operated-session-consent`로 기록한다.
- Claude Code와 Codex 모두 `aiops-run` skill이 이 절차를 따른다.

## 3. 기본 원칙

- 핵심 책임은 Role Session 기준으로 기록한다.
- 한 Agent에 여러 Role이 등록되어 있고 workflow가 연속 수행을 허용하면 Agent 정체성을 유지한 채 `active_role`만 바꿔 같은 세션에서 계속할 수 있다.
- Execution과 Verification은 기본적으로 별도 Agent 또는 독립 Role Session으로 분리한다.
- Completion, merge, release 판단은 실행 세션이 대신하지 않는다.
- 보조 작업자는 최종 책임자가 아니며, 최종 책임은 현재 Role Session이 가진다.
- 세션 전환은 Task의 `status`, `target_agent`, `target_role`, lock, handoff로 기록한다.
- 다중 worktree 운영에서는 세션 시작 시 `shared_status_policy.md` 기준으로 canonical status ref와 SHA를 확인한다.

### 3.1 Continuous multi-role session

기본 다중 Role 모드는 `continuous`다. 별도 설정 필드를 추가하지 않고 Agent registry의 `roles` 배열을 `assigned_roles`로 해석한다.

같은 세션에서 Role을 바꿀 수 있는 조건:

- 같은 Agent의 `assigned_roles`에 이전 Role과 다음 Role이 모두 등록되어 있다.
- workflow와 프로젝트 override가 해당 전이를 허용한다.
- 아래 독립 분리 조합에 해당하지 않는다.
- 상태 전이와 receipt에 변경된 `active_role`을 기록한다.

기본 독립 분리 조합:

- Execution Role과 Verification Role
- 변경 작성자와 보안·개인정보 독립 검증
- 배포 실행과 최종 Release 승인
- 변경 작성자와 독립 감사

같은 Agent가 Lead Role에서 Completion Role로 이동하는 것은 허용할 수 있지만, 다른 Agent가 완료한 것처럼 이름을 바꾸거나 새 정체성을 만들지 않는다.

## 4. 별도 세션 권장 기준

아래 경우에는 별도 Role Session을 권장한다.

- 코드 또는 제품 문서를 실제 수정한다.
- 독립 검증이 필요하다.
- iOS, Android, Web처럼 ownership이 나뉜다.
- PR, merge, release 판단이 필요하다.
- 보안, 개인정보, 결제, 데이터 삭제처럼 리스크가 높다.
- 한 세션이 자체 작업을 자체 검증하게 될 위험이 있다.

## 5. 보조 위임 허용 기준

보조 위임에 적합한 작업:

- 코드 구조 조사
- 문서 요약
- 테스트 로그 분석
- 영향 범위 후보 정리
- migration / release check 후보 조사
- 읽기 중심 비교 분석

보조 위임만으로 처리하면 안 되는 작업:

- 최종 Task 상태 전이
- Verification PASS / FAIL 최종 판정
- Completion / done 확정
- 사용자 승인 없는 commit, push, merge, deploy
- Task lock 획득 또는 해제
- 다른 Role 명의의 작업 보고 작성

## 6. 세션 인계 기준

다음 Agent 또는 독립 Role Session으로 책임이 이동하면 `.ai/runtime/role_handoff.md`의 compact receipt와 수신 컨텍스트를 남긴다. 같은 Agent가 허용된 Role로 연속 이동할 때도 receipt에는 `active_role` 변경을 기록하지만 새 세션 시작 문구는 생략할 수 있다.

필요하면 아래 정보를 추가한다.

```text
Session Handoff:
- from_role:
- to_role:
- task:
- lock:
- status_ref:
- status_ref_sha:
- worktree_path:
- report_path:
- next_session_start_prompt:
```

보조 작업자를 사용했다면 아래를 보고한다.

```text
Delegation Record:
- delegated_by:
- delegated_scope:
- files_read:
- files_changed:
- result_summary:
- final_owner:
```

## 7. Lock과 책임

### 7.1 병렬 Task

- 팀 동시 진행 한도는 `operating_model.md`의 `parallel_tasks`가 정한다(Owner 전용). 없으면 Operator 팀은 1, 다른 팀은 제한 없음.
- 한도가 2 이상이면 Lead가 큰 작업을 `allowed_paths`가 겹치지 않는 Task로 나눈다. 시작(approved → in_progress) 때 lifecycle이 한도, 자기 worktree, 경로 겹침을 검사한다.
- 실행과 검증은 Task worktree(`aiops worktree create`)에서 하고, `aiops` 명령은 프로젝트 루트 기준으로 실행한다. 변경 경로 검사는 Task worktree 기준이다.
- Completion은 `done` 전에 `aiops worktree merge`로 팀 기준 브랜치에 로컬로 합친다(rebase + fast-forward, merge commit 없음). 충돌이면 합치지 않고 Lead에게 돌려준다. push, PR, merge는 운영 방침을 따른다.

- Lock은 Role Session이 획득한다.
- 보조 작업자는 별도 lock owner가 아니다.
- 보조 작업자를 사용해도 Task의 `locked_by`는 현재 Role로 유지한다.
- 세션이 중단되면 Lead Role 또는 Direction Role이 사용자 확인 후 lock 해제를 판단한다.
- 상태 전이 기록에는 실제로 현재 세션에 부여된 Role만 사용한다.

## 8. 금지사항

- 같은 세션이 사용자 승인 없이 Execution과 Verification을 모두 수행하지 않는다.
- 보조 작업 결과를 독립 검증으로 표기하지 않는다.
- 다른 Role이 수행한 것처럼 상태 전이 기록을 작성하지 않는다.
- 다음 책임이 다른 Agent 또는 독립 분리 Role인데 인계했다고 기록한 뒤 같은 세션에서 대신 수행하지 않는다.
- 같은 Agent의 허용된 Role 이동을 다른 Agent에게 인계한 것처럼 기록하지 않는다.

## 9. 변경 이력

| 날짜 | 변경 내용 |
|---|---|
| 2026-07-23 | Agent 세션 분리와 보조 위임 기준 추가 |
| 2026-08-13 | continuous multi-role session과 독립 분리 조합 명시 |
| 2026-11-17 | Operator Role 기반 `operated_session` 추가 |

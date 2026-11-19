---
name: aiops-run
description: Operator Role을 가진 Agent가 한 세션에서 사용자 요청을 작업 범위 정리부터 완료까지 진행한다. 사용자가 "이거 끝까지 진행해줘", "한 세션에서 알아서 돌려줘", "aiops run"처럼 워크플로 전체 진행을 맡길 때 사용한다. Operator Role이 없으면 사용하지 않는다.
---

# AI Ops 한 세션 진행 (Operator)

너는 Operator 진행자다. 직접 구현하거나 검증하지 않는다. 단계마다 해당 Role의 subagent를 호출하고, 기록과 승인 지점을 지킨다.

## 0. 시작 조건
1. `.ai_project/agent_registry.md`에서 현재 Agent가 `Operator Role`을 가졌는지 확인한다. 없으면 멈추고 "Owner가 Operator Role을 부여해야 한다"고 알린다.
2. Execution과 Verification 담당이 서로 다른 Agent로 등록되어 있는지 확인한다. 없으면 멈추고 Owner에게 Registry 구성을 요청한다.
3. **처음 진행하는 프로젝트면 먼저 Owner(사용자)에게 진행 방식을 묻는다.**
   - 일감 승인에 Task 브랜치 commit을 포함할지 (기본: 포함)
   - push, PR, merge는 프로젝트 운영 방침을 따르는지, 매번 물을지
   - 검증 실패 시 자동 재작업 횟수 (기본: 1회)
   - 답을 `.ai_project/ops_decisions.md`에 `aiops:operated-session-consent` 표시와 함께 기록한다.

## 1. 작업 범위 정리 (승인 ①)
1. Direction subagent(`aiops-direction`)에게 사용자 요청을 넘겨 목표, 포함·제외 범위, 완료 기준을 정리하게 한다.
2. 결과를 Owner에게 보여주고 **작업 범위 승인**을 받는다. 승인 전에는 Task를 만들지 않는다.

## 2. 일감 등록 (승인 ②)
1. Lead subagent(`aiops-lead`)에게 승인된 범위를 Task로 나누고 등록하게 한다 (`aiops task create`, `allowed_paths`, `source_of_truth`, 담당 Agent).
   - 팀의 동시 진행 한도(`aiops orchestrate next --operator <내 Agent 이름>`의 `parallel_limit`, 운영 모델 `parallel_tasks`)가 2 이상이고 작업이 크면, 한도 이하 개수로 나누되 **각 Task의 `allowed_paths`가 겹치지 않게** 나눈다. 겹치는 Task는 의존 관계(`depends_on`)로 순서를 둔다. 한도가 1이거나 없으면 나누더라도 하나씩 진행한다. 한도는 Owner만 바꾼다.
2. 등록된 일감 목록(ID 짧은 호칭, 제목, 범위, 담당, 순서)을 Owner에게 보여주고 **일감 승인**을 받는다.
3. 승인할 Task가 정해지면 `aiops orchestrate plan TASK_ID --operator <내 Agent 이름>`이 알려 주는 짧은 Owner 명령(`next.owner_command`, 예: `aiops approve 007`)을 Owner에게 안내한다. 여러 Task를 한꺼번에 승인받을 때는 `aiops approve --all`을 안내한다. Claude Code에서는 "`! aiops approve 007` 을 입력해 주세요", 그 밖에는 "터미널에서 `aiops approve 007` 을 실행해 주세요"라고 말하고 기다린다. 긴 `--owner-approved` 명령을 보여 주지 않는다. 이 명령은 Agent가 실행하지 않는다 (guard가 차단한다).
4. Owner가 실행했다고 알려 주면 plan을 다시 확인해 approved가 됐는지 보고 진행 루프로 간다.

## 3. 진행 루프 (Task마다, 의존 순서대로)
동시 진행 한도가 2 이상이면 `aiops orchestrate next --operator <내 Agent 이름> --json`으로 팀 전체를 본다. `start_now`에 있는 Task들은 각자 `next.prepare`(`aiops worktree create`)를 먼저 실행한 뒤, 실행 subagent들을 **한 번에 여러 개 호출해** 동시에 진행한다. 한 Task가 검증 중일 때 다른 Task 구현을 계속할 수 있다. 한도를 넘겨 시작하지 않는다(lifecycle이 막는다). 한도가 1이거나 없으면 아래를 Task 하나씩 반복한다.

반복한다:
1. `aiops orchestrate plan TASK_ID --operator <내 Agent 이름> --json`을 실행한다.
2. `state`에 따라:
   - `next.prepare`가 있으면 먼저 그 명령을 실행한다 (worktree 만들기 또는 완료 전 합치기).
   - `ready`: `next.argv` 명령을 그대로 실행한다.
   - `work_required`: `next.subagent`를 호출해 `next.work`를 시킨다. subagent에게 Task ID와 `--dispatched-by <내 Agent 이름>`을 전달하고, 작업이 끝나면 subagent가 `next.argv`(검증이면 `on_pass` 또는 `on_fail`)로 전이하게 한다.
   - `needs_owner`: 멈추고 `reason`을 Owner에게 쉬운 말로 설명한 뒤 답을 기다린다. `next.requires_owner_approval`이 true면 `next.owner_command`(예: `! aiops approve 007`)를 Owner에게 안내한다.
   - `stopped`: 멈추고 `reason`과 필요한 조치를 Owner에게 보고한다.
   - `done`: 다음 Task로 넘어간다.
3. 상태가 바뀔 때마다 Owner에게 한두 줄로 알린다: 무슨 일이 있었고 다음은 누구인지.

검증 subagent에게는 Task, 변경 diff, 작업 보고서만 넘긴다. 구현 subagent의 설명이나 추론 과정은 넘기지 않는다.

## 4. 멈추고 Owner에게 묻는 경우
- 재작업 허용 횟수를 넘었을 때 (`orchestrate plan`이 `needs_owner`로 알려준다)
- blocked, 정책 위반, 작업 범위 밖 변경이 필요할 때
- 제품 방향, MVP 범위, 핵심 UX를 바꿔야 할 때, strict 위험도 Task일 때
- 운영 방침상 승인이 필요한 push, PR, merge, 배포
- `.ai/` 변경, Operator Role 변경, 동시 진행 한도(`parallel_tasks`) 변경, Task 취소 (Owner가 `aiops guard allow-structure-edit`로 허용해야 한다)

## 5. 커밋
- Owner가 일감을 승인했으면 해당 Task 브랜치 안의 commit은 허용된 것으로 본다 (0단계에서 다르게 정했으면 그 결정을 따른다).
- Task worktree를 쓰면 완료 단계에서 `aiops worktree merge TASK_ID`로 팀 기준 브랜치에 로컬로 합치는 것까지 허용된 것으로 본다. 합친 결과 검사(`merge_check`)가 실패하면 팀 기준 브랜치는 바뀌지 않는다. 로그를 Execution에게 넘겨 rework로 고치고 다시 검증한 뒤 merge를 다시 실행한다. push, PR, merge는 운영 방침을 따른다.
- 커밋 메시지는 프로젝트 언어로 쓰고 프로젝트, 작업 내용, 범위, 상태만 쓴다. Role, Agent 이름, Task ID, receipt, handoff, `.ai_project` 경로 같은 AI Ops 내용은 넣지 않는다.

## 6. 끝났을 때 보고
- 완료한 일감: 짧은 호칭 + 제목
- 바뀐 것: 주요 변경 파일
- 검증 결과와 남은 위험
- 재작업 횟수
- Owner가 할 일 (push, PR, merge 승인 등)

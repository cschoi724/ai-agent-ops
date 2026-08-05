# Agent 운영 Monitor 및 시각화 계획

상태: 논의 메모
대상: 통제 강화 기반 구현 이후
담당: AI Ops 운영자

이 문서는 AI Ops의 사용자용 시각화 방향을 정리한다.

현재 우선순위는 `control_contract_improvement_plan.md`의 통제 강화 기반을 먼저 구현하는 것이다. 이 문서는 바로 구현하지 않고, 통제 강화 이후 다시 확정할 시각화 요구사항을 보존한다.

## 핵심 목적

사용자용 시각화는 단순한 설명 화면이 아니라 운영 감시판이어야 한다.

목표는 운영 중간중간 아래를 한눈에 확인하는 것이다.

- 어떤 Agent가 활성화되어 있는가?
- 각 Agent는 어떤 Role로 움직이고 있는가?
- 각 Agent는 실제로 어떤 Task를 수행 중인가?
- Agent가 기본 Role 범위를 벗어난 행동을 하고 있지 않은가?
- 사용자가 추가로 내린 명령이 기존 Role/Task/Workflow와 충돌하지 않는가?
- Task 상태와 Git branch/worktree 상태가 맞게 연결되어 있는가?
- Agent가 오래된 adapter, legacy status, stale 문서를 보고 있지 않은가?
- 프로젝트 설정이 의도와 다르게 변경되거나 drift 되지 않았는가?

즉, 시각화의 핵심은 아래 질문에 답하는 것이다.

```text
지금 Agent 운영이 내가 설계한 프로세스대로 흘러가고 있는가?
```

## 시각화가 감지해야 할 Drift

### 1. Role Drift

Agent의 선언된 Role, 현재 Task의 `target_role`, 실제 수행 행동이 어긋나는 경우다.

예:

- Verification Role Agent가 rework 승인 없이 제품 코드를 수정
- Execution Role Agent가 검증 완료 상태를 직접 처리
- Lead Role Agent가 사용자 승인 없이 merge 진행
- Task의 `target_role`은 Verification인데 현재 Agent가 Execution으로 행동

### 2. Instruction Drift

Agent가 현재 core/adapter 지침이 아니라 오래된 지침이나 세션 내 과거 명령을 유지하는 경우다.

예:

- `AGENTS.md` 또는 `CLAUDE.md`가 현재 adapter template과 다름
- 이전 상태명 `review_ready` 같은 legacy status를 사용
- 현재 workflow catalog에 없는 상태 전이를 수행
- 사용자가 임시로 내린 명령이 Role 정책보다 우선된 것처럼 처리됨

### 3. Task / Branch Drift

Task 상태와 Git branch/worktree 상태가 맞지 않는 경우다.

예:

- local Task 상태는 `completion_review`지만 canonical 상태는 `done`
- PR이 merge된 worktree가 계속 남아 있음
- 작업 브랜치가 기준 브랜치보다 크게 뒤처짐
- 같은 Task를 여러 worktree에서 서로 다른 상태로 보고 있음

### 4. Project Config Drift

프로젝트 운영 설정이 의도와 다르게 바뀐 경우다.

예:

- `.ai_project/operating_model.md`의 `core_version`이 현재 core와 다름
- `workflow_policy`가 프로젝트에서 합의한 값과 다름
- `canonical_status_ref`가 비어 있거나 오래됨
- Agent registry의 활성 Role과 실제 Task 배정이 맞지 않음

## 필요한 데이터

Monitor는 Markdown을 직접 독자적으로 파싱해 판단하면 안 된다.

허용되는 흐름:

```text
.ai_project / Git / workflow catalog
-> project snapshot
-> project monitor / dashboard / visualization
```

통제 강화 1차에서 만들어질 `project snapshot`은 최소한 아래 정보를 제공해야 한다.

### Agent Activity

```json
{
  "agents": {
    "active": [
      {
        "id": "ios_execution_agent",
        "declared_role": "Execution Role",
        "current_task": "T-009",
        "branch": "feature/ios-t009",
        "worktree": "../wt-ios-t009",
        "drift": []
      }
    ]
  }
}
```

### Task / Branch Map

```json
{
  "tasks": {
    "items": [
      {
        "id": "T-009",
        "status": "in_progress",
        "target_role": "Execution Role",
        "target_agent": "iOS Execution Agent",
        "branch": "feature/ios-t009",
        "worktree": "../wt-ios-t009",
        "canonical_status": "verification_ready",
        "drift": ["local_status_differs_from_canonical"]
      }
    ]
  }
}
```

### Drift Summary

```json
{
  "drift": {
    "role_drift": [],
    "instruction_drift": [],
    "task_branch_drift": [],
    "project_config_drift": []
  }
}
```

### Control Actions

```json
{
  "control_actions": [
    {
      "severity": "warn",
      "action": "sync_status",
      "message": "공용 상태 기준이 오래되었습니다.",
      "command": "aiops sync-status --target .",
      "requires_user_approval": true
    }
  ]
}
```

## 화면 구성 후보

첫 시각화는 일반 dashboard보다 `monitor`에 가깝다.

후보 명령:

```sh
aiops project monitor
```

또는:

```sh
aiops ops monitor
```

### 1. Project Config

프로젝트 운영 설정을 보여준다.

```text
Project: CookLog
Operating Mode: team_basic
Workflow: standard_vnext
Canonical Status Ref: origin/develop
Core Version: 0.10.0
```

목적:

- 프로젝트 설정을 한눈에 파악
- core/update/migration drift 확인

### 2. Agent / Role Activity Map

활성 Agent, Role, Task, Branch를 연결해 보여준다.

```text
Agent                 Role              Task    Status              Branch
iOS Execution Agent   Execution         T-009   in_progress         feature/ios-t009
iOS QA Agent          Verification      T-009   verification_ready  verify/ios-t009
Project Lead          Lead              T-012   completion_review   main
```

목적:

- 누가 무엇을 하는지 확인
- Role과 Task 배정이 맞는지 확인

### 3. Task / Branch / Worktree Map

Task와 Git 작업 위치를 연결해 보여준다.

```text
Task   Role          Branch             Worktree          Canonical Sync
T-009  Execution     feature/ios-t009    ../wt-ios-t009    stale
T-012  Lead          main                ./CookLog         current
```

목적:

- 오래된 worktree 탐지
- Task 상태와 canonical 상태 불일치 탐지
- 병렬 Agent 작업의 기준점 확인

### 4. Drift Warnings

운영 drift를 따로 모아 보여준다.

```text
[WARN] iOS QA Agent is editing outside Verification Role
[WARN] AGENTS.md differs from current adapter template
[BLOCKER] T-009 local status differs from canonical status
```

목적:

- Agent가 잘못 이해하고 있는지 빠르게 확인
- 레거시 명령이나 오래된 문서 사용 감지

### 5. Control Actions

운영자가 취할 수 있는 다음 조치를 보여준다.

```text
1. Sync canonical status
   aiops sync-status --target .

2. Review role drift for iOS QA Agent
   check reports/T-009-verification.md

3. Re-open Project Lead session for completion review
   aiops project context --role lead --task T-012
```

목적:

- 문제를 발견하는 데서 끝나지 않고 다음 확인/통제 행동으로 이어지게 함

## 용어와 네이밍 원칙

사용자에게는 내부 필드명을 그대로 노출하지 않는다.

예:

```text
canonical_status_ref -> 공용 상태 기준
status_ref_state -> 상태 동기화 상태
target_role -> 담당 Role
allowed_paths -> 수정 허용 범위
handoff -> 인계 내용
verification_ready -> 검증 대기
completion_review -> 완료 확인 대기
```

단, Agent/debug 모드에서는 원래 필드명을 함께 보여줄 수 있다.

후보:

```sh
aiops project monitor
aiops project monitor --debug
aiops project monitor --json
```

## 출력 방식 후보

구현 순서 후보:

1. Terminal monitor
2. JSON monitor output
3. Static HTML monitor
4. 외부 dashboard adapter

처음부터 HTML dashboard를 만들지 않는다. 먼저 통제 강화 snapshot이 안정화된 뒤 terminal monitor로 운영 감시 목적을 검증한다.

## 중요한 제약

- Monitor는 source of truth가 아니다.
- Monitor 결과를 수동 수정하는 운영 문서로 쓰지 않는다.
- Monitor는 snapshot 또는 같은 상태 계약만 읽는다.
- Monitor와 Agent가 보는 상태 판단 기준은 같아야 한다.
- 시각화는 통제 강화 기반이 안정화된 뒤 다시 범위를 확정한다.

## 다시 결정할 질문

통제 강화 1차 완료 후 아래를 다시 결정한다.

- 첫 명령 이름은 `project monitor`가 적합한가?
- `dashboard`라는 이름을 별도 HTML 화면에 남길 것인가?
- Terminal monitor에서 어느 정도까지 색상/표/상태 아이콘을 쓸 것인가?
- Agent activity는 Task 문서만으로 충분한가, 별도 session/activity log가 필요한가?
- Branch/worktree 매핑은 자동 추론으로 충분한가, Task metadata에 명시해야 하는가?
- Drift 감지는 warning 중심으로 시작할 것인가, blocker까지 올릴 것인가?

# AI Ops 통제 강화 개선 계획

상태: 릴리즈 이후 개선 계획
대상: v0.10.0 이후
담당: AI Ops 운영자

이 문서는 AI Ops가 Agent에게 프로젝트 상태를 더 정확하고 일관되게 읽히고, Agent 행동을 통제 가능한 방식으로 제한하기 위한 개선 계획이다.

사용자용 summary, dashboard, visualization은 별도 계획인 `project_visualization_next_phase_note.md`에서 다룬다. 이 문서는 그 전에 필요한 Agent/CLI 통제 기반만 다룬다.

## 핵심 목표

AI Agent가 `.ai_project/` Markdown 문서를 감으로 해석하지 않고, schema로 검증 가능한 기계 판독 상태 계약을 먼저 읽게 한다.

이를 통해 아래를 달성한다.

- Agent가 같은 프로젝트 상태를 같은 방식으로 판단한다.
- 오래된 worktree, stale canonical ref, 불완전한 Task metadata를 구조적으로 드러낸다.
- Agent가 현재 할 수 있는 행동과 하면 안 되는 행동을 명확히 알 수 있다.
- commit, push, merge, deploy, 상태 전이처럼 승인이나 검증이 필요한 행동을 기계적으로 표시한다.
- 이후 사용자용 summary/dashboard는 같은 상태 계약을 읽어 표현만 담당한다.

## 설계 원칙

### 1. Snapshot은 Source of Truth가 아니다

Source of Truth는 아래 원천이다.

- `.ai_project/` 운영 문서
- `.ai_project/tasks/` Task 문서
- `.ai_project/.runtime/` runtime 기록
- `.ai/runtime/workflows.json`
- schema 파일
- Git branch/head/canonical ref

`project snapshot`은 이 원천을 읽어 만든 projection이다. 수동 편집 대상이 아니며, 저장하더라도 cache 또는 report로만 취급한다.

### 2. Agent는 Contract를 먼저 읽는다

Agent 세션 시작 또는 작업 착수 전 우선순위:

```text
aiops project snapshot --json
-> 필요한 경우 aiops project context --role ROLE --task TASK_ID --json
-> 필요한 source 문서만 추가로 읽기
```

### 3. 통제 신호는 상태값과 근거를 같이 제공한다

Agent에게 단순히 `blocked`만 주면 부족하다.

필요한 정보:

- 어떤 행동이 가능한가
- 어떤 행동이 막혔는가
- 왜 막혔는가
- 근거 파일이나 Git ref는 무엇인가
- 사용자 승인이 필요한가

예:

```json
{
  "control": {
    "can_transition": false,
    "requires_user_approval": ["commit", "push"],
    "blocked_actions": [
      {
        "action": "task_transition",
        "reason": "canonical status ref is stale",
        "evidence": {
          "recorded_status_sha": "1111111",
          "canonical_status_sha": "bb09c23"
        }
      }
    ]
  }
}
```

### 4. 기존 안정 기능은 바로 갈아엎지 않는다

`inspect`, `context`, `health`는 이미 v0.10.0에서 동작한다.

따라서 처음부터 내부 구현을 통합하지 않는다. 먼저 snapshot을 독립 명령으로 추가하고, 테스트로 안정화한 뒤 점진적으로 통합한다.

## 차수별 로드맵

## 1차: Project Snapshot + Control Block

### 목표

Agent가 프로젝트에 들어왔을 때 먼저 읽을 표준 상태 계약을 만든다.

### 구현 범위

- `aiops project snapshot --json` 추가
- `schemas/project_snapshot.schema.json` 추가
- snapshot에 공통 metadata 포함
  - `schema`
  - `core_version`
  - `generated_at`
  - `target`
  - `source_refs`
- snapshot에 운영 상태 포함
  - `core`
  - `project`
  - `agents`
  - `tasks`
  - `workflow`
  - `health`
- snapshot에 통제 신호 포함
  - `control.can_start_task`
  - `control.can_transition`
  - `control.can_commit`
  - `control.can_push`
  - `control.can_merge`
  - `control.requires_user_approval`
  - `control.blocked_actions`
- snapshot에 판단 근거 포함
  - `checks[].id`
  - `checks[].severity`
  - `checks[].confidence`
  - `checks[].message`
  - `checks[].evidence`
- `next[]`를 Agent용과 사용자용으로 분리
  - `audience: agent|user`
  - `action`
  - `command`
  - `message`
- E2E 테스트 추가
- `release-check --strict`에 snapshot/schema 검증 연결
- Codex/Claude adapter가 세션 시작 시 snapshot을 먼저 읽도록 보강

### 최소 출력 예시

```json
{
  "schema": "aiops.project_snapshot.v1",
  "core_version": "0.10.0",
  "generated_at": "2026-08-05T10:00:00Z",
  "target": "/Users/example/CookLog",
  "source_refs": {
    "local_branch": "feature/T-001",
    "local_head": "abc123",
    "canonical_status_ref": "origin/develop",
    "canonical_status_sha": "bb09c23",
    "status_ref_state": "recorded_stale"
  },
  "project": {
    "present": true,
    "name": "CookLog",
    "operating_mode": "team_basic",
    "workflow_policy": "standard_vnext"
  },
  "tasks": {
    "total": 12,
    "active": 3,
    "by_status": {
      "in_progress": 1,
      "verification_ready": 2
    }
  },
  "health": {
    "overall": "warning",
    "warnings": 2,
    "blockers": 0
  },
  "control": {
    "can_start_task": true,
    "can_transition": false,
    "can_commit": false,
    "can_push": false,
    "can_merge": false,
    "requires_user_approval": ["commit", "push", "merge"],
    "blocked_actions": [
      {
        "action": "task_transition",
        "reason": "canonical status ref is stale"
      }
    ]
  },
  "checks": [
    {
      "id": "canonical_status_stale",
      "severity": "warn",
      "confidence": "high",
      "message": "canonical status SHA is stale",
      "evidence": {
        "recorded_status_sha": "1111111",
        "canonical_status_sha": "bb09c23"
      }
    }
  ],
  "next": [
    {
      "audience": "agent",
      "action": "sync_status",
      "command": "aiops sync-status --target /Users/example/CookLog"
    },
    {
      "audience": "user",
      "action": "approve_sync",
      "message": "공용 상태 기준이 오래되어 상태 동기화가 필요합니다."
    }
  ]
}
```

### 제외 범위

- `inspect/context/health` 내부 리팩토링
- `project summary`
- dashboard 또는 HTML 시각화
- policy rule 데이터화
- strict level
- Agent Action Plan Contract

### 독립 검증 기준

독립 검증자는 아래를 확인한다.

- `.ai_project`가 없는 빈 프로젝트에서도 `project snapshot --json`이 JSON을 출력한다.
- seed-only 프로젝트에서도 blocker 상태 snapshot을 출력한다.
- Fast Track 프로젝트에서 snapshot이 schema를 통과한다.
- Guided Full 프로젝트에서 snapshot이 schema를 통과한다.
- Git 저장소가 아닌 프로젝트에서도 snapshot이 실패하지 않는다.
- canonical status ref가 stale인 fixture에서 `status_ref_state`와 `blocked_actions`가 기대대로 나온다.
- `control.requires_user_approval`에 commit, push, merge가 포함된다.
- snapshot 명령은 파일을 수정하지 않는다.
- `release-check --strict`가 snapshot/schema 검증을 포함한다.
- Codex/Claude adapter가 snapshot 우선 확인을 안내한다.

### 완료 기준

- `scripts/test.sh` 통과
- `bin/aiops release-check --strict --allow-pending-release` 통과
- 독립 검증에서 차단 이슈 없음

## 2차: Inspect / Context / Health Snapshot 통합

### 목표

`inspect`, `context`, `health`가 각자 다른 방식으로 상태를 계산하지 않도록 공통 상태 계산 기반을 만든다.

### 구현 범위

- snapshot 생성 로직에서 재사용 가능한 helper 경계 정의
- 중복 상태 계산 로직을 점진적으로 공통화
  - front matter 읽기
  - legacy field 읽기
  - Git branch/head 계산
  - canonical status ref 계산
  - Task 목록과 status 분포 계산
  - workflow catalog 해석
- `inspect --json`과 snapshot의 주요 필드 의미 일치 확인
- `context --json`이 snapshot의 project/git/task/workflow 정보를 재사용할 수 있는지 검토
- `health --json`이 snapshot의 checks/control/readiness에서 파생될 수 있는지 검토

### 제외 범위

- 사용자용 dashboard
- policy rule 데이터화
- action plan

### 독립 검증 기준

독립 검증자는 아래를 확인한다.

- 기존 `project inspect` 출력이 회귀하지 않는다.
- 기존 `project context` 출력이 회귀하지 않는다.
- 기존 `project health` 출력이 회귀하지 않는다.
- 같은 프로젝트에서 snapshot과 inspect/context/health의 핵심 값이 충돌하지 않는다.
  - project name
  - operating mode
  - workflow policy
  - Git branch/head
  - canonical status ref
  - task status distribution
  - health overall
- 기존 E2E 테스트가 모두 통과한다.

### 완료 기준

- `scripts/test.sh` 통과
- 독립 검증에서 snapshot과 기존 명령 간 의미 충돌 없음

## 3차: Policy Rule 데이터화

### 목표

health와 validate 판정 규칙을 CLI 코드 안에만 두지 않고, 기계가 읽을 수 있는 policy rule로 분리한다.

### 구현 범위

- `runtime/policy_rules.json` 후보 추가
- `schemas/policy_rules.schema.json` 후보 추가
- rule 기본 구조 정의
  - `id`
  - `description`
  - `severity`
  - `when`
  - `message`
  - `applies_to`
- strict level 후보 정의
  - `basic`
  - `team`
  - `regulated`
- snapshot/checks가 policy rule 결과를 담을 수 있게 연결
- `project health`와 `validate project`가 rule 결과를 읽는 방식 검토

### 예시

```json
{
  "schema": "aiops.policy_rules.v1",
  "rules": [
    {
      "id": "canonical_status_ref_required_for_team",
      "severity": "warn",
      "applies_to": ["team", "regulated"],
      "when": {
        "project.team_pattern": ["multi_team", "division_based"],
        "source_refs.canonical_status_ref": null
      },
      "message": "팀 기반 운영에서는 canonical_status_ref 설정을 권장합니다."
    }
  ]
}
```

### 제외 범위

- 시각화 구현
- 외부 runtime 실행 엔진
- 사용자별 custom rule editor

### 독립 검증 기준

독립 검증자는 아래를 확인한다.

- policy rules JSON이 schema를 통과한다.
- 잘못된 severity, unknown level, 잘못된 when 구조가 실패한다.
- basic/team/regulated 수준에 따라 같은 상태의 severity가 달라질 수 있다.
- 기존 프로젝트가 strict level을 지정하지 않아도 기존 동작과 크게 충돌하지 않는다.
- release-check가 policy rule syntax/schema를 확인한다.

### 완료 기준

- `scripts/test.sh` 통과
- policy rule negative test 통과
- 독립 검증에서 기존 프로젝트 호환성 차단 이슈 없음

## 4차: Agent Action Plan Contract

### 목표

Agent가 작업을 시작하기 전에 의도한 행동을 구조화해 선언하고, 그 행동이 Role/Task/allowed_paths/approval 정책에 맞는지 검증한다.

### 구현 범위

- action plan 계약 후보 정의
- 후보 명령 검토

```sh
aiops action plan --role execution --task T-001 --json
aiops action validate plan.json
```

- action plan 필드 후보
  - `role`
  - `task_id`
  - `intended_actions`
  - `allowed_paths`
  - `requires_user_approval`
  - `blocked_actions`
  - `evidence`
- snapshot control block과 action plan의 관계 정의
- Agent adapter가 작업 착수 전 action plan을 참고하도록 보강

### 예시

```json
{
  "schema": "aiops.action_plan.v1",
  "role": "Execution Role",
  "task_id": "T-001",
  "intended_actions": ["read_source", "edit_allowed_paths", "run_tests"],
  "requires_user_approval": ["commit", "push"],
  "blocked_actions": []
}
```

### 제외 범위

- Agent 자동 실행 엔진
- 외부 tool permission 시스템 직접 제어
- 사용자 승인 UI

### 독립 검증 기준

독립 검증자는 아래를 확인한다.

- allowed_paths 밖 수정 의도가 action validate에서 차단된다.
- commit/push/merge/deploy는 사용자 승인 필요 행동으로 표시된다.
- 잘못된 role, 없는 task, stale task 상태에서 action plan이 경고 또는 차단을 낸다.
- action plan 결과가 snapshot control block과 충돌하지 않는다.
- Codex/Claude adapter가 action plan을 “강제 실행 명령”이 아니라 “작업 전 검토 계약”으로 안내한다.

### 완료 기준

- `scripts/test.sh` 통과
- action plan schema/e2e 통과
- 독립 검증에서 Agent 행동 통제 의미 충돌 없음

## 사용자용 시각화 계획과의 관계

사용자용 시각화는 이 통제 강화 계획의 결과물을 읽어야 한다.

허용되는 흐름:

```text
.ai_project / Git / workflow catalog
-> project snapshot
-> project summary / dashboard / visualization
```

금지되는 흐름:

```text
dashboard가 Markdown을 직접 파싱해 독자 판단
summary가 health와 다른 규칙 사용
시각화 결과물을 source of truth로 수동 관리
```

시각화 상세 계획은 `project_visualization_next_phase_note.md`에서 별도로 확정한다.

## 전체 완료 후 정리 기준

각 차수 완료 후 독립 검증 결과를 반영한다.

전체 계획이 완료되면 이 문서는 삭제하고, 구현 결과는 아래 정식 문서에 반영한다.

- `README.md`
- `QUICKSTART.md`
- `docs/project_state.md`
- `docs/agent_intent.md`
- `schemas/README.md`
- `CHANGELOG.md`

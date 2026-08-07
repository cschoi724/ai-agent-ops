# Project Visualization Upgrade Plan

상태: 실행 계획
대상: 5차 policy evaluation / project snapshot / action plan 계약 이후
담당: AI Ops 운영자

이 문서는 AI Ops의 사용자용 시각화 업그레이드 계획이다.

5차까지의 핵심 기반은 완료됐다.

- `aiops project snapshot --json`
- `aiops project health --json`
- `aiops policy evaluate --json`
- `aiops action plan --json`
- `canonical_status_ref` / `sync-status`
- `.ai_project/.runtime/status_ref` local cache 계약

따라서 다음 시각화는 Markdown을 직접 파싱해 독자 판단하지 않고, 위 상태 계약을 읽어 사용자에게 운영 상태를 쉽게 보여주는 방향으로 진행한다.

## 목표

시각화의 목적은 예쁜 dashboard가 아니라 운영 판단 시간을 줄이는 monitor다.

사용자가 한눈에 답을 얻어야 하는 질문은 아래다.

- 지금 프로젝트는 작업을 시작해도 되는가?
- 어떤 blocker/warning이 있는가?
- 어떤 Agent/Role/Task가 활성 상태인가?
- Task 상태와 공용 Git 기준이 동기화되어 있는가?
- 다음에 실행할 안전한 명령은 무엇인가?
- 사용자 승인이 필요한 행동은 무엇인가?

## 비목표

초기 단계에서는 아래를 하지 않는다.

- HTML dashboard
- 웹 서버
- 실시간 watch UI
- 복잡한 TUI framework
- 별도 상태 저장소
- Monitor 결과를 source of truth로 저장
- Markdown 원문을 monitor가 독자적으로 재해석

## 원칙

Monitor는 projection이다.

```text
.ai_project / Git / workflow catalog / policy rules
-> project snapshot
-> policy evaluation
-> project monitor
```

원본은 계속 `.ai_project`, Git, workflow/policy catalog다. Monitor는 상태를 보여주고 다음 조치를 안내할 뿐, 운영 결정을 저장하지 않는다.

## 명령 후보

우선 명령은 아래로 시작한다.

```sh
aiops project monitor
aiops project monitor --json
```

후보였던 `dashboard`는 HTML 또는 외부 UI 단계까지 보류한다.

```sh
aiops project dashboard
```

## 출력 모델

### Terminal Output

사람이 바로 읽는 기본 출력이다.

예상 구조:

```text
AI Ops project monitor
target: /path/to/project

Status
  overall: warning
  bootstrap: complete
  task_work: allowed_with_warnings
  multi_agent: ready
  migration: not_required

Git
  branch: develop
  head: 5307f13
  canonical_status_ref: origin/develop
  status_ref_state: recorded_current

Tasks
  total: 68
  active: 20
  approved: 1
  scoped: 2
  proposed: 17

Warnings
  - task_metadata_incomplete: 18 task(s)
  - task_status_ref_missing: 20 active task(s)
  - unresolved_decisions_present: 7 marker(s)

Next
  - aiops validate project --strict
```

### JSON Output

기계가 읽는 출력이다. 초기 schema는 별도 파일로 만들지 않고 experimental field로 시작할 수 있다. 단, release 전에 schema가 필요하면 `schemas/project_monitor.schema.json`을 추가한다.

후보:

```json
{
  "schema": "aiops.project_monitor.v1",
  "target": "/path/to/project",
  "status": {
    "overall": "warning",
    "blockers": 0,
    "warnings": 3
  },
  "readiness": {
    "bootstrap": "complete",
    "task_work": "allowed_with_warnings",
    "multi_agent": "ready",
    "migration": "not_required"
  },
  "git": {
    "branch": "develop",
    "head": "5307f13",
    "canonical_status_ref": "origin/develop",
    "status_ref_state": "recorded_current"
  },
  "tasks": {
    "total": 68,
    "active": 20,
    "by_status": {
      "approved": 1,
      "scoped": 2,
      "proposed": 17
    }
  },
  "warnings": [],
  "blockers": [],
  "next": []
}
```

## 표시할 정보

### 1. Readiness

`project health --json`의 readiness를 사람이 읽기 쉬운 순서로 보여준다.

- bootstrap
- task_work
- multi_agent
- migration

핵심 판단:

- blocker가 있으면 작업 시작 불가
- `multi_agent=sync_required`면 `aiops sync-status` 우선
- `migration=migration_needed`면 `aiops migrate --plan` 우선

### 2. Git / Shared Status

`project snapshot` 또는 `project health`의 git/source_refs를 사용한다.

표시 항목:

- current branch
- local head
- canonical status ref
- canonical SHA
- recorded SHA
- status ref state

주의:

- `.ai_project/.runtime/status_ref`는 local cache로만 표시한다.
- monitor는 이 파일을 commit 대상으로 안내하지 않는다.

### 3. Task Summary

초기에는 전체 Task table을 길게 보여주지 않는다.

표시 항목:

- total
- active
- by_status
- missing metadata count
- missing status_ref_sha count

상세 Task 목록은 `--verbose` 또는 별도 후속 단계에서 다룬다.

### 4. Policy / Checks

`project snapshot.policy.matched_rules` 또는 `policy evaluate` 결과를 표시한다.

우선순위:

1. blocker
2. warn
3. next action

동일 의미의 health check와 policy rule이 중복되면 하나로 요약한다.

### 5. Action Guidance

Monitor는 자동 실행하지 않고 명령을 제안한다.

예:

```text
Next
  - aiops sync-status --target .
  - aiops migrate --plan
  - aiops validate project --strict
  - aiops role prompt execution --task TASK_ID
```

commit/push/PR/merge/deploy/external configuration changes는 monitor에서 실행하지 않는다. 필요한 경우 action plan과 사용자 승인을 안내한다.

## 단계 계획

### Phase 1. Terminal Monitor

목표:

- `aiops project monitor` 추가
- `project health --json`과 `project snapshot --json`의 기존 값을 재사용
- 새로운 판단 로직을 최소화

작업:

- command routing 추가
- human-readable monitor 출력 추가
- `--json` 출력 추가
- E2E 추가

검증:

- 빈 프로젝트에서 blocker monitor 출력
- 정상 guided_full fixture에서 ready monitor 출력
- stale canonical fixture에서 sync_required 출력
- runtime cache ignored fixture에서 dirty Git status 유발 없음

### Phase 2. Policy-Oriented Summary

목표:

- policy matched rule을 monitor에 통합 표시
- blocker/warn/next action을 사용자 중심 문장으로 요약

작업:

- `policy.evaluate` 결과를 monitor summary에 연결
- 중복 check 요약 규칙 정의
- source evidence를 debug 모드에 노출

검증:

- policy blocker가 monitor blocker로 보임
- policy warning이 health warning과 충돌하지 않음
- schema-invalid snapshot은 monitor에서도 실패

### Phase 3. Role / Task View

목표:

- 활성 Agent/Role/Task를 한 화면에서 확인
- 실행 가능한 다음 Role Session을 쉽게 알 수 있게 함

작업:

- active agents summary
- active tasks summary
- approved/scoped/verification/completion 후보 표시
- `role prompt` 추천 명령 표시

검증:

- approved task가 Execution 후보로 표시
- verification_ready task가 Verification 후보로 표시
- completion_review task가 Completion 후보로 표시

### Phase 4. Debug / Machine Contract

목표:

- `--json` 출력을 안정화
- 필요하면 `schemas/project_monitor.schema.json` 추가

작업:

- monitor JSON field 확정
- release-check schema gate 연결 검토
- downstream dashboard adapter가 읽을 최소 계약 정의

검증:

- generated monitor JSON schema validation
- snapshot/health/policy와 핵심 값 불일치 없음

### Phase 5. Dashboard 후보 재검토

목표:

- terminal monitor가 충분한지 평가
- HTML/static dashboard 필요 여부 결정

진행 조건:

- terminal monitor가 실제 프로젝트에서 반복 사용됨
- 사용자가 CLI 출력보다 시각적 구조를 명확히 요구함
- monitor JSON 계약이 안정화됨

그 전에는 HTML dashboard를 만들지 않는다.

## 수용 기준

1. `aiops project monitor`는 파일을 수정하지 않는다.
2. monitor 출력은 snapshot/health/policy와 의미가 충돌하지 않는다.
3. blocker가 있으면 작업 가능처럼 보이면 안 된다.
4. `status_ref_state=recorded_stale`이면 `sync-status`를 다음 조치로 제안한다.
5. `.ai_project/.runtime/status_ref`는 local cache로만 다룬다.
6. 새로운 사용자 문구는 내부 필드명을 과도하게 노출하지 않는다.
7. `--json`은 Agent나 외부 도구가 읽을 수 있게 안정적인 key를 사용한다.

## 다음 구현 후보

첫 구현 Task 후보:

```text
TBD: aiops project monitor terminal summary 추가
```

권장 브랜치:

```text
feature/project-monitor
```

권장 첫 PR 범위:

- `aiops project monitor`
- terminal output
- JSON output
- E2E 3~4개
- 문서 갱신

HTML dashboard나 외부 adapter는 이 PR에 포함하지 않는다.

# State Contract 다음 단계 계획

상태: 릴리즈 이후 개선 계획
대상: v0.10.0 릴리즈 이후
담당: AI Ops 운영자

이 문서는 AI Ops가 프로젝트 상태를 더 정확하고 일관되게 해석하도록 만들기 위한 다음 단계 계획이다. 현재 v0.10.0 릴리즈 범위에는 포함하지 않는다.

## 배경

현재 AI Ops는 Markdown front matter, JSON catalog, CLI 요약을 함께 사용한다.

- 사람은 `.ai_project/*.md` 문서로 운영 상태를 이해한다.
- Agent는 `aiops project inspect/context/health --json` 출력으로 상태를 더 구조적으로 읽을 수 있다.
- Workflow 일부는 `runtime/workflows.json`으로 기계 판독 가능해졌다.

다음 단계에서는 사람용 문서와 Agent/CLI용 상태 모델의 경계를 더 명확히 한다.

핵심 방향:

```text
Markdown 운영 문서는 사람용으로 유지하고,
Agent 판단은 schema가 검증한 snapshot/state contract를 기준으로 통제한다.
```

## 목표

- Agent가 긴 Markdown 전체를 임의 해석하지 않고 정규화된 상태값을 먼저 읽게 한다.
- 상태 판단, Role 가능 행동, Task 전이, health 판정을 schema로 검증할 수 있게 한다.
- 사용자에게는 자연어 요약이나 Dashboard로 같은 상태를 쉽게 보여준다.
- Dashboard나 summary가 새로운 source of truth가 되지 않도록 한다.

## 하지 않을 것

- v0.10.0 릴리즈 전에 구현하지 않는다.
- 기존 `.ai_project/*.md`를 제거하지 않는다.
- source of truth를 Markdown과 JSON으로 이중화하지 않는다.
- Dashboard 구현 방식을 지금 확정하지 않는다.

## 개선 단위

### 1. 출력 JSON Schema 추가

현재 CLI 출력은 schema 이름을 갖고 있지만 별도 JSON Schema 파일은 없다.

추가 후보:

- `schemas/project_inspect.schema.json`
- `schemas/project_context.schema.json`
- `schemas/project_health.schema.json`
- `schemas/project_snapshot.schema.json`

기대 효과:

- Agent와 외부 도구가 출력 구조를 안정적으로 신뢰할 수 있다.
- release-check에서 주요 JSON 출력의 구조를 검증할 수 있다.
- Dashboard 입력 형식이 흔들리지 않는다.

### 2. Canonical State Snapshot 추가

후보 명령:

```sh
aiops project snapshot --json
```

역할:

- `inspect`, `context`, `health`, workflow, Git/canonical 상태를 하나의 JSON으로 묶는다.
- Agent 세션 시작, Dashboard, 외부 runtime adapter의 공통 입력으로 사용한다.
- 파일을 수정하지 않는다.

출력 후보 필드:

```json
{
  "schema": "aiops.project_snapshot.v1",
  "core_version": "0.10.0",
  "generated_at": "2026-08-05T10:00:00Z",
  "source_refs": {
    "canonical_status_ref": "origin/main",
    "canonical_status_sha": "abc123"
  },
  "project": {},
  "agents": {},
  "tasks": {},
  "workflow": {},
  "health": {},
  "next": []
}
```

### 3. State Contract Versioning

모든 기계 판독 출력에 아래 필드를 일관되게 둔다.

- `schema`
- `core_version`
- `generated_at`
- `target`
- `source_refs`

기대 효과:

- Agent가 어떤 core 버전과 어떤 Git 기준으로 판단했는지 알 수 있다.
- stale 상태나 migration 필요 여부를 더 명확히 설명할 수 있다.

### 4. Policy Rule 데이터화

현재 health와 validate 판정 일부는 CLI 코드 안에 있다.

후보:

```text
runtime/policy_rules.json
```

예시:

```json
{
  "rule": "task_requires_status_ref_sha",
  "severity": "warn",
  "when": {
    "canonical_status_ref": "present",
    "task.status": ["approved", "in_progress", "verification_ready"]
  }
}
```

기대 효과:

- 프로젝트 규모에 따라 검증 강도를 조정하기 쉬워진다.
- CLI 코드와 문서 사이의 규칙 중복을 줄인다.
- 나중에 `strict_level: basic|team|regulated` 같은 모델로 확장할 수 있다.

### 5. Agent Action Plan Contract

Agent가 작업 시작 전 의도한 행동을 구조화해 선언하게 한다.

후보 명령:

```sh
aiops action plan --role execution --task T-001 --json
aiops action validate plan.json
```

계약 예시:

```json
{
  "role": "Execution Role",
  "task_id": "T-001",
  "intended_actions": ["read_source", "edit_allowed_paths", "run_tests"],
  "requires_user_approval": ["commit", "push"]
}
```

기대 효과:

- Agent가 Role/Task/allowed_paths 밖 행동을 시작하기 전에 탐지할 수 있다.
- 사용자 승인 필요 행동을 더 명확히 분리할 수 있다.

### 6. User Summary Layer

기계 상태를 사용자에게 자연어로 번역하는 계층을 둔다.

후보 명령:

```sh
aiops project summary
```

출력 방향:

```text
상태: 작업 가능, 동기화 권장
현재 할 일: 3개
막힌 일: 1개
다음 Agent: Execution Role
위험: canonical 상태 동기화 필요
```

이 계층은 `snapshot`을 읽어 생성하는 파생 결과여야 한다.

### 7. Dashboard는 Snapshot 기반으로 검토

사용자용 시각화는 `aiops project snapshot --json` 또는 같은 schema를 읽어야 한다.

하지 말아야 할 것:

- Dashboard가 Markdown 문서를 직접 별도 파싱
- Dashboard 결과물을 수동 수정 source of truth로 사용
- CLI와 Dashboard가 서로 다른 상태 판정 로직 보유

## 권장 순서

1. `project inspect/context/health` 출력 JSON Schema 추가
2. `aiops project snapshot --json` 추가
3. snapshot schema 추가
4. release-check에서 snapshot/schema 검증
5. Agent adapter가 세션 시작 시 snapshot/context를 우선 읽도록 보강
6. `project summary` 또는 Dashboard 방향 재논의
7. policy rule 데이터화와 strict level 확장 검토

## 시각화 메모와의 관계

`project_visualization_next_phase_note.md`는 사용자에게 보여주는 방식에 대한 논의 메모다.

이 문서는 그 전에 필요한 기계 판독 상태 계약을 다룬다.

따라서 다음 단계는 아래 순서가 적절하다.

```text
State Contract 강화 -> User Summary -> Dashboard/Visualization 검토
```

## 완료 후 정리 기준

이 계획은 구현이 완료되면 삭제한다. 구현 결과는 README, docs, schemas, runtime, CHANGELOG에 반영한다.

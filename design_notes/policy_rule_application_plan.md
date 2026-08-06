# 5차 Policy Rule 실제 적용 계획

상태: 작업 전 계획
대상: v0.10.0 이후 통제 강화 5차
완료 후 처리: 구현과 검증이 끝나면 삭제하고 정식 문서에 반영

## 목표

5차의 목표는 `runtime/policy_rules.json`을 단순한 규칙 catalog에서 실제 프로젝트 판단에 쓰이는 정책 평가 기준으로 끌어올리는 것이다.

현재 AI Ops는 `project snapshot`, `health`, `validate`가 프로젝트 상태를 읽고 각각 판단한다. 1~4차에서 snapshot, 상태 통합, policy rule catalog, action plan 계약은 마련되었지만, policy rule은 아직 주로 "정의되고 검증되는 데이터"에 가깝다.

5차에서는 아래 흐름을 만든다.

```text
.ai_project / Git / workflow catalog
-> project snapshot
-> policy_rules.json 평가
-> policy result
-> health / control / next action 판단에 반영
```

즉, Agent가 "왜 이 프로젝트가 ok/warning/blocked인지"를 코드 내부 추측이 아니라 기계가 읽을 수 있는 정책 규칙 결과로 확인할 수 있게 한다.

## 쉬운 예시

정책 규칙:

```text
core_missing:
.ai core가 없으면 blocker
```

프로젝트 상태:

```json
{
  "core": {
    "present": false
  }
}
```

기대 결과:

```json
{
  "matched_rules": [
    {
      "id": "core_missing",
      "severity": "blocker",
      "message": ".ai core missing; run aiops seed first.",
      "evidence": {
        "core.present": false
      }
    }
  ]
}
```

이 결과가 있으면 Agent는 다음처럼 판단할 수 있다.

```text
core_missing rule이 blocker로 걸렸으므로 Task 시작 불가.
먼저 aiops seed가 필요함.
```

## 구현 범위

### 1. Policy Rule Evaluator 추가

새 evaluator는 snapshot JSON과 `runtime/policy_rules.json`을 입력으로 받아 어떤 rule이 적용되는지 계산한다.

후보 명령:

```sh
aiops policy evaluate --target . --json
aiops policy evaluate --snapshot /tmp/project_snapshot.json --json
```

초기 출력 후보:

```json
{
  "schema": "aiops.policy_evaluation.v1",
  "strict_level": "basic",
  "matched_rules": [
    {
      "id": "core_missing",
      "severity": "blocker",
      "message": ".ai core missing; run aiops seed first.",
      "source": "project_snapshot",
      "evidence": {
        "core.present": false
      }
    }
  ],
  "summary": {
    "info": 0,
    "warn": 0,
    "blocker": 1
  }
}
```

초기 evaluator는 복잡한 표현식 엔진을 만들지 않는다. 현재 `policy_rules.json`의 `when` 조건을 아래 수준으로만 처리한다.

- `key: value` exact match
- `key: null`
- `key: [a, b]` 중 하나와 일치
- `checks.some_check_id: "present"`

### 2. Strict Level 결정 방식 정의

기본 strict level은 `basic`으로 둔다.

후보 입력:

```sh
aiops policy evaluate --strict-level basic
aiops policy evaluate --strict-level team
aiops policy evaluate --strict-level regulated
```

향후 `.ai_project/operating_model.md`에 아래 필드를 둘 수 있다.

```yaml
policy_level: team
```

단, 5차에서는 기존 프로젝트 호환성을 우선한다. `policy_level`이 없으면 `basic`으로 처리한다.

각 level 의미:

| Level | 의미 |
|---|---|
| `basic` | 개인/소규모 프로젝트. 핵심 blocker 위주 |
| `team` | 여러 Agent, branch, worktree가 있는 프로젝트. 공유 상태와 Task metadata를 더 엄격히 봄 |
| `regulated` | 감사/배포 안정성이 중요한 프로젝트. 증거 누락과 승인 누락을 더 강하게 봄 |

### 3. Snapshot에 Policy Result 연결

`aiops project snapshot --json` 출력에 policy 평가 결과를 추가한다.

후보 필드:

```json
{
  "policy": {
    "catalog_present": true,
    "strict_level": "basic",
    "matched_rules": [],
    "summary": {
      "info": 0,
      "warn": 0,
      "blocker": 0
    }
  }
}
```

중요 원칙:

- snapshot은 source of truth가 아니라 projection이다.
- policy result도 snapshot 안에 저장되는 "판단 결과"일 뿐 수동 편집 대상이 아니다.
- 기존 `checks`와 policy result가 충돌하면 안 된다.

### 4. Health / Control 반영

초기에는 전체 health/control을 한 번에 policy engine으로 교체하지 않는다.

1차 반영 범위:

- policy blocker가 있으면 `health.overall=blocked`와 충돌하지 않아야 한다.
- policy blocker가 있으면 `control.can_start_task=false`와 충돌하지 않아야 한다.
- policy rule 중 특정 action을 막는 규칙은 `control.blocked_actions`에 반영할 수 있다.

예:

```json
{
  "id": "canonical_status_stale",
  "severity": "warn",
  "matched": true
}
```

이 경우:

```json
{
  "control": {
    "can_transition": false,
    "blocked_actions": [
      {
        "action": "task_transition",
        "reason": "Recorded canonical status SHA is stale"
      }
    ]
  }
}
```

단, 기존 snapshot에서 이미 같은 blocker/check를 만들고 있다면 중복 출력하지 않도록 한다.

### 5. Validate / Release Gate 연결

`release-check --strict`는 이미 policy rule catalog schema 검증을 수행한다.

5차에서는 다음을 추가 검토한다.

- seed fixture에서 `policy evaluate`가 정상 실행되는지 확인
- malformed policy catalog가 release-check에서 실패하는지 유지
- evaluator가 schema-invalid JSON을 출력하지 않는지 확인

### 6. E2E 테스트 추가

필수 테스트:

- `.ai`가 없는 프로젝트에서 `core_missing` rule이 blocker로 match
- `.ai_project`가 없는 프로젝트에서 `project_config_missing` rule이 blocker로 match
- 필수 파일 누락 프로젝트에서 `required_project_file_missing` rule match
- `canonical_status_ref`가 stale인 fixture에서 `canonical_status_stale` rule match
- `basic`에서는 team 전용 rule이 적용되지 않음
- `team`에서는 team 전용 rule이 적용됨
- 알 수 없는 strict level은 실패
- `policy evaluate --snapshot FILE --json`이 파일을 수정하지 않음
- `scripts/test.sh`와 `release-check` 통과

## 제외 범위

5차에서 하지 않는다.

- 사용자 dashboard / HTML monitor 구현
- 복잡한 custom rule editor
- 외부 workflow runtime 도입
- 모든 health / validate 로직 전면 교체
- 프로젝트별 policy rule override 파일 설계
- GUI 기반 승인 UI

## 독립 검증 기준

독립 검증자는 아래를 확인한다.

- `aiops policy evaluate --target . --json`이 schema-valid JSON을 출력한다.
- `aiops policy evaluate --snapshot FILE --json`이 schema-valid JSON을 출력한다.
- `core_missing`, `project_config_missing`, `required_project_file_missing`, `canonical_status_stale`가 기대 상황에서 match된다.
- strict level에 따라 적용 rule이 달라진다.
- policy result와 snapshot `health/control/checks`가 충돌하지 않는다.
- 알 수 없는 strict level, 깨진 policy catalog, 잘못된 snapshot 입력은 non-zero로 실패한다.
- 기존 프로젝트에 `policy_level`이 없어도 basic으로 동작한다.
- `scripts/test.sh`가 통과한다.
- `bin/aiops release-check --strict --allow-pending-release`가 통과한다.

## 완료 기준

- CLI evaluator 추가 완료
- policy evaluation schema 추가 또는 기존 schema에 명확히 연결
- snapshot에 policy result 연결
- 관련 문서 갱신
  - `docs/project_state.md`
  - `schemas/README.md`
  - `CHANGELOG.md`
- E2E 및 negative test 추가
- 독립 검증에서 릴리즈/머지 차단 이슈 없음

## 다음 단계와의 관계

5차가 끝나면 사용자용 시각화는 아래 데이터를 읽으면 된다.

```text
project snapshot
policy matched_rules
health/control
tasks/agents/source_refs
```

따라서 Dashboard나 Monitor는 Markdown을 직접 파싱하지 않고, 5차에서 안정화된 policy evaluation 결과를 표시하는 방향으로 진행한다.

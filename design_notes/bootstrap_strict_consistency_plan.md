# Bootstrap Strict Consistency Improvement Plan

작성일: 2026-08-06
브랜치: `feature/bootstrap-strict-consistency`
상태: 계획

## 목표

실제 bootstrap 테스트에서 드러난 문제를 해결한다.

현재 신규 `guided_full` 프로젝트는 운영 구성 자체는 생성되지만, 명령별 판단이 서로 다르다.

- `bootstrap-guide`: 운영 구성이 완료됐다고 안내
- `project health`: `warning`, `task_work: allowed_with_warnings`
- `project snapshot`: blocker 없음, `can_start_task: true`
- `doctor --strict`: 선택 문서 누락을 missing으로 보고 실패
- `validate project --strict`: 선택 문서 누락을 missing으로 보고 실패

목표는 문서를 무조건 더 만들게 하는 것이 아니다.
`bootstrap_mode`, `branch_pr`, `workflow_policy`, migration 상황에 맞춰 필수/선택 기준을 나누고, Agent와 사용자가 같은 상태를 읽도록 만드는 것이다.

## 실제 재현 Fixture

테스트 프로젝트:

```text
/Users/annyeongjelly/Desktop/Projects/Dev/AIOPS_BOOTSTRAP_SCENARIO_TEST
```

핵심 설정:

```yaml
bootstrap_mode: guided_full
core_version: "0.11.0"
start_context: new_project_with_requirement
readiness_level: idea_structured
operating_mode: solo_light
team_pattern: single_team
workflow_policy: skip_scoped_for_simple_tasks
ownership_model: path_plus_domain
coordination: single_active_task
branch_pr: pending_decision
canonical_status_ref: unresolved
knowledge_mode: minimal
```

현재 누락으로 잡히는 파일:

```text
.ai_project/branch_pr_strategy.md
.ai_project/workflow_overrides.md
.ai_project/ops_migration_plan.md
```

## 기준 결정

### Core Required

아래는 신규 bootstrap 이후 항상 있어야 하는 핵심 운영 파일이다.

```text
.ai_project/operating_model.md
.ai_project/agent_registry.md
.ai_project/current_context.md
.ai_project/source_of_truth.md
.ai_project/task_board.md
.ai_project/ops_decisions.md
.ai_project/ops_issues.md
.ai_project/tasks/
.ai_project/tasks/active/
.ai_project/tasks/backlog/
.ai_project/tasks/archive/
```

### Conditional Required

아래는 상황에 따라 필요하다.

```text
.ai_project/branch_pr_strategy.md
```

필수 조건:

- `branch_pr`가 `pending_decision`이 아님
- 또는 원격/PR/merge 전략이 실제 활성화됨

없어도 되는 조건:

- 신규 프로젝트이고 `branch_pr: pending_decision`

```text
.ai_project/workflow_overrides.md
```

필수 조건:

- `workflow_policy: custom`
- 또는 프로젝트별 workflow override가 있다고 명시됨

없어도 되는 조건:

- 표준 workflow option을 그대로 사용

```text
.ai_project/ops_migration_plan.md
```

필수 조건:

- `aiops migrate --plan` 또는 `--apply` 대상
- `bootstrap_mode`가 migration 성격
- 기존 `.ai_project` 업그레이드 영향 분석이 필요한 경우

없어도 되는 조건:

- 신규 bootstrap 프로젝트

## 개선 단계

## 1단계: Required File Rule 분리

`doctor`와 `validate project --strict`의 필수 파일 판정을 아래처럼 분리한다.

- Core Required: 없으면 strict 실패
- Conditional Required: 조건이 맞을 때만 없으면 strict 실패
- Not Required: 현재 상황에서 필요 없으면 `not_required` 또는 `ok`로 안내

예상 출력 예:

```text
not_required: .ai_project/branch_pr_strategy.md
reason: branch_pr pending_decision

not_required: .ai_project/workflow_overrides.md
reason: workflow_policy skip_scoped_for_simple_tasks uses standard catalog

not_required: .ai_project/ops_migration_plan.md
reason: new project bootstrap, migration not requested
```

완료 조건:

- 신규 `guided_full` fixture에서 `doctor --strict` 통과
- 신규 `guided_full` fixture에서 `validate project --strict` 통과
- 기존 migration 관련 E2E는 유지

## 2단계: 상태 판정 일관성 정렬

`health`, `snapshot`, `doctor`, `validate`가 같은 프로젝트를 서로 다르게 판단하지 않게 정렬한다.

이번 fixture의 목표 판정:

```text
doctor --strict: pass with warnings
validate project --strict: pass with warnings
project health: warning
project snapshot health.overall: warning
project snapshot control.can_start_task: true
project snapshot control.can_transition: true 또는 canonical 정책에 따른 warning
policy evaluate: schema-valid, blocker 0
```

주의:

- `canonical_status_ref: unresolved`는 단일/초기 프로젝트에서는 warning이다.
- multi-worktree/team 병렬 운영에서는 더 강한 정책으로 볼 수 있다.

완료 조건:

- 같은 fixture에서 네 명령의 blocker 수가 충돌하지 않음
- `policy evaluate`가 strict 필수 파일 정책과 모순되는 결과를 내지 않음

## 3단계: core_version 비교 오탐 수정

현재 doctor는 아래처럼 같은 버전을 다르게 판단한다.

```text
warn: .ai_project core_version "0.11.0" differs from current core 0.11.0
```

원인 후보:

- YAML front matter에서 따옴표가 포함된 literal string으로 읽힘
- legacy parser가 markdown line을 단순 문자열로 읽어 quote를 제거하지 못함

개선:

- `core_version` 비교 전 양쪽 값을 scalar string으로 정규화
- 앞뒤 quote/backtick 제거
- 공백 제거

완료 조건:

- `core_version: "0.11.0"`과 `VERSION=0.11.0` 비교 시 경고 없음
- 실제 mismatch는 계속 경고

## 4단계: session-guide 표시 보강

현재 `session-guide`에서 아래 항목이 비어 나온다.

```text
활성 Agent / Role 후보:

현재 초점:
```

개선:

- `agent_registry.md`의 enabled/deferred Agent 표시
- `current_context.md`의 현재 초점 또는 현재 운영 상태 표시
- 다음 추천 Role을 bootstrap 상태에 맞춰 제안

예상 출력:

```text
활성 Agent / Role 후보:
  - current-ai-agent-session: Direction / Lead / Ops Governance
  - deferred-execution-agent: Execution, planning ready 이후 활성화
  - deferred-verification-agent: Verification, implementation ready 이후 활성화

현재 초점:
  요구사항 있는 신규 프로젝트의 기획 구조를 정리한다.

추천 다음 세션:
  aiops role prompt direction --target "..."
```

완료 조건:

- 신규 guided_full fixture에서 빈 섹션이 나오지 않음
- active/deferred Role 구분이 보임
- 초보자가 다음 행동을 이해할 수 있음

## 5단계: E2E 회귀 테스트 추가

새 테스트를 추가한다.

후보 파일:

```text
tests/e2e_bootstrap_strict_consistency.sh
```

테스트 fixture:

- `.ai` symlink
- `AGENTS.md`, `CLAUDE.md`
- 신규 guided_full `.ai_project`
- `branch_pr: pending_decision`
- `workflow_policy: skip_scoped_for_simple_tasks`
- migration 없음
- `core_version: "현재 VERSION"`

검증:

```text
aiops doctor --strict
aiops validate project --strict
aiops project snapshot --json
aiops validate project-snapshot snapshot.json
aiops policy evaluate --snapshot snapshot.json --json
aiops validate policy-evaluation policy.json
aiops project health --json
aiops session-guide
```

기대:

- doctor/validate strict exit 0
- snapshot schema-valid
- policy evaluation schema-valid
- missing branch_pr_strategy/workflow_overrides/ops_migration_plan 출력 없음
- session-guide의 활성 Role/현재 초점 섹션이 비어 있지 않음

## 독립 검증 요청 문구

각 단계 구현 후 아래 방식으로 독립 검증을 요청한다.

```text
feature/bootstrap-strict-consistency 브랜치의 최신 커밋 기준으로 bootstrap strict consistency를 독립 검증해줘.
신규 guided_full 프로젝트 fixture에서 doctor --strict, validate project --strict, project health, project snapshot, policy evaluate, session-guide가 서로 모순 없이 동작하는지 확인해줘.
특히 branch_pr_strategy.md, workflow_overrides.md, ops_migration_plan.md가 신규 프로젝트에서 불필요하게 missing으로 처리되지 않는지 봐줘.
파일은 수정하지 말고 결과만 보고해줘.
```

## 완료 후 정리

이 계획 문서는 작업 완료와 독립 검증 후 삭제 대상이다.

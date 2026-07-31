# Coordination Policy

작성일: 2026-07-10
상태: Draft vNext Slim Reference
범위: 병렬 작업, dependency, blocked, rework 조율 기준

## 1. 목적

Coordination은 여러 Agent, Role, Team이 같은 프로젝트에서 충돌 없이 일하도록 조율하는 기준이다.

이 문서는 병렬 작업을 언제 허용할지, dependency와 blocked를 어떻게 기록할지, rework를 누가 정리할지를 정의한다.

## 2. 기본 원칙

- 한 Task의 source of truth는 Task 파일이다.
- 다중 worktree 운영에서 공용 Task 상태는 `shared_status_policy.md`의 `canonical_status_ref` 기준으로 확인한다.
- 병렬 작업은 ownership, lock, dependency가 명확할 때만 허용한다.
- 불명확하면 `single_active_task`로 되돌린다.
- blocked와 rework는 실패가 아니라 조율 상태다.
- Lead Role은 병렬 가능 여부와 충돌 해소 책임을 가진다.

## 3. Coordination Model

canonical 선택값은 `schemas/operating_model.schema.json`과 `runtime/bootstrap_options.json`을 따른다.

| Model | 의미 | 권장 상황 |
|---|---|---|
| `single_active_task` | 핵심 Task 하나만 진행 | 초기 프로젝트, solo_light |
| `parallel_with_locks` | lock과 ownership이 겹치지 않으면 병렬 허용 | 여러 Agent가 분리된 영역 작업 |
| `team_board_coordination` | Project Board와 Team Board로 병렬 조율 | multi-team |
| `custom` | 프로젝트 규칙 사용 | 기존 PM/issue 프로세스 유지 |

기존 표현인 `parallel_with_dependencies`, `parallel_by_ownership`, `lead_coordinated_parallel`은 bootstrap에서 위 canonical 값으로 매핑한다.

## 4. 병렬 작업 허용 조건

아래 조건을 모두 만족하면 병렬 작업을 허용할 수 있다.

- Task별 `allowed_paths` 또는 `owned_domains`가 겹치지 않는다.
- `depends_on`, `blocks` 관계가 기록되어 있다.
- 같은 source of truth 문서를 동시에 수정하지 않는다.
- Team Board 또는 Project Board에서 병렬 상태가 보인다.
- Lead Role이 병렬 가능하다고 판단했다.
- 각 Agent가 확인한 `status_ref`와 `status_ref_sha`가 기록되어 있다.

## 5. 병렬 작업 금지 조건

아래 경우에는 병렬 작업을 중단하거나 Lead 판단을 받는다.

- 같은 파일이나 디렉토리를 동시에 수정한다.
- 같은 API 계약, schema, architecture decision을 바꾼다.
- 한 Task 결과가 다른 Task의 전제 조건이다.
- Verification Role이 재현 가능한 검증 기준을 갖지 못한다.
- release 또는 migration 중 rollback 기준이 없다.

## 6. Dependency

Dependency는 선행 작업이 끝나야 진행 가능한 관계다.

dependency 해제는 local worktree snapshot이 아니라 canonical status ref 기준으로 확인한다.

Task metadata 권장 필드:

```yaml
depends_on:
blocks:
blocked_by:
parallel_group:
```

Lead Role은 Task 등록 또는 scope 단계에서 dependency를 확인한다.

## 7. Blocked

`blocked`는 진행 불가 상태다.

필수 기록:

```yaml
blocker:
blocked_since:
blocked_owner:
next_decision:
```

blocked 해소 주체가 사용자라면 명확한 질문으로 남긴다. Agent가 스스로 해결 가능한 문제라면 별도 recovery Task를 만들 수 있다.

## 8. Rework

`rework_requested`는 검증 결과 수정이 필요한 상태다.

필수 기록:

```yaml
rework_reason:
requested_by:
required_changes:
return_to_role:
```

Verification Role은 rework 요청 시 실패 근거와 재검증 기준을 기록한다.

## 9. Cross-Team 조율

Cross-Team 변경은 Lead Role이 조율한다.

필수 확인:

- 영향을 받는 Team
- shared path 또는 shared domain
- source of truth 변경 여부
- merge 순서
- 검증 책임

Team 간 충돌이 있으면 Project Board에 노출한다.

## 10. Source of Truth 조율

source of truth 문서가 충돌하면 코드 변경보다 문서 기준을 먼저 확정한다.

원칙:

- 요구사항, API, architecture 문서가 서로 다르면 `unresolved`로 기록한다.
- Agent는 불확실한 기준을 사실처럼 확정하지 않는다.
- Direction 또는 Lead Role이 사용자에게 결정 질문을 올린다.

## 11. 기록 위치

```text
.ai_project/tasks/<state>/<task_id>.md
.ai_project/task_board.md
.ai_project/teams/<team_id>/task_board.md
.ai_project/ops_issues.md
```

Task metadata가 우선이고, Board는 요약 view다.

## 12. 금지사항

- ownership이 겹치는데 병렬 작업을 강행하지 않는다.
- dependency를 말로만 두고 Task에 기록하지 않는다.
- blocked 상태를 done처럼 닫지 않는다.
- rework 범위 없이 "다시 해줘"만 남기지 않는다.
- Lead 승인 없이 cross-team path를 넓히지 않는다.

## 13. 변경 이력

| 날짜 | 변경 내용 |
|---|---|
| 2026-07-10 | 병렬 작업, dependency, rework, blocked 조율 기준 추가 |
| 2026-07-27 | 중복 예시를 줄이고 slim reference로 압축 |

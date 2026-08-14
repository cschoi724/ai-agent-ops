# Shared Status Policy

작성일: 2026-07-31  
상태: Draft vNext  
범위: 다중 Agent, Git worktree, Task 상태 공유, 공용 상태 기준 ref

## 1. 목적

이 문서는 여러 Agent가 서로 다른 branch 또는 worktree에서 작업할 때, 최신 공용 Task 상태를 무엇을 기준으로 판단할지 정의한다.

AI Ops는 특정 브랜치 전략을 강제하지 않는다. 대신 프로젝트마다 공용 상태 기준인 `canonical_status_ref`를 명시하고, Agent가 현재 worktree의 `.ai_project/` 문서를 최신 공용 상태로 오인하지 않도록 한다.

## 2. 핵심 원칙

- 공용 상태 기준은 프로젝트별 `canonical_status_ref`다.
- 각 worktree의 `.ai_project/`는 해당 branch/HEAD 시점의 snapshot이다.
- Agent는 현재 worktree 문서를 최신 공용 상태로 단정하지 않는다.
- 세션 시작 또는 재개 시 canonical ref를 fetch하고 확인한 SHA를 보고한다.
- Task dependency 해제, merge 판단, `done` 확정은 canonical ref 기준으로 확인한다.
- local task branch의 상태 변경은 공용 기준에 merge되기 전까지 전역 완료로 간주하지 않는다.

## 3. Canonical Status Ref

`canonical_status_ref`는 프로젝트의 최신 공용 운영 상태를 판단하는 Git ref다.

예:

```yaml
canonical_status_ref: origin/main
canonical_status_ref: origin/develop
canonical_status_ref: origin/release/current
```

브랜치 전략별 예:

| 전략 | canonical_status_ref 예시 |
|---|---|
| main trunk | `origin/main` |
| develop integration | `origin/develop` |
| release train | `origin/release/current` |
| custom company flow | 프로젝트별 통합 ref |

팀별 통합 기준이 다르면 프로젝트별 override로 기록한다.

```yaml
canonical_status_ref:
  project: origin/develop
  ios: origin/ios/develop
  android: origin/android/develop
```

## 4. 기록 위치

권장 위치:

```text
.ai_project/operating_model.md
.ai_project/branch_pr_strategy.md
.ai_project/teams/<team_id>/branch_pr_strategy.md
```

최소 필드:

```yaml
canonical_status_ref: origin/main
```

선택 필드:

```yaml
status_ref_checked_at:
status_ref_sha:
```

## 5. Session Start Sync

Role Session은 작업 시작 전 아래를 확인한다.

1. 현재 worktree branch와 HEAD
2. canonical status ref 설정값
3. `git fetch --prune origin` 실행 가능 여부
4. canonical ref의 최신 SHA
5. 현재 worktree HEAD와 canonical ref의 관계

Agent는 확인한 기준을 최종 응답 또는 handoff에 남긴다.

```text
status_ref: origin/develop
status_ref_sha: bb09c23
worktree_branch: task/T-20260731-001-example
worktree_head: 123abcd
```

## 6. Task State Authority

Task 파일은 실행 지시의 source of truth다. 단, 다중 worktree 운영에서는 어느 ref의 Task 파일을 읽었는지가 함께 기록되어야 한다.

| 판단 | 기준 |
|---|---|
| 현재 Agent가 수행 중인 local 작업 상태 | 현재 worktree Task 파일 |
| 다른 Agent가 볼 공용 Task 상태 | `canonical_status_ref`의 Task 파일 |
| dependency 해제 | canonical ref 기준 |
| `done` 확정 | canonical ref 기준 |
| merge 가능 판단 | PR diff + canonical ref 기준 |
| rework/blocked 조율 | 현재 worktree 기록 + canonical ref 최신 상태 비교 |

`done`은 task branch에서 먼저 기록될 수 있지만, Completion Role은 canonical ref에 merge된 상태를 확인하기 전까지 전역 완료로 확정하지 않는다.

## 7. Worktree Lifecycle

worktree는 아래 상태로 분류한다.

| 상태 | 의미 | 조치 |
|---|---|---|
| `active` | 진행 중 작업 | 유지 |
| `verification` | 검증 또는 재검증 중 | 유지 |
| `merged` | 관련 branch가 canonical ref에 통합됨 | dirty/unpushed 확인 후 cleanup 후보 |
| `stale` | 오래된 base ref 또는 뒤처진 remote 기준 | 상태 판단 기준으로 사용 금지 |
| `dirty` | uncommitted 변경 존재 | 제거 금지 |
| `unpushed` | local commit이 remote에 없음 | 제거 금지 |
| `cleanup_candidate` | merged, clean, 보존 필요 없음 | 사용자 승인 후 제거 가능 |

AI Ops는 상태 조회나 프로젝트 정책만으로 worktree를 자동 삭제하지 않는다. 실제 정리는 `aiops task close TASK_ID --apply`처럼 사용자가 명시적으로 적용해야 하며, 프로젝트별 `delete_branch_after_merge` 정책이 정리를 금지하지 않아야 한다. 원격 branch 삭제는 별도 `--delete-remote`가 필요하다.

Task의 `done`과 Git cleanup은 별도 결과다. cleanup 실패가 Task 상태를 되돌리거나 새로 `done`으로 만들지 않으며, 결과는 `.ai_project/.runtime/task_cleanup/`의 로컬 receipt에 `complete`, `partial`, `blocked`로 기록한다. 공용 완료 판단은 계속 canonical Task 상태와 merge 증거를 사용한다.

## 8. 금지사항

- 현재 worktree의 `.ai_project/task_board.md`만 보고 공용 상태를 확정하지 않는다.
- stale worktree의 Task 상태로 dependency를 해제하지 않는다.
- local branch에만 존재하는 `done`을 전역 완료로 보고하지 않는다.
- dirty 또는 unpushed worktree를 자동 cleanup 대상으로 분류하지 않는다.
- 오래된 루트 WIP branch를 최신 운영 상태 조회 기준으로 사용하지 않는다.

## 9. 권장 CLI 흐름

세션 시작:

```sh
aiops status-ref
aiops sync-status
```

Task 상태 확인:

```sh
aiops task status T-YYYYMMDD-001 --source canonical
```

worktree 점검:

```sh
aiops worktree doctor
```

완료 Task 정리:

```sh
aiops task close T-YYYYMMDD-001 --check
aiops task close T-YYYYMMDD-001 --apply
aiops task close T-YYYYMMDD-001 --apply --delete-remote
```

## 10. 변경 이력

| 날짜 | 변경 내용 |
|---|---|
| 2026-07-31 | 다중 Agent worktree 공용 상태 기준 정책 추가 |
| 2026-08-14 | canonical 완료 확인 기반 Safe Task Close와 로컬 cleanup receipt 기준 추가 |

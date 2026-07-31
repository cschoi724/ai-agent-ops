# Shared Status / Worktree Guide

여러 Agent가 각자 Git worktree에서 작업하면, 현재 폴더의 `.ai_project/`가 최신 공용 상태가 아닐 수 있다.

AI Ops는 이 문제를 줄이기 위해 프로젝트별 공용 상태 기준인 `canonical_status_ref`를 사용한다.

## 언제 필요한가

- Task마다 별도 branch 또는 worktree를 쓴다.
- iOS, Android, Backend Agent가 병렬로 작업한다.
- `develop` 또는 `main`에 PR을 모아 통합한다.
- 완료된 Task 상태가 Agent 세션마다 다르게 보인다.

## 1. 기준 ref 정하기

프로젝트 운영모델이나 branch 전략에 기록한다.

```yaml
canonical_status_ref: origin/main
```

develop 통합 브랜치를 쓰면:

```yaml
canonical_status_ref: origin/develop
```

브랜치 이름은 프로젝트가 정한다. AI Ops는 `main`이나 `develop`을 강제하지 않는다.

## 2. 세션 시작 전 확인

작업 전 먼저 공용 상태 기준을 확인한다.

```bash
aiops status-ref
aiops sync-status
```

`sync-status`는 `git fetch --prune origin`을 실행하고 확인한 SHA를 출력한다. `.ai_project/`가 있으면 `.ai_project/.runtime/status_ref`에도 기록한다.

## 3. Task 상태 확인

현재 worktree의 local 상태:

```bash
aiops task status T-YYYYMMDD-001
```

공용 기준 ref의 상태:

```bash
aiops task status T-YYYYMMDD-001 --source canonical
```

두 결과가 다르면 local worktree가 아직 공용 상태에 통합되지 않았거나, 오래된 snapshot일 수 있다.

## 4. Worktree 점검

```bash
aiops worktree doctor
```

출력은 보고 전용이다. AI Ops는 worktree를 자동 삭제하지 않는다.

분류 예:

| 분류 | 의미 |
|---|---|
| `active` | 현재 작업 기준으로 유지 |
| `dirty` | 미커밋 변경이 있어 제거 금지 |
| `cleanup_candidate` | merged/clean 후보, 사용자 확인 후 정리 |
| `stale_or_diverged` | canonical ref와 갈라졌거나 뒤처짐 |

## 안전 원칙

- 현재 worktree 문서만 보고 `done`을 확정하지 않는다.
- dependency 해제는 canonical ref 기준으로 확인한다.
- dirty 또는 unpushed worktree는 자동 정리하지 않는다.
- 오래된 WIP 루트 폴더를 최신 상태 조회 기준으로 쓰지 않는다.

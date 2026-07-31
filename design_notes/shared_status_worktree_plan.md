# Shared Status / Worktree 안정화 개선 계획

작성일: 2026-07-31  
상태: Temporary Plan  
삭제 기준: 아래 단계가 구현, 검증, 문서화, 릴리즈 노트 반영까지 완료되면 삭제한다.

## 1. 배경

다중 Agent가 Git worktree를 나누어 작업할 때, 각 Agent가 자신의 로컬 worktree에 있는 `.ai_project/` 문서를 최신 공용 상태로 오인할 수 있다.

이 경우 같은 Task가 세션마다 `completion_review`, `done` 등 서로 다른 상태로 보이고, 완료된 Task를 다시 실행하거나 아직 완료되지 않은 dependency를 해제하는 문제가 생길 수 있다.

현재 AI Ops는 Task 파일을 source of truth로 정의하지만, 어느 branch/ref/worktree의 Task 파일이 공용 기준인지 강제하지 않는다.

## 2. 목표

- 프로젝트마다 다른 브랜치 전략을 허용한다.
- 단, 모든 프로젝트는 최신 공용 상태를 판단할 `canonical_status_ref`를 명시할 수 있어야 한다.
- Agent는 현재 worktree의 `.ai_project/`를 최신 공용 상태로 가정하지 않아야 한다.
- 세션 시작, Task 상태 확인, 완료 판단, handoff에 기준 ref/SHA가 남아야 한다.
- 오래된 worktree와 dirty/unpushed worktree를 구분해 정리 위험을 낮춘다.

## 3. 비목표

- 특정 브랜치 전략을 강제하지 않는다.
- `develop` 또는 `main`을 전역 기본으로 고정하지 않는다.
- Git worktree를 자동 삭제하지 않는다.
- 원격 push, merge, deploy를 자동 승인하지 않는다.
- 제품 코드의 Task 상태를 중앙 서버로 옮기지 않는다.

## 4. 핵심 개념

### canonical_status_ref

프로젝트의 최신 공용 운영 상태를 판단하는 기준 ref다.

예:

```yaml
canonical_status_ref: origin/main
canonical_status_ref: origin/develop
canonical_status_ref: origin/release/current
```

팀별 통합 기준이 다르면 프로젝트별 문서에서 team override로 기록한다.

### local worktree snapshot

각 worktree의 `.ai_project/`는 해당 branch/HEAD 시점의 스냅샷이다. Agent는 이를 최신 공용 상태로 단정하지 않는다.

### status_ref_sha

Agent가 Task 상태, dependency, handoff, completion을 판단할 때 확인한 canonical ref의 SHA다.

## 5. 권장 작업 순서

### Step 1. 정책 추가

파일:

```text
policies/shared_status_policy.md
```

내용:

- canonical status ref 정의
- local worktree snapshot 원칙
- session start sync 규칙
- Task state authority 규칙
- done/dependency 해제 기준
- worktree lifecycle 분류
- 브랜치 전략별 예시

완료 조건:

- 정책 문서가 branch 전략과 독립적인 공용 상태 기준을 설명한다.

### Step 2. 기존 정책 연결

파일:

```text
policies/README.md
policies/branch_pr_policy.md
policies/coordination_policy.md
policies/session_orchestration_policy.md
runtime/task_queue.md
runtime/role_handoff.md
```

내용:

- Task source of truth와 canonical ref 기준의 차이 명시
- 세션 시작 시 fetch/SHA 확인 원칙 연결
- worktree 문서를 최신 공용 상태로 가정 금지
- handoff에 status ref/SHA 기록
- done 확정 기준 강화

완료 조건:

- 기존 정책들이 `shared_status_policy.md`를 참조한다.

### Step 3. Schema 확장

파일:

```text
schemas/operating_model.schema.json
schemas/task.schema.json
schemas/handoff.schema.json
```

추가 후보:

```yaml
canonical_status_ref:
status_ref:
status_ref_sha:
worktree_path:
worktree_role:
base_ref:
base_sha:
```

원칙:

- 첫 패치에서는 optional로 추가한다.
- strict required는 기존 프로젝트 migration 경험을 본 뒤 결정한다.

완료 조건:

- 기존 fixture와 template가 schema 검증을 통과한다.

### Step 4. Template / Adapter 확장

파일:

```text
templates/ai_project/fast_track/operating_model.md
templates/ai_project/guided_full/operating_model.md
templates/ai_project/guided_full/branch_pr_strategy.md
templates/tasks/task.md
templates/tasks/handoff_message.md
templates/tool_adapters/codex/AGENTS.md
templates/tool_adapters/claude/CLAUDE.md
```

내용:

- operating model에 canonical status ref 기록 위치 추가
- Task template에 base/status ref 필드 추가
- handoff template에 status ref/SHA 추가
- Codex/Claude에 stale worktree 경고 추가

완료 조건:

- 새로 seed/bootstrap된 프로젝트가 canonical status ref 개념을 볼 수 있다.

### Step 5. CLI 최소 기능 추가

파일:

```text
bin/aiops
```

명령 후보:

```sh
aiops status-ref
aiops sync-status
aiops worktree doctor
aiops task status TASK_ID --source canonical
```

1차 구현 범위:

- `status-ref`: 프로젝트의 canonical ref 후보를 출력한다.
- `sync-status`: `git fetch --prune origin` 후 ref SHA를 출력한다.
- `worktree doctor`: `git worktree list --porcelain` 기반으로 dirty/stale 후보를 보고한다.
- `task status --source canonical`: canonical ref의 Task 파일 상태 조회를 시도한다.

완료 조건:

- 사용자가 세션 시작 전 공용 상태 기준을 확인할 수 있다.

### Step 6. 검증 추가

파일:

```text
scripts/test.sh
tests/
```

테스트:

- canonical ref가 없는 프로젝트에서 warning 출력
- configured canonical ref를 읽을 수 있음
- canonical ref 기준 Task 상태 조회 가능
- stale local task와 canonical task 상태 차이 감지
- worktree doctor가 dirty worktree를 제거 후보가 아닌 보존 필요로 분류

완료 조건:

- `sh scripts/test.sh`
- `bin/aiops release-check --strict --allow-pending-release`

### Step 7. 사용자 문서 반영

파일:

```text
README.md
QUICKSTART.md
CHANGELOG.md
docs/
```

내용:

- 여러 Agent/worktree 운영 시 `aiops sync-status` 먼저 실행
- 현재 worktree의 `.ai_project/`는 최신 공용 상태가 아닐 수 있음을 설명
- canonical ref 설정 예시
- 기존 프로젝트 적용 절차

완료 조건:

- 초보자가 다중 worktree 프로젝트에서 무엇을 먼저 확인해야 하는지 알 수 있다.

### Step 8. 최종 정리

작업 완료 후:

- 임시 계획 문서 삭제
- 최종 변경 요약을 CHANGELOG에 남김
- 테스트 통과
- PR/머지 준비

## 6. 예상 릴리즈 성격

권장 버전: `0.8.1` 또는 `0.9.0`

- 정책 + CLI 명령이 들어가면 `0.9.0` 후보
- 정책/문서 중심이면 `0.8.1` 후보

현재 이슈가 P0이고 CLI guard가 필요하므로 `0.9.0` 성격에 가깝다.

# 프로젝트 상태 조회

AI Ops에서 프로젝트 상태를 안정적으로 읽기 위한 기준 문서다.

## Inspect

`aiops project inspect`는 현재 프로젝트의 운영 상태를 읽기 전용으로 요약한다.

```sh
aiops project inspect
aiops project inspect --json
```

확인하는 항목:

- `.ai/` core 연결 상태와 버전
- Codex / Claude adapter 존재 여부
- `.ai_project/` 운영 모델
- 현재 Git branch와 HEAD
- `canonical_status_ref`와 기록된 status ref SHA
- 활성 Role
- Task 개수와 상태 분포

이 명령은 파일을 수정하지 않는다.

## 왜 필요한가

다중 Agent나 여러 worktree를 사용하는 프로젝트에서는 현재 폴더의 문서가 최신 공용 상태가 아닐 수 있다.

`project inspect`는 Agent가 작업 전에 현재 상태를 한 번에 확인할 수 있는 공통 입력 기반이다. 이후 `doctor`, `validate`, `context`, `health`, Dashboard 기능은 이 정규화된 상태 조회를 기준으로 확장한다.

## JSON 출력

외부 도구나 후속 자동화를 위해 JSON 출력도 제공한다.

```sh
aiops project inspect --json
```

현재 schema:

```text
aiops.project_inspect.v1
```

JSON 출력은 source of truth가 아니라, 현재 프로젝트 파일과 Git 상태를 읽어 만든 파생 결과다.

## Agent Context Contract

`aiops project context`는 Role Session이 작업을 시작하기 전에 읽을 실행 계약을 출력한다.

```sh
aiops project context --role execution
aiops project context --role execution --task T-YYYYMMDD-001
aiops project context --role execution --task T-YYYYMMDD-001 --json
```

이 명령은 파일을 수정하지 않는다. 현재 Role과 Task를 기준으로 아래 항목을 한 번에 모은다.

- 현재 프로젝트 운영 모드와 workflow 정책
- 현재 branch, HEAD, `canonical_status_ref`
- Task status, workflow, target_role, target_agent
- Task의 `allowed_paths`와 `source_of_truth`
- 현재 Role이 수행할 수 있는 다음 상태 전이
- 다음 상태의 checkpoint와 canonical publish 정책
- 승인 없이 하면 안 되는 행동
- 세션 시작 전 권장 확인 명령

Role Session은 이 출력을 기준으로 “내가 지금 이 Task를 맡아도 되는지”, “다음 상태로 어떻게 넘겨야 하는지”, “어떤 파일 밖으로 나가면 안 되는지”를 확인한다.

현재 schema:

```text
aiops.project_context.v1
```

## Project Health

`aiops project health`는 현재 프로젝트를 바로 운영해도 되는지 짧게 요약한다.

```sh
aiops project health
aiops project health --json
```

이 명령은 파일을 수정하지 않는다. `inspect`, schema, workflow catalog, canonical status ref, migration 신호를 사람이 읽기 쉬운 건강 상태로 압축한다.

주요 출력:

- `overall`: `ok`, `warning`, `blocked`
- `readiness.bootstrap`: bootstrap 완료 여부
- `readiness.task_work`: Task 작업 착수 가능 여부
- `readiness.multi_agent`: 다중 Agent/worktree 운영 준비 상태
- `readiness.migration`: 마이그레이션 필요 여부
- `checks`: `ok`, `warn`, `blocker` 단위의 상세 신호
- `next`: 다음에 실행할 추천 명령 또는 조치

현재 schema:

```text
aiops.project_health.v1
```

`health`는 빠른 판단을 위한 파생 요약이다. 실제 운영 기준은 `.ai_project/` 문서, workflow catalog, Git 상태, schema 검증 결과를 함께 확인한다.

## 관계 검증

`aiops validate project --strict`는 schema 검증 후 문서 간 관계도 함께 점검한다.

현재 관계 검증은 기존 프로젝트 호환성을 위해 `report_only`로 동작한다. 즉, 잘못된 참조는 `warn:`으로 보여주지만 아직 validate 실패로 만들지는 않는다.

점검하는 관계:

- Task의 `target_role`이 운영 모델 또는 Agent registry에 선언되어 있는가
- Task의 `target_agent`가 Agent registry에 등록되어 있는가
- Task의 `workflow`가 `.ai/workflows/` 기준에 존재하는가
- Task의 `depends_on` / `blocks`가 실제 Task를 가리키는가
- Task의 `source_of_truth`가 존재하는 로컬 파일 또는 명시적 외부 기준인가
- `canonical_status_ref`가 로컬 Git ref로 해석되는가

이 검증은 이후 단계에서 `doctor`, `context`, `health`와 연결할 수 있는 상태 정합성 기반이다.

## 상태별 증거 검증

`aiops validate project --strict`는 Task 상태별로 필요한 운영 증거도 함께 점검한다.

현재 이 검증도 기존 프로젝트 호환성을 위해 `report_only`로 동작한다. 누락된 증거는 `warn:`으로 표시하지만 아직 validate 실패로 만들지 않는다.

예시:

- `approved`: 승인자, 실행 범위, 기준 문서, 보고서 경로
- `in_progress`: lock 정보, branch/worktree/base ref, 보고서 경로
- `verification_ready`: 구현 보고서 파일, 검증 보고서 경로, status ref/SHA
- `verification_passed`: QA 보고서 파일, status ref/SHA
- `completion_review`: 구현 보고서, QA 보고서, status ref/SHA
- `done`: 완료 보고서, QA 보고서, status ref/SHA, merge/no-merge 판단 흔적
- `blocked`: blocker와 다음 의사결정

이 검증의 목적은 Agent가 현재 Task 상태를 믿어도 되는지 판단할 근거를 늘리는 것이다. strict 실패 기준으로 올리는 것은 마이그레이션 지원 이후 별도 승인으로 진행한다.

## 상태 전이 보호

`canonical_status_ref`가 있는 프로젝트에서는 `aiops task transition`도 canonical 기준을 확인한다.

전이 전에 확인하는 내용:

- 현재 canonical ref가 로컬에서 해석되는가
- Task에 기록된 `status_ref_sha`가 현재 canonical SHA와 같은가
- `status_ref_sha`가 없다면 로컬 Task 상태와 canonical Task 상태가 같은가

불일치가 있으면 오래된 worktree 상태로 판단하고 전이를 차단한다. 전이가 허용되면 Task에 현재 `status_ref`, `status_ref_sha`, `base_ref`, `base_sha`를 기록한다.

이 보호장치는 다중 worktree 환경에서 이미 완료된 Task를 다시 완료 처리하거나, 오래된 dependency 상태를 기준으로 작업을 진행하는 문제를 줄이기 위한 것이다.

## Workflow Catalog와 Checkpoint

`runtime/workflows.json`은 workflow 상태와 checkpoint 정책을 기계가 읽을 수 있게 정리한 catalog다.

Task 상태 전이 후 `aiops task transition`은 catalog를 읽어 아래 정보를 출력한다.

- `workflow`
- `checkpoint`
- `canonical_publish`
- `status_meaning`
- `checkpoint_note`

`checkpoint: true`는 다른 Agent가 이어받거나 dependency 판단에 영향을 줄 수 있는 상태라는 뜻이다. 이 상태는 프로젝트가 설정한 `canonical_status_ref`에 반영하는 것이 권장되거나 필요할 수 있다.

`canonical_publish` 의미:

- `not_required`: 로컬 또는 task branch 상태로 충분
- `optional`: 필요하면 canonical에 반영
- `recommended`: 다음 Agent 인계를 위해 canonical 반영 권장
- `required`: 다른 Agent가 의존하기 전 canonical 반영 필요

브랜치 이름은 고정하지 않는다. `origin/develop`이 아니라 프로젝트별 `canonical_status_ref`가 기준이다.

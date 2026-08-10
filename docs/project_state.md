# 프로젝트 상태 조회

AI Ops에서 프로젝트 상태를 안정적으로 읽기 위한 기준 문서다.

## Project Snapshot

`aiops project snapshot --json`은 Agent가 세션 시작 또는 작업 착수 전에 먼저 읽는 기계 판독 상태 계약이다.

```sh
aiops project snapshot --json
```

이 명령은 파일을 수정하지 않는다. `.ai_project`가 없는 프로젝트나 Git 저장소가 아닌 폴더에서도 실패하지 않고, 현재 가능한 범위의 상태와 blocker를 JSON으로 출력한다.

현재 schema:

```text
aiops.project_snapshot.v1
```

주요 출력:

- `source_refs`: local branch/head, `canonical_status_ref`, 기록된 status ref SHA, 동기화 상태
- `core`: `.ai/` core 연결과 Codex/Claude adapter 상태
- `project`: 운영 모드, workflow 정책, 기록된 core version
- `agents`: 등록 Agent와 활성 Role
- `tasks`: Task 개수, 활성 Task, 상태 분포, Task별 routing 정보
- `workflow`: workflow catalog 연결 상태
- `health`: `ok`, `warning`, `blocked` 요약
- `control`: Agent가 시작/상태전이/commit/push/merge를 해도 되는지에 대한 통제 신호
- `checks`: severity, confidence, evidence를 포함한 판단 근거
- `next`: Agent용 command와 사용자용 message로 분리된 다음 조치

`snapshot`은 source of truth가 아니다. `.ai_project/`, workflow catalog, Git 상태를 읽어 만든 projection이다. 사용자용 monitor나 dashboard도 이 snapshot 또는 같은 상태 계약을 읽어야 한다.

## Dashboard

`aiops project dashboard`는 snapshot 기반 상태를 사람이 읽기 쉬운 한 화면으로 보여준다.

사용자가 자주 보는 화면은 짧은 top-level 명령으로도 실행할 수 있다.

```sh
aiops status
aiops work
aiops risks
aiops agents
aiops release
```

이 명령들은 기존 dashboard projection을 다시 계산하되, 터미널에서는 한국어 라벨, 색상, 진행률, 요약 section을 적용한 사용자용 화면으로 표시한다.

| 사용자용 명령 | 표시 목적 |
|---|---|
| `aiops status` | 프로젝트 상태, 진행률, 운영 readiness, 주의 항목 |
| `aiops work` | 현재 일감, 상태별 요약, 담당 역할/에이전트, 다음 조치 |
| `aiops risks` | 차단/주의 항목, 공용 기준 상태, 메타데이터 누락, 에이전트 drift |
| `aiops agents` | 에이전트 활성 상태, 팀, 역할, 담당 일감 수 |
| `aiops release` | 출시 전 readiness, 공용 기준 상태, 차단 항목, release-check 명령 |

세부 view, JSON, Mermaid, HTML 출력이 필요하면 아래 고급 명령을 사용한다.

사용자용 명령은 각 명령의 의미를 바꾸는 `--view`, `--map`, `--output`, `--json` 같은 고급 dashboard 옵션을 받지 않는다. `aiops work`만 터미널 표시 방식 선택을 위해 `--format terminal|tree`를 허용한다.

```sh
aiops project dashboard
aiops project dashboard --level compact
aiops project dashboard --level detail
aiops project dashboard --view work
aiops project dashboard --view risk
aiops project dashboard --view agents
aiops project dashboard --view release
aiops project dashboard --format html --map summary --output dashboard.html
aiops project dashboard --format html --map swimlane --group-by agent --output dashboard.html
aiops project dashboard --format html --map dependencies --focus T-20260805-007 --depth 2 --output dashboard.html
aiops project dashboard --format html --filter-status approved,scoped --filter-agent "iOS Agent" --output dashboard.html
aiops project dashboard --view work --format tree
aiops project dashboard --view work --format mermaid --map summary
aiops project dashboard --view work --format mermaid --map dependencies
aiops project dashboard --view work --format mermaid --map dependencies --focus T-20260805-007 --depth 2
aiops project dashboard --view work --format mermaid --map swimlane --group-by agent
aiops project dashboard --view work --format mermaid --map critical-path
aiops project dashboard --view work --format mermaid --map workflow
aiops project dashboard --view work --format mermaid --map agents
aiops project dashboard --view work --format mermaid --map blockers
aiops project dashboard --format html --output dashboard.html
aiops project dashboard --json
aiops project dashboard --color always
```

현재 dashboard 구현은 사용자용 CLI 화면, Main Dashboard, Work Dashboard terminal/tree, Work Mermaid map, static HTML dashboard, Dashboard JSON contract, Risk/Agent/Release 전문 view를 제공한다.

사용자용 top-level 명령은 파일을 수정하지 않으며, 실행할 때마다 `project snapshot --json`과 `project health --json`을 다시 계산한 현재 projection을 표시한다. 사용자용 terminal 출력은 사람이 읽기 쉬운 표시층이므로 자동화 입력으로 쓰지 않는다. Agent와 자동화가 읽어야 하는 기계 계약은 여전히 `aiops project snapshot --json`, `aiops project health --json`, `aiops project dashboard --json`이다.

사용자용 help는 자주 쓰는 명령을 먼저 보여준다.

```sh
aiops help
aiops help work
aiops help dashboard
aiops help ai
aiops help all
```

기본 `aiops help`는 `project snapshot --json` 같은 Agent/자동화용 명령을 숨긴다. 기계 계약 명령은 `aiops help ai`, 전체 명령 목록은 `aiops help all`에서 확인한다. 도움말 문구는 기본 한국어이며 `AIOPS_LOCALE=en` 또는 `--locale en`으로 영어 표시를 선택할 수 있다.

Main Dashboard 표시 항목은 프로젝트 진행률, readiness, canonical status sync, 운영 설정, Agent/Role 요약, blocker/warning, next command다.

Work Dashboard 표시 항목은 활성 일감, status, workflow, target role, target agent, lock, 다음 Role Session 후보, detail 레벨의 allowed_paths/source_of_truth다.

Risk Dashboard 표시 항목은 blocker/warning, policy rule, canonical sync, unresolved decisions, Task metadata/status_ref 누락, Agent drift, blocked action, 승인 필요 action이다.

Agent Dashboard 표시 항목은 Agent status/team/role/capability/current task/branch/worktree/drift와 Agent별 활성 Task 배정이다.

Release Dashboard 표시 항목은 release 전 readiness, canonical status, blocker/warning, policy rule, blocked action, required approval, release-check 실행 명령이다. 이 view는 실제 CI나 GitHub required check 결과를 대체하지 않는다.

지원 범위:

- `--view main|work|risk|agents|release`
- `--level compact|standard|detail`
- `--format terminal|tree|mermaid|html`
- `--map summary|dependencies|swimlane|critical-path|workflow|agents|blockers`
- `--focus TASK_ID`
- `--depth N`
- `--group-by area|agent|role|status|workflow`
- `--filter-status STATUS,...` (HTML 초기 필터)
- `--filter-agent AGENT` (HTML 초기 필터)
- `--filter-role ROLE` (HTML 초기 필터)
- `--filter-workflow WORKFLOW` (HTML 초기 필터)
- `--output FILE`
- `--json`
- `--color auto|always|never`
- `--no-color`

`--format mermaid`는 현재 `--view work`에서만 지원하며, 터미널에는 렌더링된 그림이 아니라 Mermaid source text를 출력한다. summary map은 Task를 영역 단위로 접은 요약, dependency map은 `depends_on`/`blocks`, swimlane map은 `--group-by` 기준 활성 일감 보드, critical-path map은 출시/목표 Task 중심 선행 경로, workflow map은 표준 상태 흐름, agents map은 target_agent/target_role, blockers map은 health warning/blocker를 Mermaid `flowchart`로 출력한다.

`--format html --output dashboard.html`은 같은 dashboard projection과 Mermaid source를 정적 HTML로 감싸 브라우저에서 시각적으로 볼 수 있게 만든다. HTML은 Mermaid CDN module을 사용해 diagram을 렌더링하며, 각 diagram 아래에는 원본 Mermaid source도 함께 접어 둔다. HTML dashboard에는 한국어 안내, 상태 색상 범례, Agent 상태 색상, map별 접기/펼치기, diagram 확대/축소 버튼이 포함된다. 상태, Role, Team, Agent 표시명, workflow, capability 같은 기계 판독 값은 HTML 표시에서 locale label catalog를 거쳐 사용자가 읽기 쉬운 라벨로 치환한다. 기본 catalog는 `ko`이며, 미등록 값은 원본 의미를 잃지 않도록 사람이 읽을 수 있는 fallback으로 표시한다. HTML에서 `--map`을 지정하지 않으면 큰 dependency graph 대신 `summary` map을 먼저 연다.

HTML의 `일감 탐색` 패널은 브라우저 안에서 ID/제목 검색, 상태 toggle, 담당자/역할/workflow 필터, 중심 일감과 연결 깊이 1~4단계 선택을 제공한다. 필터는 작업 표와 dependency map에 함께 적용되며, 결과가 큰 경우 중심 일감으로 범위를 줄이라는 안내를 표시한다. 필터용 task/edge 데이터는 생성된 HTML 안에서만 사용하고 target project나 dashboard JSON projection을 수정하지 않는다. `--filter-*` 옵션은 HTML이 처음 열릴 때 적용할 필터를 지정하며 다른 format과 함께 사용하면 오류가 난다.

중심 일감은 dependency 연결 범위만 제한하며 상태·담당자·역할·workflow·검색 필터를 우회하지 않는다. `--filter-agent`, `--filter-role`, `--filter-workflow`에 현재 일감 데이터에 없는 값을 지정하면 전체 선택으로 조용히 전환하지 않고 오류로 종료한다. Agent 필터에는 locale 설명이 아니라 프로젝트에 등록된 고유 이름을 표시한다.

큰 프로젝트에서는 전체 dependency map보다 아래 형태가 더 읽기 쉽다.

```sh
aiops project dashboard --format html --map summary --output dashboard.html
aiops project dashboard --format html --map swimlane --group-by agent --output dashboard.html
aiops project dashboard --format html --map dependencies --focus TASK_ID --depth 2 --output dashboard.html
aiops project dashboard --format html --filter-status approved,scoped --filter-role "Execution Role" --output dashboard.html
```

`--json`은 `aiops.project_dashboard.v1` 계약을 출력한다. 이 계약은 project/health/snapshot 값을 dashboard 용도에 맞게 projection한 결과이며, terminal/tree/Mermaid와 같은 의미를 공유한다. 주요 필드는 status, progress, readiness, git, agents, tasks, risks, control, next, maps, views다.

이 명령은 파일을 수정하지 않는다. Dashboard 출력은 source of truth가 아니며, Agent의 기계 판정 기준은 `project snapshot --json`의 `control`, `checks`, `source_refs`를 우선한다.

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

`project inspect`는 사람이 읽기 쉬운 상세 점검에 가깝다. Agent가 가장 먼저 읽어야 하는 표준 상태 계약은 `project snapshot --json`이다.

`inspect`, `context`, `health`는 snapshot과 같은 핵심 의미를 사용해야 한다. 특히 아래 값은 서로 충돌하면 안 된다.

- 프로젝트 이름, 운영 모드, workflow 정책
- Git branch/head
- `canonical_status_ref`와 status ref 상태
- Task 상태 분포
- health overall

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

작업 전 권장 순서는 snapshot을 먼저 읽고, 이후 Role/Task별 context를 확인하는 방식이다.

```sh
aiops project snapshot --json
aiops project context --role execution --task T-YYYYMMDD-001 --json
```

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

`health`는 빠른 판단을 위한 파생 요약이다. Agent 통제 기준은 `project snapshot --json`의 `control`, `checks`, `source_refs`를 우선 확인한다.

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

## Policy Rules

`runtime/policy_rules.json`은 snapshot, health, validate가 사용하는 운영 판단 규칙을 데이터화하기 위한 catalog다.

```sh
aiops validate policy-rules
aiops policy evaluate --target . --json
aiops policy evaluate --snapshot /tmp/project_snapshot.json --json
```

`aiops policy evaluate`는 project snapshot에 policy rule을 적용해 어떤 규칙이 match되었는지 출력한다. 출력 schema는 아래와 같다.

```text
aiops.policy_evaluation.v1
```

현재 evaluator가 처리하는 조건은 intentionally small이다.

- `key: value` exact match
- `key: null`
- `key: [a, b]` 중 하나와 일치
- `checks.some_check_id: "present"`

`project snapshot --json`은 `policy` 필드에 같은 평가 결과 요약을 포함한다. 이 값은 source of truth가 아니라 snapshot과 policy catalog를 읽어 만든 projection이다.

초기 단계에서는 기존 snapshot/health 계산을 한 번에 모두 교체하지 않는다. 대신 policy result와 기존 `checks`, `health`, `control`이 충돌하지 않도록 연결한다.

## Action Plan

`aiops action plan`은 Agent가 작업을 시작하기 전에 의도한 행동을 구조화해 확인하는 계약이다.

```sh
aiops action plan --role execution --task T-YYYYMMDD-001 --json
aiops action validate /tmp/action_plan.json
```

Action plan은 source of truth가 아니다. Task, project context, Git/canonical 상태를 읽어 만든 작업 전 검토 결과다.

주요 목적:

- 현재 Role과 Task가 맞는지 확인
- `allowed_paths` 밖 수정 의도가 있는지 확인
- `task_transition`, `task_lock`, `task_unlock`, `create_handoff` 같은 운영 상태 변경 의도를 구조화
- `commit`, `push`, `create_pr`, `merge`, `deploy`, `external_configuration_changes`가 사용자 승인 필요 행동으로 표시되는지 확인
- stale canonical 상태에서 Task 상태 전이 의도가 차단되는지 확인

이 명령은 실제 파일 수정, 상태 전이, lock 변경, handoff 생성, commit, push, PR, merge, deploy, 외부 설정 변경을 수행하지 않는다.

# Agent Intent Handling

AI Ops CLI는 사용자가 직접 모든 명령을 외워 실행하기 위한 인터페이스라기보다, Agent가 프로젝트 상태를 정확히 읽기 위한 운영 도구다.

사용자는 보통 자연어로 요청한다.

```text
AI Ops 상태 점검해줘.
다음에 뭘 하면 돼?
이 Task를 개발 에이전트에게 넘겨도 돼?
기존 프로젝트를 새 AI Ops 기준으로 업데이트해줘.
worktree 상태가 이상한 것 같아.
```

Agent는 이 요청을 CLI 명령에 기계적으로 1:1 매핑하지 않는다. 먼저 의도를 파악하고, 가장 작은 읽기 전용 명령부터 실행한다.

## 기본 원칙

- 먼저 읽기 전용 명령으로 현재 상태를 확인한다.
- 사용자의 질문에 답하기 위해 필요한 최소 범위만 조회한다.
- 같은 정보를 방금 확인했다면 불필요하게 같은 명령을 반복하지 않는다.
- 파일 수정, 상태 전이, handoff 생성, commit, push, PR, merge, deploy처럼 프로젝트 상태나 소스에 영향을 주는 행동 전에는 action plan을 생성해 의도한 행동, 승인 필요 항목, 차단 항목을 확인한다.
- 상태 전이, 파일 수정, 마이그레이션 적용, commit, push, PR, merge, deploy는 사용자 승인 후 진행한다.
- CLI 출력은 사용자에게 그대로 던지지 않고, 사람이 이해하기 쉬운 판단과 다음 조치로 요약한다.
- 프로젝트마다 branch/PR/worktree 전략이 다를 수 있으므로 `origin/develop` 같은 이름을 고정 가정하지 않는다.

## Intent별 권장 조회

| 사용자 의도 | 우선 고려할 읽기 전용 명령 | 사용 시점 |
|---|---|---|
| 운영 상태 계약 확인 | `aiops project snapshot --json` | Agent가 현재 상태와 통제 신호를 먼저 읽어야 할 때 |
| 운영 상태 점검 | `aiops project health` | 사람이 읽을 빠른 운영 가능 여부가 필요할 때 |
| 상세 상태 확인 | `aiops project inspect` | 현재 운영 모델, Task 분포, Git 상태를 자세히 봐야 할 때 |
| Role Session 시작 | `aiops project context --role ROLE` | 특정 Role이 지금 무엇을 할 수 있는지 확인할 때 |
| Task 시작 가능 여부 | `aiops project context --role ROLE --task TASK_ID` | Task의 상태, 허용 경로, 다음 전이를 확인할 때 |
| 작업 전 의도 검토 | `aiops action plan --role ROLE --task TASK_ID --intends ACTIONS --paths PATHS --json` | Agent가 실제 수정, 상태 전이, handoff, commit/push/merge/deploy 전에 의도한 행동과 승인/차단 항목을 구조화해야 할 때 |
| 구성 정합성 점검 | `aiops validate project --strict` | schema와 문서 간 관계를 확인할 때 |
| 기존 프로젝트 업데이트 | `aiops migrate --plan` | 적용 전 영향 범위를 설명해야 할 때 |
| 다중 worktree 상태 이상 | `aiops status-ref`, `aiops sync-status`, `aiops worktree doctor` | 공용 상태 기준과 로컬 worktree 상태가 의심될 때 |
| 최신 공용 Task 상태 확인 | `aiops task status TASK_ID --source canonical` | 로컬 Task 문서가 오래됐을 수 있을 때 |

이 표는 강제 매핑이 아니다. Agent는 요청 맥락, 최근 실행 결과, 현재 Role, Task 상태를 기준으로 필요한 명령만 선택한다.

Agent가 작업 착수 가능 여부, 상태 전이 가능 여부, 승인 필요 행동을 판단해야 한다면 `project snapshot --json`의 `control`, `checks`, `source_refs`를 먼저 확인한다.

## Action Plan 사용 기준

Action Plan은 사용자가 직접 매번 입력해야 하는 명령이 아니라, Agent가 실제 행동 전에 스스로 실행해 확인해야 하는 의도 검토 계약이다.

아래 행동이 포함되면 Agent는 작업 전에 `aiops action plan`을 생성한다.

- 제품 코드 또는 운영 문서 파일 수정
- Task 상태 전이 또는 lock 변경
- handoff 생성 또는 다음 Role 인계
- commit, push, PR, merge, deploy
- 외부 서비스 설정 변경

Action Plan 결과에 `blocked_actions`가 있으면 해당 행동을 진행하지 않는다. Agent는 blocker의 이유와 evidence를 사용자에게 요약하고, 필요한 사용자 결정 또는 선행 조치를 요청한다.

Action Plan 결과에 `requires_user_approval`이 있으면 승인 전에는 해당 행동을 실행하지 않는다. 특히 `commit`, `push`, `merge`, `deploy`, `external_configuration_changes`는 Action Plan이 있더라도 사용자 승인 없이 진행하지 않는다.

예:

```text
aiops action plan \
  --role "Execution Role" \
  --task T-YYYYMMDD-001 \
  --intends edit_paths,run_tests,task_transition \
  --paths src/LoginView.swift \
  --json
```

## 응답 방식

Agent는 CLI 결과를 아래처럼 요약한다.

```text
현재 운영 상태는 warning입니다.

- bootstrap은 완료되어 있습니다.
- Task 작업은 가능하지만 canonical status ref 동기화가 필요합니다.
- 현재 worktree의 기준 SHA가 최신 공용 상태와 다를 수 있습니다.

다음 조치:
1. aiops sync-status로 공용 상태 기준을 기록
2. T-001은 Execution Role 세션으로 진행 가능
3. 상태 전이 또는 commit은 사용자 승인 후 진행
```

## 수정이 필요한 요청

사용자가 아래와 같은 요청을 하면 Agent는 먼저 영향 범위를 설명하고 승인 지점을 분리한다.

- `.ai_project` 생성 또는 수정
- Task 상태 전이
- handoff 생성
- migration apply
- 제품 코드 수정
- commit, push, PR, merge, deploy
- `.ai/` core 문서 수정

특히 `.ai/` core는 운영자 승인 없이 수정하지 않는다. 일반 프로젝트별 결정과 진행 상태는 `.ai_project/`에 남긴다.

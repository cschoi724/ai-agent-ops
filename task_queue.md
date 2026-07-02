# Task Queue Policy

작성일: 2026-06-29  
상태: Draft v1  
범위: `.ai_project/tasks/` 기반 Agent 작업 큐 운영 기준

## 1. 목적

이 문서는 Agent들이 복사/붙여넣기 지시에 의존하지 않고, 공유 작업 큐를 통해 자기 작업을 찾고 실행하는 기준을 정의한다.

`.ai_project/tasks/`의 Task 파일은 Agent 실행 지시의 source of truth다. `.ai_project/task_board.md`는 현황 요약판이며, `reports/`, `qa/`는 Task 진행 과정의 보조 기록이다.

## 2. 기본 원칙

- PM Agent는 사용자 승인 없이 실행 가능한 Task를 만들지 않는다.
- Development Agent와 QA Agent는 세션 시작 또는 재개 시 `.ai_project/current_context.md`와 `.ai_project/tasks/`를 확인한다.
- Agent는 `target_agent`가 자신과 맞는 Task만 처리한다.
- `target_agent`가 명시되어 있으면 `target_agent`가 `required_capabilities`보다 우선한다.
- `target_agent`가 현재 Agent와 다르면 승인 상태와 capability 일치 여부와 관계없이 실행하지 않는다.
- `required_capabilities`는 `target_agent`가 현재 Agent와 일치한 뒤 추가 조건으로 확인한다. `target_agent`가 비어 있거나 `any`인 경우에만 capability 기준으로 라우팅한다.
- 실행 가능한 Task는 `status: approved` 또는 `status: ready_for_qa`처럼 명확한 상태를 가져야 한다.
- 실행 가능한 Task는 `approved_by`가 비어 있지 않아야 한다.
- Task는 `depends_on`이 모두 완료된 경우에만 실행한다.
- Agent는 잠금 필드가 비어 있는 Task만 시작할 수 있다.
- Agent는 Task를 시작하기 전 상태를 갱신하고, 완료 후 보고서 경로를 Task 파일에 기록한다.
- 동시에 여러 Task를 병렬 실행하지 않는다. 같은 Agent는 하나의 `in_progress` Task만 가진다.

## 3. Task 상태값

| 상태 | 의미 | 주 담당 |
|---|---|---|
| `proposed` | PM Agent가 후보로 제안 | PM Agent |
| `approved` | 사용자가 진행 승인 | PM Agent |
| `in_progress` | 담당 Agent가 작업 중 | Development Agent 또는 QA Agent |
| `ready_for_qa` | 개발 완료 후 QA 대기 | Development Agent |
| `qa_in_progress` | QA Agent 검증 중 | QA Agent |
| `qa_passed` | QA 통과 후 PM Agent 완료 확정 대기 | PM Agent |
| `rework_requested` | QA 결과 재작업 필요 | QA Agent / PM Agent |
| `blocked` | 외부 요인으로 차단 | 담당 Agent |
| `done` | PM Agent가 완료 확정 | PM Agent |
| `cancelled` | 사용자 또는 PM Agent가 취소 | PM Agent |

## 4. 허용 상태 전이

Agent는 아래 상태 전이만 수행한다. 이 표에 없는 전이는 PM Agent가 사용자 확인 후 처리한다.

| 현재 상태 | 다음 상태 | 수행 주체 | 조건 |
|---|---|---|---|
| `proposed` | `approved` | PM Agent | 사용자 승인 완료 |
| `approved` | `in_progress` | Development Agent | 실행 가능 조건 충족, lock 획득 |
| `in_progress` | `ready_for_qa` | Development Agent | 개발 보고 작성 완료 |
| `ready_for_qa` | `qa_in_progress` | QA Agent | QA 가능 조건 충족, lock 획득 |
| `qa_in_progress` | `qa_passed` | QA Agent | `PASS` 또는 `PASS_WITH_RISK` QA 보고 작성 완료, lock 해제 |
| `qa_passed` | `done` | PM Agent | QA 통과 결과 검토 후 PM 확정 |
| `qa_in_progress` | `rework_requested` | QA Agent / PM Agent | 수정 필요 |
| `qa_passed` | `rework_requested` | PM Agent | PM 검토 중 수정 필요 확인 |
| `rework_requested` | `approved` | PM Agent | 재작업 범위 확정 및 사용자 승인 |
| `blocked` | `approved` | PM Agent | 차단 해소 및 사용자 승인 |
| `approved` | `blocked` | 담당 Agent | 외부 차단 발견 |
| `in_progress` | `blocked` | 담당 Agent | 외부 차단 발견 |
| `ready_for_qa` | `blocked` | QA Agent | QA 차단 발견 |
| `proposed` | `cancelled` | PM Agent | 사용자 또는 PM 취소 |
| `approved` | `cancelled` | PM Agent | 사용자 또는 PM 취소 |
| `blocked` | `cancelled` | PM Agent | 사용자 또는 PM 취소 |

## 5. 실행 가능 조건

Development Agent가 Task를 실행하려면 아래 조건을 모두 만족해야 한다.

- `status: approved`
- `approved_by`가 비어 있지 않음
- `target_agent: Development Agent`
- `required_capabilities`가 Development Agent의 capability와 일치
- `allowed_paths`가 명시됨
- `depends_on`에 있는 Task가 모두 `done`
- `locked_by`가 비어 있음

QA Agent가 Task를 실행하려면 아래 조건을 모두 만족해야 한다.

- `status: ready_for_qa`
- `target_agent: QA Agent`
- `required_capabilities`가 QA Agent의 capability와 일치
- 개발 보고서가 `report_to` 경로에 존재함
- `depends_on`에 있는 Task가 모두 `done`
- `locked_by`가 비어 있음

`target_agent`가 비어 있거나 `any`인 Task는 예외적으로 `required_capabilities` 기준으로 담당 Agent를 판단할 수 있다. 이 경우에도 담당 Agent가 애매하면 실행하지 않고 PM Agent에게 라우팅 확인을 요청한다.

PM Agent가 `approved` 상태로 변경하려면 아래 조건을 확인한다.

- 사용자 승인 또는 Product Owner 승인 기록이 있음
- 작업 범위와 제외 범위가 명확함
- `allowed_paths`와 `source_of_truth`가 명시됨
- 필요한 경우 `depends_on`이 명시됨

## 6. 잠금 규칙

Agent는 Task를 시작하기 전에 아래 필드를 갱신한다.

```yaml
locked_by: Development Agent
locked_at: YYYY-MM-DDTHH:mm:ss+09:00
lock_session: ios-dev-session
```

잠금 규칙:

- `locked_by`가 비어 있지 않으면 다른 Agent는 실행하지 않는다.
- 같은 Agent라도 이미 `in_progress` 또는 `qa_in_progress` Task가 있으면 새 Task를 시작하지 않는다.
- 작업을 정상 완료하면 다음 상태로 넘기면서 lock을 비운다.
- Agent 세션이 중단되어 lock이 오래 남으면 PM Agent가 사용자 확인 후 lock을 해제한다.
- lock 해제 사유는 Task 변경 이력에 기록한다.

권장 stale lock 기준:

```yaml
lock_timeout_minutes: 240
```

## 7. 우선순위와 의존성

Task 선택 순서:

1. `priority`가 높은 Task
2. `depends_on`이 모두 `done`인 Task
3. `created_at`이 오래된 Task
4. `id`가 앞선 Task

권장 priority 값:

| 값 | 의미 |
|---|---|
| `P0` | 즉시 처리, 차단/장애/긴급 |
| `P1` | 현재 우선 작업 |
| `P2` | 일반 작업 |
| `P3` | 낮은 우선순위 |

`depends_on`은 Task ID 배열로 기록한다.

```yaml
depends_on:
  - T-YYYYMMDD-001
```

## 8. 새 요구사항 우선순위 조정

새 요구사항이 들어오면 PM Agent는 기존 Task Queue를 먼저 확인하고 priority와 의존성을 제안한다.

확인 대상:

- `proposed` Task
- `approved` Task
- `in_progress` Task
- `blocked` Task
- 기존 `depends_on`

규칙:

- 새 요구사항은 기본적으로 `proposed` Task 후보로 정리한다.
- 기존 Task의 `priority`, `depends_on`, 진행 순서를 바꾸기 전에는 사용자 승인을 받는다.
- `in_progress` Task는 자동으로 중단하거나 밀어내지 않는다.
- 새 요구사항이 릴리즈 차단, 장애, 정책 리스크, 보안/개인정보 리스크를 만들면 PM Agent가 우선순위 상승을 제안할 수 있다.
- PM Agent는 우선순위 변경 이유와 기존 Queue 영향을 함께 보고한다.
- Development Agent와 QA Agent는 PM Agent가 승인한 상태와 priority 기준으로만 실행한다.

## 9. Task 파일 위치

Task 파일은 아래 형식을 권장한다.

```text
.ai_project/tasks/T-YYYYMMDD-001_task-slug.md
```

예:

```text
.ai_project/tasks/T-20260629-001_ai-agent-ops-migration.md
```

## 10. Task 메타데이터

Task 파일 상단에는 YAML front matter를 둔다.

생성 직후 `proposed` Task 예시:

```yaml
---
id: T-YYYYMMDD-001
title: Task title
status: proposed
type: feature | bugfix | docs | release | ops
priority: P1
priority_reason: Current priority rationale
target_agent: Development Agent
required_capabilities:
  - implementation
depends_on: []
allowed_paths:
  - ios/ippeo/
source_of_truth:
  - ios/ippeo/Docs/CURRENT_STATUS.md
created_by: PM Agent
approved_by:
locked_by:
locked_at:
lock_session:
lock_timeout_minutes: 240
created_at: YYYY-MM-DD
updated_at: YYYY-MM-DD
report_to: .ai_project/reports/T-YYYYMMDD-001_dev-report.md
qa_to: .ai_project/qa/T-YYYYMMDD-001_qa-report.md
---
```

PM Agent가 사용자 또는 Product Owner 승인을 확인하면 `status: approved`와 `approved_by: Product Owner`를 함께 갱신한다. Development Agent는 `approved_by`가 비어 있는 Task를 실행하지 않는다.

## 11. Agent별 Queue 확인 규칙

PM Agent:

1. `proposed`, `blocked`, `rework_requested`, `ready_for_qa`, `qa_passed` Task를 확인한다.
2. 사용자 승인이 필요한 Task는 `approved`로 바꾸기 전에 확인을 받는다.
3. `task_board.md`를 Task 상태 요약으로 갱신한다.
4. 다음 작업을 안내할 때 Task ID, status, `target_agent`, `required_capabilities`, 열 세션, 사용자 요청을 함께 표시한다.

Development Agent:

1. `target_agent: Development Agent`인 `approved` Task를 찾는다.
2. `target_agent`가 다른 Agent면 실행하지 않는다.
3. 우선순위와 의존성 기준으로 하나만 선택한다.
4. 작업 시작 전 lock을 획득하고 Task 상태를 `in_progress`로 바꾼다.
5. 완료 후 개발 보고서를 `reports/`에 작성하고 Task 상태를 `ready_for_qa`로 바꾸며 lock을 비운다.

QA Agent:

1. `target_agent: QA Agent`인 `ready_for_qa` Task를 찾는다.
2. `target_agent`가 다른 Agent면 실행하지 않는다.
3. 우선순위와 의존성 기준으로 하나만 선택한다.
4. 검증 시작 전 lock을 획득하고 Task 상태를 `qa_in_progress`로 바꾼다.
5. 검증 결과에 따라 QA 보고서를 `qa/`에 작성한다.
6. 결과가 `PASS` 또는 `PASS_WITH_RISK`면 Task 상태를 `qa_passed`로 바꾸고 PM Agent의 완료 확정을 기다린다.
7. 결과가 `FAIL`이면 `rework_requested`, `BLOCKED`면 `blocked`로 갱신한다.
8. 완료 또는 차단 처리 시 lock을 비운다.

## 12. Target Agent Hard Stop

`target_agent`는 Task 실행 권한의 최우선 라우팅 필드다.

규칙:

- `target_agent`가 현재 Agent와 다르면 실행하지 않는다.
- `status: approved`여도 `target_agent`가 다르면 실행하지 않는다.
- `required_capabilities`가 일부 일치해도 `target_agent` 불일치를 덮어쓸 수 없다.
- `target_agent`가 비어 있거나 `any`인 경우에만 `required_capabilities`로 담당 Agent를 판단한다.
- 담당 Agent가 애매하면 실행하지 않고 PM Agent에게 라우팅 확인을 요청한다.

예:

```yaml
target_agent: QA Agent
required_capabilities:
  - release_check
```

위 Task는 QA Agent만 실행한다. Development Agent가 `release_check`와 관련된 검증을 수행할 수 있더라도 이 Task를 실행하지 않는다.

## 13. 충돌 처리

- Task 파일과 `task_board.md`가 다르면 Task 파일을 우선한다.
- Task 파일과 report/QA 문서가 다르면 Task 파일을 우선한다.
- Task 파일과 프로젝트 기술 문서가 다르면 `.ai_project/source_of_truth.md`에 지정된 프로젝트 문서를 확인한다.
- Task 상태 변경이 애매하면 PM Agent가 사용자에게 확인한다.
- lock 상태가 애매하면 PM Agent가 사용자 확인 후 해제 또는 유지한다.

## 14. 변경 이력

| 날짜 | 변경 내용 |
|---|---|
| 2026-06-29 | Task Queue 정책 v1 작성 |
| 2026-06-29 | 상태 전이, 실행 가능 조건, lock, priority, dependency 규칙 추가 |
| 2026-06-29 | QA 통과 후 PM 확정 대기 상태 `qa_passed` 추가 |
| 2026-06-29 | 생성 직후 Task의 `approved_by` 기본값 기준 명확화 |
| 2026-07-01 | `target_agent` 불일치 hard stop 규칙 추가 |
| 2026-07-01 | 새 요구사항 우선순위 조정 규칙 추가 |
| 2026-07-02 | PM Agent 다음 작업 안내에 담당 Agent 표시 기준 추가 |

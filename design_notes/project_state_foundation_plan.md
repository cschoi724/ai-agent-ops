# 프로젝트 상태 안정화 기반 개선 계획

상태: 계획 문서
대상 후보 버전: v0.10.0
담당: AI Ops 운영자

이 문서는 다음 개선 단계에서 진행할 작업 순서를 정리한다. 목표는 AI Agent가 프로젝트 상태를 더 정확하고 안정적으로 읽을 수 있는 기반을 만드는 것이다.

이번 단계의 목표는 시각화가 아니다. 먼저 상태 해석 기반을 안정화하고, 그 다음 버전에서 Dashboard 같은 사용자용 시각화를 검토한다.

## 목표

AI Ops가 아래 질문에 일관되게 답할 수 있게 만든다.

- 현재 프로젝트의 기준 상태는 무엇인가?
- 어떤 Task 상태가 최신 공용 상태인가?
- 현재 worktree가 공용 브랜치보다 오래된 상태인가?
- 지금 어떤 Role이 다음 행동을 할 수 있는가?
- 작업 전에 반드시 읽어야 할 파일과 결정사항은 무엇인가?
- 현재 프로젝트 구성이 작업을 진행해도 될 만큼 유효한가?

## 이번 단계에서 하지 않을 것

- Dashboard나 HTML 시각화는 만들지 않는다.
- 운영모델 전체를 다시 설계하지 않는다.
- 기존 프로젝트가 모든 문서를 즉시 다시 작성하도록 강제하지 않는다.
- 마이그레이션 없이 기존 프로젝트를 깨는 strict 검사를 추가하지 않는다.
- 별도 승인 없이 push, merge, release를 진행하지 않는다.

## 설계 방향

AI Ops의 강점은 특정 Agent 도구에 종속되지 않고, 프로젝트 저장소 안에 운영 상태를 남기며, 사람이 이해할 수 있는 방식으로 Role, Task, 상태, 승인, 검증, 인계를 관리하는 것이다.

이 강점은 유지하되, 상태 판단은 문서 기반 약속에만 의존하지 않도록 점진적으로 기계가 읽을 수 있는 구조로 보강한다.

Markdown 문서는 사람이 이해하기 위한 설명으로 유지한다. 다만 Agent와 CLI가 판단해야 하는 핵심 상태는 schema와 정규화된 project state를 기준으로 읽게 만든다.

## 권장 작업 순서

### 1. 정규화된 프로젝트 상태 조회 추가

읽기 전용 상태 조회 명령을 추가한다.

후보 명령:

```sh
aiops project inspect
aiops project inspect --json
```

예상 동작:

- `.ai_project/` 운영 문서를 읽는다.
- Task, workflow, agent, source of truth 관련 schema 정보를 읽는다.
- 현재 Git 브랜치, canonical branch, 최신 status ref를 확인한다.
- 하나의 정규화된 프로젝트 상태 요약을 출력한다.
- 파일은 수정하지 않는다.

이 명령은 이후 validation, agent context, health summary, dashboard의 공통 입력 기반이 된다.

### 2. 문서 간 관계 검증 강화

`aiops doctor --strict`를 단순 파일 존재 검사에서 관계 검증으로 확장한다.

검증 후보:

- Task가 존재하는 Role 또는 Agent를 참조하는가?
- Task 상태가 현재 workflow에 존재하는가?
- Task dependency가 실제 Task를 가리키는가?
- dependency 상태가 현재 Task 진행을 허용하는가?
- `source_of_truth`가 실제 파일을 가리키거나 명시적으로 미정 상태를 표시하는가?
- worktree 상태가 canonical status ref와 비교되는가?
- Fast Track과 Guided Full 템플릿이 같은 validator 기준에서 유효한가?

기존 프로젝트 호환성이 불확실한 항목은 처음에는 warning으로 시작한다.

### 3. Task 상태별 필수 조건 추가

Task 상태마다 필요한 정보나 증거를 정의한다.

예시:

- `approved`: 범위, owner, allowed paths, acceptance criteria
- `in_progress`: 담당 Role 또는 Agent, branch/worktree 정보
- `verification_ready`: 구현 보고, 변경 경로, 테스트 증거 또는 테스트 생략 사유
- `verification_passed`: 검증 보고, 확인한 기준, 남은 리스크
- `completion_review`: Lead 또는 Completion Role 인계 내용
- `done`: 완료 기록, 최종 상태 기준, merge 여부 또는 no-merge 결정

처음에는 검증 가이드와 warning 중심으로 적용하고, 마이그레이션 지원이 준비된 뒤 strict 기준을 강화한다.

### 4. Canonical Status 조회와 상태 전이 보호 강화

v0.9.0에서 추가한 shared status 정책을 기반으로, 상태 판단과 전이 시 stale 상태를 더 명확히 감지한다.

예상 검사:

- canonical branch 또는 ref가 설정되어 있는가?
- 최신 remote status를 fetch했는가?
- fetch하지 못했다면 그 상태가 명확히 표시되는가?
- local Task 상태와 canonical Task 상태가 다른가?
- 오래된 base에서 상태 전이를 시도하고 있는가?
- 명령 출력이 local 기준인지 canonical 기준인지 명확히 표시하는가?

이 개선은 오래된 worktree 문서를 최신 상태로 오인하는 문제를 줄인다.

### 5. Workflow 정의 단일화

Workflow 상태와 전이 규칙을 하나의 기계 판독 가능한 catalog로 모은다.

예상 결과:

- CLI validation이 하나의 workflow 정의를 읽는다.
- 사람용 문서는 같은 정의를 요약하거나 링크한다.
- 상태 전이 규칙이 여러 문서에 서로 다르게 반복되지 않는다.
- 프로젝트별 override는 가능하되, 어떤 점이 다른지 명시해야 한다.

별도 모델 개정 승인이 있기 전까지는 현재 workflow 상태 이름과 의미를 유지한다.

### 6. Agent Context Contract 추가

Agent가 세션을 시작할 때 읽어야 할 기준과 허용 행동을 명확히 출력하는 명령을 추가한다.

후보 명령:

```sh
aiops project context --role lead
aiops project context --role execution --task T-YYYYMMDD-001
```

출력 후보:

- 현재 Role
- 현재 Task
- 사용한 canonical status ref
- 반드시 읽어야 할 파일
- 허용 경로
- 금지 행동
- 가능한 다음 상태
- 다음 인계 대상
- 사용자 승인 필요 여부

이 명령은 Codex, Claude, 그 외 Agent 도구가 같은 운영 계약을 읽고 시작하게 만드는 기반이 된다.

### 7. Project Health / Readiness 요약 추가

프로젝트가 현재 어느 정도 준비되었는지 짧게 확인하는 명령을 추가한다.

후보 명령:

```sh
aiops project health
aiops project health --json
```

요약 후보:

- 운영 구성 유효성
- Task board 정합성
- stale worktree 위험
- migration 필요 여부
- schema 적용 범위
- unresolved decision
- strict mode blocker

이 단계는 CLI 텍스트와 JSON 출력까지만 다룬다. Dashboard는 다음 단계에서 검토한다.

### 8. Release, Migration, Documentation 정리

구현 후 릴리즈 전에 아래를 확인한다.

- seed, bootstrap, doctor, migration, inspect, context, health 흐름 E2E 테스트
- 새 프로젝트와 기존 `.ai_project` 프로젝트 호환성 테스트
- release notes 업데이트
- README는 필수 사용 흐름만 유지
- 상세 설명은 별도 문서로 분리

## 마이그레이션 기준

기존 프로젝트는 즉시 깨지지 않아야 한다.

권장 흐름:

- 프로젝트의 AI Ops 버전과 누락된 schema 필드를 먼저 감지한다.
- 변경 영향 범위를 먼저 설명한다.
- migration plan을 생성한다.
- 사용자 승인 후 적용한다.
- 운영 상태 수정 시 backup 파일 또는 branch 기준을 제공한다.

## 사용자 승인 지점

아래 시점에서는 작업을 멈추고 사용자 승인을 받아야 한다.

- 이 계획을 실제 구현으로 전환하기 전
- 기존 프로젝트에 strict 실패를 유발할 수 있는 검사를 추가하기 전
- workflow 상태 이름이나 의미를 바꾸기 전
- v0.10.0 태그와 릴리즈를 만들기 전

## 기대 결과

이 단계가 끝나면 AI Ops는 프로젝트 상태를 더 안정적으로 읽고, stale worktree 문제를 더 잘 감지하며, Task 상태와 Role 행동 가능 여부를 더 명확하게 판단할 수 있어야 한다.

이 기반이 준비된 뒤 다음 버전에서 사용자용 Dashboard나 시각화 기능을 논의한다.

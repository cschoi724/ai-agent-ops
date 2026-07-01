# AI Agent Ops Tutorial

작성일: 2026-06-29
상태: Draft v1
범위: Codex 기준 PM / Development / QA / AI Ops Agent 운영 튜토리얼

## 1. 목적

이 문서는 AI Agent 운영 방식을 처음 적용하는 사람이 전체 흐름을 이해하고 실제 프로젝트에서 사용할 수 있도록 안내한다.

목표는 사람이 매번 긴 지시를 복사/붙여넣기 하지 않고, Agent들이 `.ai_project/`의 공유 문서를 기준으로 자기 역할과 다음 작업을 찾게 만드는 것이다.

## 2. 핵심 개념

AI Agent 운영은 두 영역으로 나눈다.

| 영역 | 역할 |
|---|---|
| `.ai/` | 공통 운영 가이드북과 템플릿 |
| `.ai_project/` | 특정 프로젝트의 실제 Agent 협업 상태 |

`.ai/`는 여러 프로젝트에 재사용하는 운영 템플릿이다. 프로젝트 진행 중 Agent가 임의로 수정하지 않는다.

`.ai_project/`는 프로젝트별 Task Queue, 현재 컨텍스트, 보고서, QA 결과, 운영 결정을 기록하는 실제 작업 공간이다.

## 3. 기본 Agent

기본 실행 운영은 아래 세 Agent로 시작한다.

| Agent | 핵심 역할 |
|---|---|
| PM Agent | 작업 정의, 승인 게이트, Task Queue 관리, 최종 판단 |
| Development Agent | 승인된 Task 범위 안에서 구현, 검증, 개발 보고 |
| QA Agent | 개발 결과 검증, 리스크 분석, 재작업 필요 여부 정리 |

이 세 Agent는 고정 상한이 아니다. 운영 중 반복 부담이 커지면 PM Agent가 새 Agent 추가와 capability 위임을 제안한다.

AI Ops Agent는 실행 Agent가 아니라 독립 운영 Agent다.

| Agent | 핵심 역할 |
|---|---|
| AI Ops Agent | 운영 프로세스 점검, 역할/권한 충돌 확인, AI 운영 마이그레이션 주도 |

AI Ops Agent는 제품 Task 생성, 승인, 상태 변경, 코드 수정, QA 판정을 하지 않는다.

## 4. 사람이 하는 일

사람은 Product Owner 역할을 한다.

주요 책임:

- 프로젝트 방향 결정
- Task 진행 승인
- 정책, 요구사항, 외부 설정처럼 Agent가 확정할 수 없는 항목 결정
- 커밋, push, 배포 승인
- Agent 운영 방식 변경 승인

사람이 매번 구현 세부 지시를 길게 작성하는 것이 목표가 아니다. 방향과 승인만 주고, 세부 실행 지시는 `.ai_project/tasks/`에 남긴다.

## 5. 첫 적용 순서

새 프로젝트에 적용할 때는 아래 순서로 진행한다.

1. 프로젝트 루트에 `.ai/`를 준비한다.
2. 프로젝트 `.gitignore`에 `.ai/`를 제외한다.
3. AI Ops Agent가 사용자 승인 후 `.ai_project/` 초기화 또는 운영 마이그레이션을 진행한다.
4. `.ai_project/source_of_truth.md`에 프로젝트 기준 문서를 매핑한다.
5. `.ai_project/agent_registry.md`에 활성 Agent를 기록한다.
6. PM Agent가 첫 Task를 `.ai_project/tasks/`에 생성한다.
7. 사용자가 Task 진행을 승인한다.
8. Development Agent와 QA Agent가 Task Queue를 읽고 자기 작업을 수행한다.

## 6. 세션별 운영 방식

### PM Agent 세션

PM Agent는 프로젝트 진행관리 세션이다.

시작 시 확인:

1. `.ai/README.md`
2. `.ai/workflow.md`
3. `.ai/task_queue.md`
4. `.ai/agents/pm_agent.md`
5. `.ai_project/current_context.md`
6. `.ai_project/tasks/`
7. `.ai_project/source_of_truth.md`

주요 작업:

- 다음 Task 후보 정리
- 새 요구사항과 기존 Task Queue의 우선순위 비교
- 사용자 승인 필요 항목 정리
- Task 파일 생성
- Task 상태를 `proposed`에서 `approved`로 변경
- Development / QA 보고 확인
- `qa_passed` Task를 `done`으로 확정할지 판단
- `task_board.md` 요약 갱신

PM Agent는 사용자 승인 없이 `.ai/` 운영 문서를 수정하지 않는다.

### Development Agent 세션

Development Agent는 실제 구현 세션이다.

시작 시 확인:

1. 개발 세션용 프로젝트 지침
2. `.ai/task_queue.md`
3. `.ai/agents/development_agent.md`
4. `.ai_project/current_context.md`
5. 자신에게 할당된 `.ai_project/tasks/*.md`
6. Task의 `source_of_truth`

실행 가능한 Task 조건:

- `status: approved`
- `approved_by`가 비어 있지 않음
- `target_agent` 또는 `required_capabilities`가 자신과 맞음
- `allowed_paths`가 명시됨
- `depends_on`이 모두 `done`
- `locked_by`가 비어 있음

작업 흐름:

1. 실행 가능한 Task를 하나 선택한다.
2. Task 상태를 `in_progress`로 바꾸고 lock을 획득한다.
3. 승인된 범위 안에서만 구현한다.
4. 가능한 검증을 수행한다.
5. 개발 보고서를 `.ai_project/reports/`에 작성한다.
6. Task 상태를 `ready_for_qa`로 바꾸고 lock을 비운다.

Development Agent는 사용자 승인 없이 커밋하거나 push하지 않는다.

### QA Agent 세션

QA Agent는 검증 세션이다.

시작 시 확인:

1. `.ai/task_queue.md`
2. `.ai/agents/qa_agent.md`
3. `.ai_project/current_context.md`
4. `ready_for_qa` 상태의 Task
5. Development Agent 보고서
6. Task의 `source_of_truth`

실행 가능한 QA 조건:

- `status: ready_for_qa`
- 개발 보고서가 존재함
- `depends_on`이 모두 `done`
- `locked_by`가 비어 있음

작업 흐름:

1. QA 가능한 Task를 하나 선택한다.
2. Task 상태를 `qa_in_progress`로 바꾸고 lock을 획득한다.
3. 변경 범위, 문서 일치성, 검증 결과, 리스크를 확인한다.
4. QA 보고서를 `.ai_project/qa/`에 작성한다.
5. 결과가 `PASS` 또는 `PASS_WITH_RISK`면 Task 상태를 `qa_passed`로 바꾼다.
6. 결과가 `FAIL`이면 `rework_requested`로 바꾼다.
7. 외부 요인으로 검증할 수 없으면 `blocked`로 바꾼다.
8. lock을 비운다.

QA Agent는 직접 기능 구현을 하지 않고, 커밋 또는 push도 직접 수행하지 않는다.

### AI Ops Agent 세션

AI Ops Agent는 운영 프로세스 점검과 AI 운영 마이그레이션 세션이다.

시작 시 확인:

1. `.ai/agents/ai_ops_agent.md`
2. `.ai/workflows/ops_migration.md`
3. `.ai/project_workspace.md`
4. `.ai/task_queue.md`
5. `.ai_project/current_context.md`
6. `.ai_project/agent_registry.md`
7. `.ai_project/ops_issues.md`
8. `.ai_project/ops_migration_plan.md`

주요 작업:

- 새 프로젝트 AI 운영 초기화
- 기존 프로젝트 AI 운영 마이그레이션 계획 작성
- `.ai_project/` 운영 문서 구조 점검
- 기존 `AGENTS.md`와 운영 지침 병합안 작성
- source of truth 매핑 초안 작성
- 운영 프로세스 충돌과 모호성 기록
- `.ai_project/ops_issues.md`와 `.ai_project/ops_migration_plan.md` 갱신

AI Ops Agent는 제품 Task 상태를 변경하지 않는다.

## 7. Task 상태 흐름

기본 상태 흐름:

```text
proposed -> approved -> in_progress -> ready_for_qa -> qa_in_progress -> qa_passed -> done
```

재작업 흐름:

```text
qa_in_progress -> rework_requested -> approved -> in_progress
```

차단 흐름:

```text
approved/in_progress/ready_for_qa -> blocked
blocked -> approved
```

중요한 기준:

- `proposed`는 아직 실행하면 안 되는 후보 Task다.
- `approved`는 사용자가 진행을 승인한 Task다.
- `qa_passed`는 QA가 통과했지만 PM 확정 전 상태다.
- `done`은 PM Agent가 최종 완료로 확정한 상태다.

## 8. Task 작성 예시

PM Agent는 `.ai/templates/tasks/task.md`를 기준으로 Task를 만든다.

생성 직후 예시:

```yaml
---
id: T-20260629-001
title: Social Login callback payload 계약 정리
status: proposed
type: docs
priority: P1
target_agent: Development Agent
required_capabilities:
  - implementation
depends_on: []
allowed_paths:
  - ios/ippeo/Docs/
source_of_truth:
  - ios/ippeo/Docs/IMPLEMENTATION_PLAN.md
  - ios/ippeo/Docs/BRIDGE_SPEC.md
created_by: PM Agent
approved_by:
locked_by:
locked_at:
lock_session:
lock_timeout_minutes: 240
created_at: 2026-06-29
updated_at: 2026-06-29
report_to: .ai_project/reports/T-20260629-001_dev-report.md
qa_to: .ai_project/qa/T-20260629-001_qa-report.md
---
```

사용자가 진행을 승인하면 PM Agent가 아래처럼 바꾼다.

```yaml
status: approved
approved_by: Product Owner
```

Development Agent는 승인 전 Task를 실행하지 않는다.

## 9. 사람이 Agent에게 말하는 방식

PM Agent에게:

```text
.ai와 .ai_project 기준으로 현재 다음 Task 후보를 정리해줘.
실행은 하지 말고, 내가 결정해야 할 항목과 추천안을 알려줘.
```

새 요구사항을 전달할 때:

```text
다음 요구사항을 기존 Task Queue와 비교해서 우선순위를 제안해줘.
기존 Task를 밀어내야 하면 이유와 영향 범위를 설명하고,
아직 Task 상태나 priority는 변경하지 마.

요구사항:
[내용]
```

PM Agent가 특정 작업을 다음 실행 후보로 정했다면, 개발 세션에 붙여넣을 지시문을 출력하지 않고 `.ai_project/tasks/`에 `proposed` Task 파일을 만든다.

```text
Plan B를 .ai_project/tasks/에 proposed Task 파일로 생성해줘.
아직 approved로 바꾸지 말고, task_board.md는 요약만 갱신해줘.
```

Task 승인:

```text
T-20260629-001 진행 승인. allowed_paths와 source_of_truth 범위 안에서만 진행하도록 Task를 approved로 바꿔줘.
```

Development Agent에게:

```text
.ai/task_queue.md와 .ai_project/current_context.md를 확인하고,
내 역할에 맞는 approved Task가 있으면 하나만 선택해서 진행해줘.
완료 후 개발 보고서를 작성하고 ready_for_qa로 넘겨줘.
```

QA Agent에게:

```text
.ai/task_queue.md와 .ai_project/tasks/를 확인하고,
ready_for_qa Task가 있으면 하나만 검증해줘.
결과는 PASS, PASS_WITH_RISK, FAIL, BLOCKED 중 하나로 분류해줘.
```

AI Ops Agent에게:

```text
너는 이 프로젝트의 AI Ops Agent야.
.ai/agents/ai_ops_agent.md와 .ai/workflows/ops_migration.md를 기준으로
현재 프로젝트에 AI Agent 운영 체계를 적용하거나 점검해줘.
제품 Task 상태는 변경하지 말고, 운영 이슈와 마이그레이션 계획만 문서화해줘.
```

## 10. 커밋과 Push

기본 기준:

- `.ai/` 변경은 `ai-agent-ops` 저장소 커밋이다.
- `.ai_project/` 변경은 적용 대상 프로젝트의 운영 상태다.
- 프로젝트 코드/문서 변경과 `.ai/` 템플릿 변경은 섞지 않는다.
- 커밋, push, 배포는 사용자 승인 후 진행한다.

초기 마이그레이션 또는 운영 실험 단계에서는 `.ai_project/`를 로컬 전용으로 둘 수 있다. 이 경우 사유와 재검토 조건을 migration 문서 또는 `.ai_project/ops_decisions.md`에 기록한다.

## 11. 자주 생기는 실수

| 실수 | 방지 기준 |
|---|---|
| `.ai/`에 프로젝트 진행 기록을 남김 | 프로젝트별 기록은 `.ai_project/`에 둔다 |
| `proposed` Task를 Development Agent가 실행함 | `approved_by`가 비어 있으면 실행하지 않는다 |
| QA 통과를 바로 `done`으로 처리함 | QA는 `qa_passed`, PM이 `done` 확정 |
| `task_board.md`만 보고 작업함 | 실행 기준은 항상 `.ai_project/tasks/`의 Task 파일 |
| 여러 Task를 동시에 진행함 | 한 Agent는 한 번에 하나의 Task만 진행 |
| 기존 프로젝트 문서를 템플릿으로 덮어씀 | 기존 문서는 source of truth로 유지 |

## 12. 최소 운영 체크리스트

프로젝트 초기화 전:

- `.ai/`가 존재한다.
- `.ai/`가 적용 대상 프로젝트 저장소에서 제외된다.
- `.ai_project/` 생성 위치가 결정됐다.
- AI Ops Agent가 운영 마이그레이션 범위와 생성 파일 목록을 제시했다.
- 기존 프로젝트 source of truth 문서 위치가 확인됐다.

Task 시작 전:

- Task가 `.ai_project/tasks/`에 있다.
- `status`와 `approved_by`가 실행 가능 상태다.
- `allowed_paths`가 명확하다.
- `source_of_truth`가 명확하다.
- `depends_on`이 모두 완료됐다.
- `locked_by`가 비어 있다.

Task 종료 전:

- Task 상태가 다음 단계로 갱신됐다.
- lock이 비워졌다.
- 개발 보고 또는 QA 보고가 작성됐다.
- `task_board.md` 요약이 필요한 경우 갱신됐다.
- 남은 리스크와 사용자 결정 항목이 분리됐다.

## 13. 변경 이력

| 날짜 | 변경 내용 |
|---|---|
| 2026-06-29 | AI Agent Ops 튜토리얼 v1 작성 |
| 2026-07-01 | AI Ops Agent와 운영 마이그레이션 흐름 추가 |

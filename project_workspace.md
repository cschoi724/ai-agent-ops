# Project Workspace Policy

작성일: 2026-06-29  
상태: Draft v1  
범위: `.ai/`와 `.ai_project/` 분리 운영 기준

## 1. 목적

AI Agent 운영 문서는 두 레이어로 분리한다.

- `.ai/`: AI Agent 운영 가이드북과 템플릿 프레임워크
- `.ai_project/`: 특정 프로젝트에 종속되는 실제 Agent 협업 상태와 진행 기록

이 분리는 `ai-agent-ops` 템플릿을 여러 프로젝트에 재사용하면서도, 각 프로젝트의 작업 기록과 의사결정이 템플릿 업데이트와 충돌하지 않게 하기 위한 기준이다.

## 2. 레이어 구분

| 경로 | 성격 | 저장소 포함 | 수정 정책 |
|---|---|---|---|
| `.ai/` | AI Agent 운영 가이드북, 역할, workflow, capability, 템플릿 | 현재 프로젝트 저장소에서는 제외 | 사용자 승인 없이 수정 금지 |
| `.ai_project/` | 프로젝트별 Task Queue, 작업 보드, 보고서, QA 기록, Agent 운영 결정, source of truth 매핑 | 기본적으로 현재 프로젝트 저장소에 포함, 초기 예외 가능 | 프로젝트 운영 중 갱신 가능 |

## 3. `.ai/` 운영 기준

`.ai/`는 `ai-agent-ops` private 저장소에서 내려받아 관리한다.

원격 저장소:

```text
https://github.com/cschoi724/ai-agent-ops.git
```

새 프로젝트에서 권장 설치 방식:

```sh
git clone https://github.com/cschoi724/ai-agent-ops.git .ai
```

프로젝트 저장소에는 `.ai/`를 커밋하지 않는다. 새 프로젝트 적용 시 프로젝트 `.gitignore`에 아래 항목을 추가하는 것을 권장한다.

```gitignore
.ai/
```

주의:

- `.ai/`는 템플릿 저장소이므로 프로젝트 진행 중 Agent가 임의로 수정하지 않는다.
- `.ai/` 변경은 `ai-agent-ops` 저장소의 변경으로 취급한다.
- `.ai/` 변경은 `.ai/document_governance.md` 기준으로 사용자 승인 후 진행한다.

## 4. `.ai_project/` 운영 기준

`.ai_project/`는 특정 프로젝트에 종속되는 협업 데이터다.

새 프로젝트에서 `.ai_project/`는 기본적으로 프로젝트 저장소에 포함한다.

단, 초기 마이그레이션, 운영 실험, 루트 저장소 미구성처럼 프로젝트 저장소 포함 시점이 확정되지 않은 경우에는 사용자 결정으로 `.ai_project/`를 로컬 전용으로 둘 수 있다. 이 예외는 적용 대상 프로젝트의 migration 문서 또는 `.ai_project/ops_decisions.md`에 기록한다.

역할:

- 현재 프로젝트의 Agent 활성 구성
- 실제 Task Queue
- 현재 Agent 운영 컨텍스트
- Task Board 요약
- 프로젝트별 source of truth 기준
- Agent 운영 결정 기록
- workflow override
- 개발 보고
- QA 보고
- 배포 준비 기록

권장 생성 구조:

```text
.ai_project/
  README.md
  agent_registry.md
  current_context.md
  tasks/
  task_board.md
  source_of_truth.md
  ops_decisions.md
  ops_issues.md
  ops_migration_plan.md
  workflow_overrides.md
  reports/
  qa/
  release/
```

## 5. AI Ops Agent의 `.ai_project/` 초기화 권한

AI Ops Agent는 사용자가 프로젝트에 AI Agent 운영을 적용하라고 명시한 경우 `.ai_project/`를 생성하거나 운영 마이그레이션 계획을 작성할 수 있다.

생성 조건:

- `.ai/`가 존재한다.
- 사용자가 현재 프로젝트에 AI Agent 운영 초기화를 요청했다.
- AI Ops Agent가 생성할 파일 목록과 마이그레이션 범위를 먼저 제시했다.
- 사용자가 생성 범위를 승인했다.

AI Ops Agent가 생성할 수 있는 기본 파일:

```text
.ai_project/README.md
.ai_project/agent_registry.md
.ai_project/current_context.md
.ai_project/tasks/
.ai_project/task_board.md
.ai_project/source_of_truth.md
.ai_project/ops_decisions.md
.ai_project/ops_issues.md
.ai_project/ops_migration_plan.md
.ai_project/workflow_overrides.md
.ai_project/reports/
.ai_project/qa/
.ai_project/release/
```

기본 파일 내용은 `.ai/templates/ai_project/`를 기준으로 만든다.

AI Ops Agent는 `.ai_project/`를 생성하더라도 사용자 승인 없이 `.ai/` 운영 문서를 수정하지 않는다.

PM Agent는 운영 마이그레이션 이후 제품/일정 영향 검토, source of truth 최종 판단, 첫 제품 Task 등록을 담당한다.

## 6. `.ai_project/` 수정 권한

| 영역 | 기본 수정 주체 | 승인 필요 여부 |
|---|---|---|
| `.ai_project/current_context.md` | PM Agent | 일반 상태 갱신은 가능, 운영 모드 변경은 사용자 확인 |
| `.ai_project/tasks/` | PM/Dev/QA Agent | 생성과 승인 상태 변경은 PM Agent, 실행 상태 갱신은 담당 Agent |
| `.ai_project/task_board.md` | PM Agent | Task Queue 요약 갱신은 가능, 우선순위 변경은 사용자 확인 권장 |
| `.ai_project/source_of_truth.md` | PM Agent | 프로젝트 기준 변경 전 사용자 승인 |
| `.ai_project/ops_decisions.md` | PM Agent | 사용자 결정 후 갱신 |
| `.ai_project/ops_issues.md` | AI Ops Agent | 운영 이슈 기록 가능, 실행 Task 상태 변경 금지 |
| `.ai_project/ops_migration_plan.md` | AI Ops Agent | 운영 마이그레이션 계획 작성 가능, 적용 전 사용자 승인 |
| `.ai_project/agent_registry.md` | PM Agent | Agent 활성/비활성 변경 전 사용자 승인 |
| `.ai_project/workflow_overrides.md` | PM Agent | workflow 변경 전 사용자 승인 |
| `.ai_project/reports/` | Dev Agent | 개발 완료 보고 작성 가능 |
| `.ai_project/qa/` | QA Agent | QA 보고 작성 가능 |
| `.ai_project/release/` | PM Agent / QA Agent | 배포 관련 작업은 사용자 승인 필요 |

## 7. 문서 참조 우선순위

Agent는 아래 순서로 문서를 해석한다.

1. `.ai/` 운영 가이드북
2. `.ai_project/current_context.md`
3. `.ai_project/tasks/`
4. `.ai_project/` Agent 협업 상태 문서
5. 프로젝트 기존 문서
6. 실제 코드 상태

단, 제품/기술 source of truth는 `.ai_project/source_of_truth.md`에 지정된 프로젝트 문서를 우선 확인한다.

## 8. 충돌 처리

`.ai/`와 `.ai_project/`가 충돌하면 아래 기준을 따른다.

- 운영 원칙 충돌: `.ai/` 우선
- Agent Task 상태 충돌: `.ai_project/tasks/` 우선
- Task 요약 충돌: `.ai_project/tasks/`가 `.ai_project/task_board.md`보다 우선
- 제품/기술 문서 충돌: `.ai_project/source_of_truth.md`에 지정된 프로젝트 문서 우선
- 제품 정책 충돌: 사용자 결정 우선
- 코드 실제 동작 충돌: 코드와 검증 결과를 확인한 뒤 PM Agent가 정리

## 9. 변경 이력

| 날짜 | 변경 내용 |
|---|---|
| 2026-06-29 | `.ai/`와 `.ai_project/` 분리 운영 기준 v1 작성 |
| 2026-06-29 | Task Queue 기반 `.ai_project/` 구조 추가 |
| 2026-06-29 | `.ai_project/` 저장소 포함 기본값과 초기 예외 기준 정리 |
| 2026-07-01 | `.ai_project/` 초기화와 운영 마이그레이션 주체를 AI Ops Agent로 정리 |

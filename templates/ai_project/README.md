# AI Project Workspace

작성일: {{DATE}}  
프로젝트: {{PROJECT_NAME}}  
상태: Draft

## 1. 목적

이 디렉토리는 현재 프로젝트에 종속되는 AI Agent 협업 문서 영역이다.

`.ai/`는 운영 가이드북이고, `.ai_project/`는 실제 Agent Task Queue와 협업 기록을 관리한다.

## 2. 문서 목록

| 문서/폴더 | 역할 |
|---|---|
| `.ai_project/agent_registry.md` | 현재 프로젝트 활성 Agent 구성 |
| `.ai_project/current_context.md` | 세션 시작 시 확인할 현재 운영 컨텍스트 |
| `.ai_project/tasks/` | Agent 실행 Task Queue |
| `.ai_project/tasks/active/` | 실행/검증/완료 판단 대상 Task |
| `.ai_project/tasks/backlog/` | 승인 전 후보와 보류 후보 Task |
| `.ai_project/tasks/archive/` | 완료/취소/오래된 Task 보관 |
| `.ai_project/task_board.md` | Task Queue 요약 보드 |
| `.ai_project/source_of_truth.md` | 프로젝트 기준 문서와 충돌 처리 기준 |
| `.ai_project/ops_decisions.md` | Agent 운영 결정 기록 |
| `.ai_project/ops_issues.md` | AI Agent 운영 프로세스 이슈와 개선 제안 |
| `.ai_project/ops_migration_plan.md` | AI Agent 운영 체계 도입 계획 |
| `.ai_project/workflow_overrides.md` | 프로젝트별 workflow 예외 |
| `.ai_project/reports/` | 작업 완료 보고 |
| `.ai_project/qa/` | QA 보고 |
| `.ai_project/release/` | 릴리즈 준비 기록 |

## 3. 운영 원칙

- `.ai_project/`는 기본적으로 프로젝트 저장소에 포함한다.
- 초기 마이그레이션이나 운영 실험 단계에서 로컬 전용으로 시작하는 경우, 그 결정과 재검토 조건을 `ops_decisions.md`에 기록한다.
- `.ai/` 운영 문서와 충돌하면 운영 원칙은 `.ai/`를 우선한다.
- Agent 실행 지시는 `.ai_project/tasks/`를 우선한다.
- 새 Task는 기본적으로 `active/` 또는 `backlog/`에 생성한다.
- 기존 프로젝트의 `.ai_project/tasks/` 루트 파일은 legacy Task로 인정한다.
- `archive/`는 히스토리 확인이 필요할 때만 참조한다.
- Agent 작업 상태 요약은 `.ai_project/task_board.md`에 기록한다.
- 제품/기술 결정은 프로젝트 문서 영역의 `DECISIONS.md`를 우선한다.
- 사용자 결정이 필요한 항목은 PM Agent가 별도로 정리한다.

## 4. 변경 이력

| 날짜 | 변경 내용 |
|---|---|
| {{DATE}} | `.ai_project/` 초기화 |
| {{DATE}} | AI Ops Issues 문서 항목 추가 |
| {{DATE}} | AI Ops Migration Plan 문서 항목 추가 |
| {{DATE}} | Task active/backlog/archive 보관 구조 항목 추가 |

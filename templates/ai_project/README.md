# AI Project Workspace

작성일: {{DATE}}  
프로젝트: {{PROJECT_NAME}}  
상태: Draft

## 1. 목적

이 디렉토리는 현재 프로젝트에 종속되는 AI Agent 협업 문서 영역이다.

`.ai/`는 운영 가이드북이고, `.ai_project/`는 실제 Agent 작업 상태와 Agent 간 인수인계를 기록한다.

## 2. 문서 목록

| 문서/폴더 | 역할 |
|---|---|
| `.ai_project/agent_registry.md` | 현재 프로젝트 활성 Agent 구성 |
| `.ai_project/task_board.md` | 현재 작업 보드 |
| `.ai_project/source_of_truth.md` | 프로젝트 기준 문서와 충돌 처리 기준 |
| `.ai_project/ops_decisions.md` | Agent 운영 결정 기록 |
| `.ai_project/workflow_overrides.md` | 프로젝트별 workflow 예외 |
| `.ai_project/handoffs/` | Agent 간 인수인계 |
| `.ai_project/reports/` | 개발 완료 보고 |
| `.ai_project/qa/` | QA 보고 |
| `.ai_project/release/` | 릴리즈 준비 기록 |
| `.ai_project/notes/` | 기타 작업 메모 |

## 3. 운영 원칙

- `.ai_project/`는 프로젝트 저장소에 포함한다.
- `.ai/` 운영 문서와 충돌하면 운영 원칙은 `.ai/`를 우선한다.
- Agent 작업 상태와 협업 진행 기록은 `.ai_project/`를 우선한다.
- 제품/기술 결정은 프로젝트 문서 영역의 `DECISIONS.md`를 우선한다.
- 사용자 결정이 필요한 항목은 PM Agent가 별도로 정리한다.

## 4. 변경 이력

| 날짜 | 변경 내용 |
|---|---|
| {{DATE}} | `.ai_project/` 초기화 |

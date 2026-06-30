# Agent Roles

작성일: 2026-06-29  
상태: Draft v1  
범위: AI Agent별 역할과 책임 정의

## 1. 목적

이 폴더는 AI 개발팀 운영에서 사용하는 Agent별 역할, 책임, 금지사항, 산출물을 정의한다.

현재 v1은 Codex 기준 운영을 우선하며, PM Agent, Development Agent, QA Agent를 기본 실행 구성으로 둔다. AI Ops Agent는 실행 흐름 밖에서 운영 프로세스를 독립 점검하는 선택 활성 Agent로 둔다.

## 2. 기본 역할

| Agent | 핵심 책임 | 주요 산출물 |
|---|---|---|
| PM Agent | 방향 정리, Task Queue 관리, 승인 게이트 관리 | Task 파일, Task Board 요약, 결정 필요 항목 |
| Development Agent | 승인된 Task 범위의 구현, 테스트, 개발 보고 | 코드 변경, 테스트 결과, 개발 완료 보고, Task 상태 갱신 |
| QA Agent | 구현 결과 검증, 리스크 분석, 재작업 지시 | QA 보고서, Task 상태 갱신, 잔여 리스크 |
| AI Ops Agent | 운영 프로세스 감사, 역할/권한 충돌 점검, 개선 제안 | 운영 이슈 기록, 개선안, 충돌 점검 보고 |

## 3. 공통 원칙

- 모든 Agent는 `.ai/workflow.md`를 우선한다.
- `.ai/` 운영 문서는 `.ai/document_governance.md` 기준으로 보호한다.
- 사용자 승인 없이 운영 규칙을 바꾸지 않는다.
- 한 번에 하나의 Task 단위로 작업한다.
- 민감정보를 로그, 문서, 보고서에 남기지 않는다.
- 커밋, push, 배포, 외부 설정 변경은 사용자 승인 후 진행한다.
- AI Ops Agent는 제품 Task 실행 라인에 참여하지 않고 운영 프로세스만 점검한다.

## 4. 문서 목록

- `pm_agent.md`: PM Agent 역할과 책임
- `development_agent.md`: Development Agent 역할과 책임
- `qa_agent.md`: QA Agent 역할과 책임
- `ai_ops_agent.md`: AI Ops Agent 역할과 책임

## 5. 변경 이력

| 날짜 | 변경 내용 |
|---|---|
| 2026-06-29 | Agent별 역할 문서 v1 작성 |
| 2026-06-29 | Task Queue 기반 산출물 표현 반영 |
| 2026-06-30 | AI Ops Agent 독립 운영 역할 추가 |

# Agent Roles

작성일: 2026-06-29  
상태: Draft vNext  
범위: 남아 있는 Agent별 참고 문서

## 1. 목적

이 폴더는 Role 모델만으로 표현하기 어려운 특수 Agent 참고 문서를 둔다.

vNext의 기본 실행 단위는 Agent 이름이 아니라 Role이다. Lead / Execution / Verification 책임은 `models/role_model.md`와 프로젝트별 `.ai_project/agent_registry.md`를 따른다.

## 2. 현재 문서

| 문서 | 기본 Role | 핵심 책임 |
|---|---|---|
| `ai_ops_agent.md` | Ops Governance Role | 운영 프로세스 감사, 역할/권한 충돌 점검, 개선 제안 |

## 3. 공통 원칙

- 모든 Agent는 `.ai/runtime/workflow.md`를 우선한다.
- `.ai/` 운영 문서는 `.ai/policies/document_governance.md` 기준으로 보호한다.
- 사용자 승인 없이 운영 규칙을 바꾸지 않는다.
- 한 번에 하나의 Task 단위로 작업한다.
- 민감정보를 로그, 문서, 보고서에 남기지 않는다.
- 커밋, push, 배포, 외부 설정 변경은 사용자 승인 후 진행한다.
- Ops Governance Role은 제품 Task 실행 라인에 참여하지 않고 운영 프로세스만 점검한다.

## 4. 변경 이력

| 날짜 | 변경 내용 |
|---|---|
| 2026-06-29 | Agent별 역할 문서 v1 작성 |
| 2026-06-29 | Task Queue 기반 산출물 표현 반영 |
| 2026-06-30 | AI Ops Agent 독립 운영 역할 추가 |
| 2026-07-09 | vNext Role 기반 bootstrap Agent 설명으로 개정 |
| 2026-07-09 | PM/Development/QA Agent 개별 문서 제거 후 Role 모델 중심으로 축약 |

# Source Of Truth

작성일: {{DATE}}
프로젝트: {{PROJECT_NAME}}
상태: Draft

## Purpose

이 문서는 현재 프로젝트에서 어떤 문서와 코드가 최종 기준인지 기록한다.

`.ai/`는 운영 하네스 기준이고, 제품/기술/검증 기준은 프로젝트 문서 또는 외부 source를 따른다.

## Project Profile

| 항목 | 값 |
|---|---|
| 제품/서비스명 | {{PROJECT_NAME}} |
| 개발 대상 | {{TARGET_PLATFORMS}} |
| 기술스택 | {{TECH_STACK}} |
| 저장소 | {{REPOSITORY}} |
| 기본 브랜치 | {{DEFAULT_BRANCH}} |

## Source Matrix

| 영역 | 최종 기준 | 상태 |
|---|---|---|
| 운영 원칙 | `.ai/` | active |
| 프로젝트 운영 구성 | `.ai_project/operating_model.md` | active |
| Agent 구성 | `.ai_project/agent_registry.md` | active |
| Task | `.ai_project/tasks/` | active |
| 현재 상태 | {{CURRENT_STATUS_DOC}} | {{STATUS}} |
| 구현 계획 | {{IMPLEMENTATION_PLAN_DOC}} | {{STATUS}} |
| 아키텍처 | {{ARCHITECTURE_DOC}} | {{STATUS}} |
| API/계약 | {{API_DOC}} | {{STATUS}} |
| QA 기준 | {{QA_DOC}} | {{STATUS}} |
| 변경 이력 | {{CHANGELOG_DOC}} | {{STATUS}} |
| 미확정 질문 | {{PENDING_QUESTIONS_DOC}} | unresolved |

## Validation Commands

| 목적 | 명령 또는 절차 |
|---|---|
| 정적 검사 | {{LINT_COMMAND}} |
| 테스트 | {{TEST_COMMAND}} |
| 빌드 | {{BUILD_COMMAND}} |
| 수동 QA | {{QA_PROCEDURE}} |

## Conflict Rule

1. 사용자 승인 결정이 최우선이다.
2. 문서와 코드가 다르면 코드 동작과 검증 결과를 확인한다.
3. 오래된 문서는 Lead 또는 Direction Role이 갱신 필요성을 기록한다.
4. 충돌 해결 후 관련 Task와 Board를 갱신한다.

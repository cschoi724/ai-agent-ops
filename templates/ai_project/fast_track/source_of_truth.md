# Source of Truth

작성일: {{DATE}}
프로젝트: {{PROJECT_NAME}}

## 1. 목적

Agent가 판단 기준으로 삼을 문서와 아직 정해지지 않은 기준을 기록한다.

## 2. 기준 문서

| 영역 | 상태 | 기준 |
|---|---|---|
| Agent 운영 원칙 | confirmed | `.ai/` |
| 프로젝트 운영 구성 | confirmed | `.ai_project/operating_model.md` |
| 현재 컨텍스트 | confirmed | `.ai_project/current_context.md` |
| 제품/업무 요구사항 | unresolved | {{REQUIREMENTS_SOURCE}} |
| 기획/계획 | unresolved | {{PLANNING_SOURCE}} |
| 아키텍처 | unresolved | 구현 준비 시 결정 |
| 테스트 전략 | unresolved | Verification Role 활성화 시 결정 |

## 3. 규칙

- 존재하지 않는 문서를 확정 기준처럼 기록하지 않는다.
- 미정 기준은 `unresolved`로 남긴다.
- 기준 문서를 만들거나 바꾸려면 Direction Role 또는 Lead Role이 사용자에게 확인한다.

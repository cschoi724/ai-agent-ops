# Source Of Truth

작성일: {{DATE}}  
프로젝트: {{PROJECT_NAME}}  
상태: Draft

## 1. 목적

이 문서는 현재 프로젝트에서 어떤 문서와 코드가 최종 기준인지 정의한다.

`.ai/`는 Agent 운영 가이드북이고, `.ai_project/`는 Agent 협업 상태다. 실제 제품, 기술스택, 구현 계획, 아키텍처, QA 기준은 프로젝트 문서 영역을 기준으로 관리한다.

## 2. 프로젝트 프로필

| 항목 | 값 |
|---|---|
| 제품/서비스명 | {{PROJECT_NAME}} |
| 개발 대상 | {{TARGET_PLATFORMS}} |
| 주 기술스택 | {{TECH_STACK}} |
| 저장소 | {{REPOSITORY}} |
| 기본 브랜치 | {{DEFAULT_BRANCH}} |
| 배포 대상 | {{RELEASE_TARGETS}} |

## 3. Source Of Truth 매트릭스

| 영역 | 최종 기준 | 보조 기준 | 충돌 시 처리 |
|---|---|---|---|
| Agent 운영 원칙 | `.ai/` | `.ai_project/` | 운영 원칙은 `.ai/` 우선 |
| 프로젝트 운영 구성 | `.ai_project/operating_model.md` | `.ai/bootstrap/project_bootstrap_policy.md`, `.ai/core/constitution.md` | 프로젝트별 선택값은 `.ai_project/operating_model.md` 우선 |
| Agent 구성 | `.ai_project/agent_registry.md` | `.ai/models/agent_registry.md` | 프로젝트 활성 구성은 `.ai_project/` 우선 |
| Agent 실행 Task | `.ai_project/tasks/` | `.ai_project/task_board.md`, report/QA 문서 | Task 파일 우선 |
| Agent 작업 상태 요약 | `.ai_project/task_board.md` | `.ai_project/tasks/` | 충돌 시 Task 파일 기준으로 보드 갱신 |
| 제품/기술 결정 | `DECISIONS.md` | 회의록, 이슈, PR | 최신 승인 결정 우선 |
| 구현 계획 | `IMPLEMENTATION_PLAN.md` | `.ai_project/tasks/`, `.ai_project/task_board.md` | 계획 변경은 Lead Role 또는 Direction Role이 문서화 |
| 현재 상태 | `CURRENT_STATUS.md` | CHANGELOG, QA 결과 | 코드/검증 결과 확인 후 갱신 |
| 아키텍처 | `ARCHITECTURE.md` | 코드, ADR, 설계 노트 | 실제 코드와 결정 문서 모두 확인 |
| 변경 이력 | `CHANGELOG.md` | Git commit, PR | 누락 시 CHANGELOG 갱신 |
| QA 기준 | `QA_CHECKLIST.md` | 테스트 코드, QA 보고 | Verification Role이 리스크 분류 |
| 미확정 질문 | `PENDING_QUESTIONS.md` | 사용자 대화, 이슈 | 사용자 결정 후 관련 문서 반영 |
| 미구현/보류 기능 | `UNIMPLEMENTED_FEATURES.md` | 구현 계획, 이슈 | 우선순위는 Lead Role 또는 Direction Role이 확인 |

## 4. 프로젝트 문서 위치

프로젝트 성격에 맞춰 아래 중 하나를 선택한다.

| 방식 | 사용 조건 | 예시 |
|---|---|---|
| 루트 `docs/` | 웹/서버/멀티플랫폼 프로젝트 | `docs/CURRENT_STATUS.md` |
| 플랫폼별 `Docs/` | iOS, Android 등 플랫폼 단위 프로젝트 | `ios/App/Docs/CURRENT_STATUS.md` |
| 모듈별 docs | 모노레포 또는 대형 서비스 | `apps/mobile/Docs/CURRENT_STATUS.md` |

현재 프로젝트 기준 위치:

```text
{{PROJECT_DOCS_PATH}}
```

## 5. 빌드/검증 기준

| 목적 | 명령 또는 절차 | 실행 주체 |
|---|---|---|
| 정적 검사 | {{LINT_COMMAND}} | Execution Role |
| 테스트 | {{TEST_COMMAND}} | Execution Role / Verification Role |
| 빌드 | {{BUILD_COMMAND}} | Execution Role |
| 수동 QA | `QA_CHECKLIST.md` 기준 | Verification Role |

## 6. 충돌 해결 원칙

1. 사용자 승인 결정이 최우선이다.
2. 실제 코드 동작과 문서가 다르면 코드와 검증 결과를 먼저 확인한다.
3. 문서가 오래되었으면 Lead Role 또는 Direction Role이 갱신 필요성을 보고한다.
4. Agent 운영 문서와 프로젝트 기술 문서가 충돌하면 영역을 분리해 해석한다.
5. 충돌 해결 후 관련 Task 파일과 `.ai_project/task_board.md`를 갱신한다.

## 7. 변경 이력

| 날짜 | 변경 내용 |
|---|---|
| {{DATE}} | Source Of Truth 문서 초기화 |

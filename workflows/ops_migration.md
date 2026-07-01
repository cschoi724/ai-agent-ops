# Ops Migration Workflow

작성일: 2026-07-01  
상태: Draft v1  
범위: 새 프로젝트 또는 기존 프로젝트에 AI Agent 운영 체계 도입

## 1. 목적

이 workflow는 `.ai/` 템플릿과 `.ai_project/` 프로젝트 운영 문서를 적용해 AI Agent 운영 체계를 도입하는 절차를 정의한다.

제품 기능 개발이나 앱 코드 변경을 직접 수행하지 않는다. 운영 체계 도입은 AI Ops Agent가 주도하고, 제품/일정 영향 판단은 PM Agent와 Product Owner가 확인한다.

## 2. 담당 Agent

| Agent | 책임 |
|---|---|
| AI Ops Agent | 운영 마이그레이션 계획 수립, 구조 초기화, 운영 문서 병합안 작성 |
| PM Agent | 제품/일정 영향 검토, source of truth 최종 판단, 사용자 승인 요청 |
| Development Agent | 코드/빌드/폴더 경로 영향이 있는 변경 실행 |
| QA Agent | 마이그레이션 후 링크, 문서 정합성, 실행 흐름 검증 |

## 3. 적용 대상

- 새 프로젝트에 AI Agent 운영 체계를 처음 적용하는 경우
- 기존 프로젝트에 `.ai/`와 `.ai_project/` 구조를 도입하는 경우
- 기존 `AGENTS.md`와 AI 운영 지침을 병합하는 경우
- 프로젝트별 source of truth 문서 체계를 정리하는 경우

## 4. 기본 흐름

```text
AI Ops analyzes project -> AI Ops drafts migration plan -> Product Owner approves -> AI Ops applies ops docs -> PM creates first Task -> Dev/QA verify flow
```

## 5. 절차

1. AI Ops Agent가 현재 프로젝트 구조와 기존 운영 지침을 분석한다.
2. `.ai/` 적용 방식과 `.gitignore` 정책을 확인한다.
3. `.ai_project/` 초기 구조 생성 계획을 작성한다.
4. 기존 문서를 삭제하지 않고 source of truth 매핑 초안을 작성한다.
5. 기존 `AGENTS.md`가 있으면 백업과 병합안을 작성한다.
6. 백업/롤백 전략을 작성한다.
7. 사용자 승인을 받은 뒤 운영 문서를 적용한다.
8. `.ai_project/agent_registry.md`, `current_context.md`, `source_of_truth.md`, `task_board.md`, `ops_decisions.md`, `ops_issues.md`를 초기화한다.
9. PM/Development/QA/AI Ops 세션 시작 기준을 정리한다.
10. 첫 파일럿 Task는 PM Agent가 별도로 `proposed` Task로 등록한다.

## 6. 새 프로젝트 기준

새 프로젝트에서는 아래 순서로 진행한다.

1. `.ai/` 템플릿을 프로젝트 루트에 배치한다.
2. 프로젝트 저장소의 `.gitignore`에 `.ai/`를 제외한다.
3. `.ai_project/`를 프로젝트 저장소에 포함할 운영 문서 영역으로 초기화한다.
4. 프로젝트 성격에 맞는 source of truth 문서 구성을 제안한다.
5. 아직 제품 Task는 만들지 않는다.

## 7. 기존 프로젝트 기준

기존 프로젝트에서는 아래 순서로 진행한다.

1. 기존 문서와 운영 지침을 먼저 분석한다.
2. 파일 이동이나 삭제 없이 마이그레이션 계획부터 작성한다.
3. 기존 문서는 백업하거나 그대로 source of truth로 유지한다.
4. 코드/빌드 경로에 영향이 있는 변경은 Development Agent Task로 분리한다.
5. 마이그레이션 후 QA Agent가 문서 링크, Task Queue, 세션 시작 기준을 검증한다.

## 8. 산출물

권장 산출물:

- `.ai_project/ops_migration_plan.md`
- `.ai_project/agent_registry.md`
- `.ai_project/current_context.md`
- `.ai_project/source_of_truth.md`
- `.ai_project/task_board.md`
- `.ai_project/ops_decisions.md`
- `.ai_project/ops_issues.md`
- 기존 `AGENTS.md` 백업 또는 병합안

## 9. 금지사항

- 제품 Task를 임의로 생성하거나 승인하지 않는다.
- 앱 코드나 빌드 설정을 직접 수정하지 않는다.
- 기존 프로젝트 문서를 사용자 승인 없이 삭제하지 않는다.
- PM Agent의 제품 우선순위를 변경하지 않는다.
- Development/QA Task 상태를 변경하지 않는다.
- `.ai/` 템플릿을 사용자 승인 없이 수정하지 않는다.

## 10. 완료 기준

- `.ai/`와 `.ai_project/`의 역할 경계가 명확하다.
- PM/Development/QA/AI Ops 세션 시작 기준이 문서화되어 있다.
- source of truth 문서가 지정되어 있다.
- 기존 문서의 백업 또는 유지 기준이 정리되어 있다.
- 첫 파일럿 Task를 PM Agent가 등록할 수 있는 상태다.
- AI Ops 이슈 기록 위치가 준비되어 있다.

## 11. 변경 이력

| 날짜 | 변경 내용 |
|---|---|
| 2026-07-01 | Ops Migration workflow v1 작성 |

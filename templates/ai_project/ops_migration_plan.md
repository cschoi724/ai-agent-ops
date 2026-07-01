# AI Ops Migration Plan

작성일: {{DATE}}
프로젝트: {{PROJECT_NAME}}
상태: Draft

## 1. 목적

이 문서는 현재 프로젝트에 AI Agent 운영 체계를 도입하기 위한 프로젝트별 마이그레이션 계획이다.

운영 체계 도입은 AI Ops Agent가 주도한다. 제품 우선순위와 개발 Task 승인은 PM Agent와 Product Owner가 담당한다.

## 2. 현재 프로젝트 구조 요약

```text
{{PROJECT_STRUCTURE_SUMMARY}}
```

## 3. 적용할 운영 구조

```text
{{PROJECT_ROOT}}/
  .ai/
  .ai_project/
    agent_registry.md
    current_context.md
    source_of_truth.md
    task_board.md
    ops_decisions.md
    ops_issues.md
    ops_migration_plan.md
    tasks/
    reports/
    qa/
    release/
```

## 4. Source Of Truth 매핑

| 영역 | 기준 문서 | 보조 문서 | 비고 |
|---|---|---|---|
| 현재 상태 |  |  |  |
| 구현 계획 |  |  |  |
| 아키텍처 |  |  |  |
| 결정사항 |  |  |  |
| 변경 이력 |  |  |  |

## 5. 기존 문서 처리 기준

- 기존 문서는 기본적으로 삭제하지 않는다.
- 기존 문서가 유효하면 그대로 source of truth로 연결한다.
- 정리가 필요한 문서는 백업 위치와 롤백 기준을 먼저 기록한다.

## 6. AGENTS.md 병합 계획

| 위치 | 현재 상태 | 처리 방향 | 비고 |
|---|---|---|---|
| 프로젝트 루트 `AGENTS.md` |  |  |  |
| 하위 프로젝트 `AGENTS.md` |  |  |  |

## 7. 백업/롤백 전략

| 대상 | 백업 위치 | 롤백 조건 | 담당 |
|---|---|---|---|
|  |  |  |  |

## 8. 적용 단계

1. 현재 구조와 기존 문서 분석
2. `.ai/` 적용과 Git 제외 정책 확인
3. `.ai_project/` 초기 구조 생성
4. source of truth 매핑 작성
5. `AGENTS.md` 백업과 병합
6. PM/Development/QA/AI Ops 세션 시작 기준 정리
7. PM Agent가 첫 `proposed` Task 등록
8. Development/QA Agent로 파일럿 검증

## 9. 사용자 결정 필요 항목

| 항목 | 선택지 | 권장안 | 결정 |
|---|---|---|---|
| `.ai_project/` Git 포함 여부 | 포함 / 로컬 전용 | 포함 |  |
| 기존 문서 처리 | 유지 / 백업 후 병합 / 재작성 | 유지 후 source of truth 연결 |  |
| 첫 파일럿 Task |  |  |  |

## 10. 리스크

| 리스크 | 영향 | 대응 |
|---|---|---|
| 기존 운영 지침과 AI 운영 지침 충돌 | Agent가 서로 다른 기준으로 동작 | AI Ops Agent가 병합안 작성 |
| source of truth 미정 | Task 실행 기준 불명확 | PM Agent와 Product Owner가 기준 문서 확정 |
| 코드/빌드 경로 영향 | 개발 작업 실패 가능 | Development Agent Task로 분리 |

## 11. 변경 이력

| 날짜 | 변경 내용 |
|---|---|
| {{DATE}} | AI Ops Migration Plan 초기화 |

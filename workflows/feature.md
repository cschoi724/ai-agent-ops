# Feature Workflow

작성일: 2026-06-29  
상태: Draft v1

## 1. 용도

신규 기능 구현 또는 기존 기능 확장에 사용한다.

## 2. 기본 흐름

```text
PM creates feature Task -> Development executes -> QA verifies -> PM closes
```

## 3. 단계별 책임

| 단계 | Capability | 기본 Agent | 산출물 |
|---|---|---|---|
| 기획/범위 정의 | `planning`, `task_routing` | PM Agent | `.ai_project/tasks/` Task |
| 구현 | `implementation`, `developer_verification` | Development Agent | 코드/문서 변경, 개발 보고 |
| 검증 | `qa_review`, `risk_review` | QA Agent | QA 보고 |
| 통합 판단 | `approval_management` | PM Agent | 커밋/보류/재작업 판단 |

## 4. Optional Hooks

v1에서는 별도 Agent hook을 추가하지 않는다. 아래 조건은 PM 또는 QA의 추가 검토 관점으로 처리한다.

| 조건 | 추가 검토 관점 | 담당 |
|---|---|---|
| 구조 변경, 모듈 경계 변경, 기술 선택이 있음 | `technical_review` | PM Agent |
| 인증, 권한, 결제, 개인정보, 로그 민감정보가 관련됨 | `security_check` | QA Agent |
| 사용자/운영/개발 문서 변경이 큼 | `documentation` | PM Agent 작성, QA Agent 검토 |
| 배포 대상 기능임 | `release_planning`, `release_check` | PM Agent / QA Agent |

## 5. 완료 조건

- Task 승인 범위의 구현이 완료됐다.
- Development Agent가 가능한 검증을 수행했다.
- QA Agent가 `PASS`, `PASS_WITH_RISK`, `FAIL`, `BLOCKED` 중 하나로 결과를 분류했다.
- 남은 리스크와 사용자 결정 항목이 분리되어 있다.

## 6. 변경 이력

| 날짜 | 변경 내용 |
|---|---|
| 2026-06-29 | Feature Workflow v1 작성 |
| 2026-06-29 | Task Queue 기반 기본 흐름 반영 |

# Report Templates

작성일: 2026-06-29  
상태: Draft v1

## 1. 목적

이 폴더는 `.ai_project/reports/`에 생성할 작업 완료 보고서 템플릿을 제공한다.

실행 지시의 source of truth는 `.ai_project/tasks/`의 Task 파일이다. 보고서는 Task 실행 결과를 기록하는 산출물이다.

## 2. 템플릿

| 파일 | 용도 |
|---|---|
| `task_report.md` | PM, Development, AI Ops 등 Task를 처리한 Agent가 공통으로 작성하는 기본 작업 보고 |
| `dev_report.md` | Development Agent 전용 상세 보고가 필요할 때 참고하는 선택 양식 |

## 3. 파일명 규칙

기본 작업 보고:

```text
T-YYYYMMDD-001_task-report.md
```

Agent별 상세 보고가 필요한 경우:

```text
T-YYYYMMDD-001_dev-report.md
```

## 4. 변경 이력

| 날짜 | 변경 내용 |
|---|---|
| 2026-06-29 | Development 보고 템플릿 분리 |
| 2026-07-02 | 공통 Task Report 템플릿 추가 |

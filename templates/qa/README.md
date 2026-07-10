# QA Templates

작성일: {{DATE}}  
상태: Draft vNext

## 1. 목적

이 폴더는 `.ai_project/qa/`에 생성할 Verification Role 산출물 템플릿을 제공한다.

실행 지시의 source of truth는 `.ai_project/tasks/`의 Task 파일이다. QA 문서는 검증 결과와 재작업 요청을 기록한다.

## 2. 템플릿

| 파일 | 용도 |
|---|---|
| `qa_report.md` | Verification Role이 검증 결과를 보고할 때 |
| `rework_request.md` | Verification Role 또는 Completion Role이 재작업 필요 항목을 정리할 때 |

## 3. 파일명 규칙

```text
T-YYYYMMDD-001_qa-report.md
T-YYYYMMDD-001_rework-request.md
```

## 4. 변경 이력

| 날짜 | 변경 내용 |
|---|---|
| 2026-06-29 | QA 템플릿 분리 |
| {{DATE}} | QA Agent 고정 표현을 Verification Role 기준으로 개정 |

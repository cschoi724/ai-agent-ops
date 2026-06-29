# Task Templates

작성일: 2026-06-29  
상태: Draft v1

## 1. 목적

이 폴더는 `.ai_project/tasks/`에 생성할 Task 파일 템플릿을 제공한다.

Task 파일은 Agent 실행 지시의 source of truth다. `task_board.md`, report, QA 문서는 Task 파일을 보조한다.

`status: proposed` 상태의 Task는 아직 승인되지 않은 후보이므로 `approved_by`를 비워둔다. 사용자 또는 Product Owner가 진행을 승인하면 PM Agent가 `status: approved`와 `approved_by`를 함께 갱신한다.

## 2. 템플릿

| 파일 | 용도 |
|---|---|
| `task.md` | 일반 Task 파일 템플릿 |

## 3. 파일명 규칙

```text
T-YYYYMMDD-001_task-slug.md
```

## 4. 변경 이력

| 날짜 | 변경 내용 |
|---|---|
| 2026-06-29 | Task 템플릿 v1 작성 |
| 2026-06-29 | 승인 전 Task의 `approved_by` 기본값 기준 추가 |

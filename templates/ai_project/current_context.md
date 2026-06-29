# Current Agent Context

작성일: {{DATE}}  
프로젝트: {{PROJECT_NAME}}  
상태: Draft

## 1. 목적

이 문서는 Agent가 세션을 시작하거나 재개할 때 가장 먼저 확인할 현재 운영 컨텍스트를 요약한다.

실제 실행 지시는 `.ai_project/tasks/`의 Task 파일을 기준으로 한다. 이 문서는 현재 초점과 주의사항을 빠르게 파악하기 위한 안내판이다.

## 2. 현재 운영 상태

| 항목 | 값 |
|---|---|
| 현재 운영 모드 | {{OPS_MODE}} |
| 활성 Agent | PM Agent, Development Agent, QA Agent |
| 현재 우선 Task | {{CURRENT_TASK_ID}} |
| 다음 확인 위치 | `.ai_project/tasks/` |
| Lock timeout | 240분 |

## 3. 현재 주의사항

- 

## 4. 세션 시작 체크

1. `.ai/workflow.md`를 확인한다.
2. `.ai/task_queue.md`를 확인한다.
3. 이 문서를 확인한다.
4. `.ai_project/tasks/`에서 자신의 역할 또는 capability와 맞는 Task를 확인한다.
5. Task의 `status`, `approved_by`, `depends_on`, `locked_by`, `allowed_paths`, `source_of_truth`를 확인한 뒤 진행한다.
6. 실행 전 lock을 획득하고 하나의 Task만 진행한다.

## 5. 변경 이력

| 날짜 | 변경 내용 |
|---|---|
| {{DATE}} | 현재 Agent 컨텍스트 문서 초기화 |

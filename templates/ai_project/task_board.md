# Project Task Board Summary

작성일: {{DATE}}  
프로젝트: {{PROJECT_NAME}}

## 1. 목적

이 문서는 `.ai_project/tasks/`의 Task Queue를 요약하는 보드다.

실제 실행 지시와 상태 source of truth는 각 Task 파일이다. 이 문서는 현재 초점, 차단 항목, 최근 활동을 빠르게 확인하기 위해 사용한다.

## 2. Current Focus

| 우선순위 | Task ID | 상태 | 제목 | 담당 Agent | 담당 Role | Team | Lock | 다음 조치 |
|---|---|---|---|---|---|---|---|---|
| 1 | {{CURRENT_TASK_ID}} | {{STATUS}} | {{TASK_TITLE}} | {{TARGET_AGENT}} | {{TARGET_ROLE}} | {{TEAM}} | {{LOCKED_BY}} | {{NEXT_ACTION}} |

## 3. Queue Summary

| 상태 | 개수 | 비고 |
|---|---:|---|
| proposed | 0 | |
| scoped | 0 | |
| approved | 0 | |
| in_progress | 0 | |
| verification_ready | 0 | |
| verification_in_progress | 0 | |
| verification_passed | 0 | |
| completion_review | 0 | |
| rework_requested | 0 | |
| blocked | 0 | |
| done | 0 | |
| cancelled | 0 | |

## 4. Team Summary

| Team | Active | Blocked | In Verification | Lead Attention | 비고 |
|---|---:|---:|---:|---|---|
| {{TEAM_NAME}} | 0 | 0 | 0 |  | {{TEAM_STATUS}} |

## 5. Role Summary

| Role | 확인할 상태 | 대기 Task | 다음 조치 |
|---|---|---:|---|
| Direction Role | proposed, scoped, blocked, completion_review | 0 | |
| Lead Role | proposed, rework_requested, blocked | 0 | |
| Execution Role | approved, in_progress | 0 | |
| Verification Role | verification_ready, verification_in_progress | 0 | |
| Completion Role | verification_passed, completion_review | 0 | |
| Ops Governance Role | ops issues | 0 | |

## 6. Blockers

| Task ID | 차단 사유 | 필요한 결정/조치 | 담당 | 의존성 |
|---|---|---|---|---|
|  |  |  |  |  |

## 7. Active Locks

| Task ID | locked_by | locked_at | lock_session | 조치 |
|---|---|---|---|---|
|  |  |  |  |  |

## 8. Ownership / Coordination

| 항목 | 관련 Task | Owner / Lead | 상태 | 필요한 조치 |
|---|---|---|---|---|
|  |  |  |  |  |

## 9. Recent Activity

| 날짜 | Agent | 내용 | 결과 |
|---|---|---|---|
| {{DATE}} | {{OPS_AGENT}} | 프로젝트 AI 운영 초기화 | 진행 중 |

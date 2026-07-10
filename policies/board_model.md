# Board Model

작성일: 2026-07-09  
상태: Draft vNext  
범위: 조직형 AI Agent 운영체계의 project board / team board / coordination view 기준

## 1. 목적

이 문서는 `ai-agent-ops` vNext에서 Task Board의 역할과 구조를 정의한다.

Board는 Task Queue의 요약판이다. 실행 지시, 상태, 라우팅, 승인, lock의 source of truth는 항상 Task 파일이다.

## 2. 기본 원칙

- Task 파일이 source of truth다.
- Board는 요약, 탐색, 우선순위 확인, 차단 현황 확인을 위한 view다.
- Board는 Task 파일을 대체하지 않는다.
- Board와 Task 파일이 충돌하면 Task 파일을 우선한다.
- Board는 Agent에게 "무엇을 볼지"를 안내하지만, 실행 가능 여부는 Task metadata로 판단한다.
- 초기에는 단일 project board를 유지한다.
- Team이 늘어나면 team board를 추가할 수 있다.

## 3. Board 계층

vNext board 계층은 아래처럼 확장할 수 있다.

```text
.ai_project/
  task_board.md
  teams/
    ios/
      team_context.md
      task_board.md
    android/
      team_context.md
      task_board.md
    web/
      team_context.md
      task_board.md
    backend/
      team_context.md
      task_board.md
```

초기에는 아래 하나만 사용한다.

```text
.ai_project/task_board.md
```

## 4. Project Board

Project board는 전체 운영 관점의 요약판이다.

기본 위치:

```text
.ai_project/task_board.md
```

목적:

- 전체 Task Queue 상태 요약
- 현재 focus Task 표시
- blocked Task 확인
- active lock 확인
- Role / Team별 다음 조치 확인
- Product Owner 또는 Direction Role이 전체 흐름을 파악

Project board에 포함할 정보:

```text
Current Focus
Queue Summary
Team Summary
Role Summary
Blockers
Active Locks
Cross-Team / Ownership Conflicts
Recent Activity
```

Project board는 모든 Task의 상세 내용을 복제하지 않는다. 상세 실행 지시는 Task 파일을 링크하거나 Task ID로 참조한다.

## 5. Team Board

Team board는 특정 Team의 실행 관점 요약판이다.

예시 위치:

```text
.ai_project/teams/ios/task_board.md
```

목적:

- Team이 맡은 active Task 확인
- Team ownership 영역의 blocked/rework 확인
- Team Lead가 scope, dependency, 병렬 작업을 조율
- 같은 Team 내 Execution / Verification / Completion Role 인계 확인

Team board에 포함할 정보:

```text
Team Focus
Team Queue Summary
Ownership Areas
In Progress
Verification Ready
Blocked / Rework
Dependencies
Parallel Groups
Recent Team Activity
```

Team board도 Task 파일을 대체하지 않는다.

## 6. Board와 Task 파일의 관계

충돌 시 우선순위:

1. Task 파일
2. `.ai_project/source_of_truth.md`에 지정된 프로젝트 문서
3. Project board
4. Team board
5. 보고서 / QA 문서

Board는 Task 파일의 상태를 요약해야 한다.

Board에 기록된 status, target_agent, target_role, priority, lock이 Task 파일과 다르면 board를 수정한다. Task 파일을 board에 맞춰 고치지 않는다.

## 7. Board 상태 요약

Board는 vNext 상태 체계를 기준으로 요약한다.

```text
proposed
scoped
approved
in_progress
verification_ready
verification_in_progress
verification_passed
completion_review
rework_requested
blocked
done
cancelled
```

Project board는 전체 상태 개수를 보여준다.

Team board는 해당 Team의 상태 개수를 보여준다.

## 8. Role Summary

Board는 Role 기준으로 다음 작업을 보여줄 수 있다.

예시:

| Role | 확인할 상태 | 목적 |
|---|---|---|
| Direction Role | `proposed`, `scoped`, `blocked`, `completion_review` | 승인, 우선순위, 완료 판단 |
| Lead Role | `proposed`, `rework_requested`, `blocked` | scope, ownership, dependency 조율 |
| Execution Role | `approved`, `in_progress` | 실행과 보고 |
| Verification Role | `verification_ready`, `verification_in_progress` | 검증과 rework 판단 |
| Completion Role | `verification_passed`, `completion_review` | 완료 확정 |
| Ops Governance Role | 운영 이슈, workflow 충돌 | 운영체계 개선 |

Board의 Role Summary는 안내용이다. 실제 실행 가능 여부는 Task의 `workflow`, `status`, `target_agent`, `target_role`, `required_capabilities` 조합으로 판단한다.

## 9. Team Summary

Project board는 Team별 요약을 제공할 수 있다.

예시:

| Team | Active | Blocked | In Verification | Lead Attention | 비고 |
|---|---:|---:|---:|---|---|
| iOS Team | 3 | 1 | 1 | ownership conflict | Auth area |
| Android Team | 0 | 0 | 0 | none | planned |
| Backend Team | 1 | 0 | 0 | API contract review | planned |

Team Summary는 전체 흐름을 보기 위한 것이다. 상세 실행은 team board 또는 Task 파일에서 확인한다.

## 10. Ownership / Coordination View

Board는 ownership과 coordination 이슈를 별도로 드러내야 한다.

권장 항목:

```text
Ownership Conflicts
Cross-Team Reviews
Parallel Groups
Blocked Dependencies
Release / Migration Gates
```

예시:

| 항목 | 관련 Task | Owner / Lead | 상태 | 필요한 조치 |
|---|---|---|---|---|
| Ownership overlap | T-001, T-002 | {{TEAM_LEAD}} | blocked | 순서 결정 |
| API contract review | T-003 | {{REVIEWER}} | scoped | reviewer 확인 |
| release gate | T-004 | Release Role | completion_review | 승인 필요 |

## 11. Board 갱신 책임

Board 갱신은 Task 상태 전이와 함께 수행한다.

기본 책임:

| 변경 | 갱신 주체 |
|---|---|
| Task 생성 | Direction Role |
| `proposed -> scoped` | Lead Role |
| `scoped -> approved` | Direction Role |
| `approved -> in_progress` | Execution Role |
| `in_progress -> verification_ready` | Execution Role |
| `verification_ready -> verification_in_progress` | Verification Role |
| `verification_in_progress -> verification_passed` | Verification Role |
| `verification_passed -> completion_review` | Completion Role |
| `completion_review -> done` | Completion Role |
| `blocked` / `rework_requested` | 현재 담당 Role 또는 Lead Role |

단, Board 갱신 누락이 Task 상태 전이를 무효화하지 않는다. Task 파일이 우선이다.

## 12. Team Board 추가 기준

Team board는 아래 조건 중 하나 이상일 때 추가한다.

- Team별 active Task가 반복적으로 3개 이상 유지된다.
- Team Lead가 별도 execution view를 필요로 한다.
- 같은 Project board에서 여러 Team의 Task가 섞여 가독성이 떨어진다.
- ownership conflict 또는 parallel group이 Team 단위로 자주 발생한다.
- iOS / Android / Web / Backend처럼 플랫폼 Team이 분리된다.

Team board를 추가할 때는 아래를 함께 정리한다.

- Team 이름
- Team context 위치
- Team board 위치
- Project board와의 동기화 방식
- Team board가 요약할 Task 필터 기준

## 13. Team Board 필터 기준

Team board는 아래 조건 중 하나 이상에 해당하는 Task를 표시한다.

- `team`이 해당 Team이다.
- `team_lead`가 해당 Team Lead다.
- ownership 영역이 해당 Team이다.
- cross-team review에 해당 Team이 포함된다.
- 해당 Team의 source of truth 문서를 수정한다.

Team board는 다른 Team의 Task를 임의로 숨기기 위한 문서가 아니다. 해당 Team의 실행과 조율에 필요한 view다.

## 14. Board Template 권장 구조

Project board 권장 구조:

```text
1. Current Focus
2. Queue Summary
3. Team Summary
4. Role Summary
5. Blockers
6. Active Locks
7. Ownership / Coordination
8. Recent Activity
```

Team board 권장 구조:

```text
1. Team Focus
2. Team Queue Summary
3. Ownership Areas
4. Active Tasks
5. Verification Queue
6. Blocked / Rework
7. Dependencies / Parallel Groups
8. Recent Team Activity
```

## 15. 금지사항

- Board를 Task 파일 대신 실행 지시로 사용하지 않는다.
- Board의 status만 보고 Task를 실행하지 않는다.
- Board와 Task 파일이 다를 때 Task 파일을 확인하지 않고 상태 전이를 수행하지 않는다.
- Team board를 별도 Task Queue로 취급하지 않는다.
- 완료된 Task의 source of truth를 board 내용으로 대체하지 않는다.
- Board 갱신을 이유로 승인, 검증, 완료 단계를 건너뛰지 않는다.

## 16. 변경 이력

| 날짜 | 변경 내용 |
|---|---|
| 2026-07-09 | 조직형 AI Agent 운영체계의 board 모델 초안 작성 |

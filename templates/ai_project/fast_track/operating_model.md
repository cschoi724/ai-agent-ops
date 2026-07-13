# Project Operating Model

작성일: {{DATE}}
프로젝트: {{PROJECT_NAME}}
상태: Active

## 1. 목적

{{PROJECT_PURPOSE}}

## 2. Bootstrap Summary

| 항목 | 선택값 |
|---|---|
| bootstrap_mode | `fast_track` |
| start_context | {{START_CONTEXT}} |
| readiness_level | {{READINESS_LEVEL}} |
| operating_mode | `solo_light` |
| team_pattern | `single_team` |
| workflow_policy | `skip_scoped_for_simple_tasks` |
| ownership_model | `path_plus_domain` |
| coordination | `single_active_task` |
| board_model | `project_board_only` |
| branch_pr | `pending_decision` |
| release_role | `inactive` |

## 3. Active Organization

```text
{{PROJECT_NAME}}
  {{TEAM_NAME}}
  AI Ops Governance
```

## 4. Active Roles

| Role | 상태 | 담당 | 책임 |
|---|---|---|---|
| Direction Role | active | {{DIRECTION_AGENT}} | 목적, 우선순위, 승인 |
| Lead Role | active | {{LEAD_AGENT}} | 범위, ownership, dependency, 완료 판단 |
| Ops Governance Role | active | AI Ops Agent | 운영모델과 workflow 점검 |
| Execution Role | deferred | {{EXECUTION_AGENT}} | 구현 가능한 Task가 생기면 활성 |
| Verification Role | deferred | {{VERIFICATION_AGENT}} | 검증 가능한 산출물이 생기면 활성 |
| Release Role | inactive | 없음 | 실제 배포 책임 발생 시 검토 |

## 5. Current Focus

{{CURRENT_FOCUS}}

## 6. Open Questions

| 질문 | 상태 | 결정 시점 |
|---|---|---|
| {{OPEN_QUESTION}} | unresolved | {{DECISION_TIMING}} |

## 7. Expansion Triggers

아래 조건이 생기면 Guided Full 문서를 추가한다.

- 구현 Task가 반복된다.
- Execution / Verification Role을 분리해야 한다.
- Git branch / PR 전략이 필요하다.
- Team 또는 ownership 충돌이 생긴다.
- release / deployment 책임이 생긴다.

# Project Operating Model

작성일: {{DATE}}  
프로젝트: {{PROJECT_NAME}}  
상태: Draft

## 1. 목적

이 문서는 현재 프로젝트에서 실제로 선택한 AI Agent 운영 구성을 기록한다.

일반 정책은 `.ai/`의 헌법과 모델 문서를 따른다. 이 문서는 프로젝트별 선택값과 활성 구성을 기록한다.

## 2. General Policy References

| 영역 | 일반 정책 |
|---|---|
| 헌법 | `.ai/core/constitution.md` |
| 조직 모델 | `.ai/models/org_model.md` |
| Team 모델 | `.ai/models/team_model.md` |
| Role 모델 | `.ai/models/role_model.md` |
| Ownership | `.ai/policies/ownership_model.md` |
| Coordination | `.ai/policies/coordination_policy.md` |
| Board | `.ai/policies/board_model.md` |
| Branch / PR | `.ai/policies/branch_pr_policy.md` |
| Task Queue | `.ai/runtime/task_queue.md` |

## 3. Start Context

| 항목 | 선택값 |
|---|---|
| start_context | {{START_CONTEXT}} |
| readiness_level | {{READINESS_LEVEL}} |
| start_context_summary | {{START_CONTEXT_SUMMARY}} |

선택 후보:

```text
new_project_with_requirement
assigned_or_existing_project
blank_slate_discovery
rescue_or_recovery
migration_or_modernization
ops_setup_only
scale_up_existing_ops
custom_start_context
```

Readiness 후보:

```text
idea_only
idea_structured
planning_ready
implementation_ready
existing_project_scan_required
discovery_required
recovery_required
ops_only
```

## 4. Selected Operating Mode

| 항목 | 선택값 |
|---|---|
| operating_mode | {{OPERATING_MODE}} |
| description | {{OPERATING_MODE_DESCRIPTION}} |

선택 후보:

```text
solo_light
team_basic
team_pr
multi_team
enterprise
```

## 5. Organization / Team Configuration

```text
{{PROJECT_ORG_STRUCTURE}}
```

예시:

```text
AI Agent Ops Organization
  Development Division
    {{TEAM_NAME}}
  AI Ops Division
```

## 6. Active Teams

| Team | Team ID | 상태 | Pattern | Lead | Team Context | 비고 |
|---|---|---|---|---|---|---|
| {{TEAM_NAME}} | {{TEAM_ID}} | active | {{TEAM_PATTERN}} | {{TEAM_LEAD}} | `.ai_project/teams/{{TEAM_ID}}/team_context.md` | |

## 7. Role / Agent Mapping

| Agent | Role | Capabilities | 비고 |
|---|---|---|---|
| {{LEAD_AGENT}} | Lead Role | team_coordination, ownership_review, dependency_management, merge_coordination | |
| {{EXECUTION_AGENT}} | Execution Role | implementation, developer_verification, task_reporting, branch_management, pr_creation | |
| {{VERIFICATION_AGENT}} | Verification Role | qa_review, pr_review, ci_check, test_execution, risk_review | |
| {{OPS_AGENT}} | Ops Governance Role | process_governance, workflow_governance, ops_migration | |

## 8. Workflow / State Configuration

| 항목 | 선택값 |
|---|---|
| state_model | standard_vnext |
| scoped_required | {{SCOPED_REQUIRED}} |
| workflow_overrides | `.ai_project/workflow_overrides.md` |

기본 상태 흐름:

```text
proposed -> scoped -> approved -> in_progress -> verification_ready -> verification_in_progress -> verification_passed -> completion_review -> done
```

## 9. Ownership / Coordination Configuration

| 항목 | 선택값 |
|---|---|
| ownership_model | {{OWNERSHIP_MODEL}} |
| parallel_control | {{PARALLEL_CONTROL}} |
| ownership_doc | {{OWNERSHIP_DOC}} |

선택 후보:

```text
path_only
path_plus_domain
document_ownership
strict_parallel_control
```

## 10. Board Configuration

| 항목 | 선택값 |
|---|---|
| board_model | {{BOARD_MODEL}} |
| project_board | `.ai_project/task_board.md` |
| team_boards | {{TEAM_BOARDS}} |

선택 후보:

```text
project_board_only
project_plus_team_board
custom_views
```

## 11. Branch / PR Configuration

| 항목 | 선택값 |
|---|---|
| branch_pr_strategy | `.ai_project/branch_pr_strategy.md` |
| model | {{BRANCH_STRATEGY_MODEL}} |
| merge_owner | {{MERGE_OWNER}} |
| team_override_allowed | {{TEAM_BRANCH_OVERRIDE_ALLOWED}} |

## 12. Source of Truth

| 영역 | 기준 문서 |
|---|---|
| 현재 상태 | {{CURRENT_STATUS_DOC}} |
| 구현 계획 | {{IMPLEMENTATION_PLAN_DOC}} |
| 아키텍처 | {{ARCHITECTURE_DOC}} |
| 결정 기록 | {{DECISIONS_DOC}} |
| 변경 이력 | {{CHANGELOG_DOC}} |

세부 기준은 `.ai_project/source_of_truth.md`를 따른다.

## 13. Bootstrap Decisions

| 항목 | 선택값 | 결정자 | 날짜 |
|---|---|---|---|
| Start Context | {{START_CONTEXT}} | {{APPROVER}} | {{DATE}} |
| Readiness Level | {{READINESS_LEVEL}} | {{APPROVER}} | {{DATE}} |
| 운영 모드 | {{OPERATING_MODE}} | {{APPROVER}} | {{DATE}} |
| Team 구성 | {{TEAM_SELECTION}} | {{APPROVER}} | {{DATE}} |
| Role 매핑 | {{ROLE_MAPPING_SELECTION}} | {{APPROVER}} | {{DATE}} |
| Branch / PR 전략 | {{BRANCH_STRATEGY_MODEL}} | {{APPROVER}} | {{DATE}} |
| Board 모델 | {{BOARD_MODEL}} | {{APPROVER}} | {{DATE}} |
| Source of Truth | {{SOURCE_OF_TRUTH_SELECTION}} | {{APPROVER}} | {{DATE}} |

## 14. Open Configuration Questions

| 질문 | 상태 | 결정 필요 시점 |
|---|---|---|
|  |  |  |

## 15. 변경 이력

| 날짜 | 변경 내용 |
|---|---|
| {{DATE}} | 프로젝트 운영 모델 초기 구성 |
| {{DATE}} | Team context, branch override, source of truth 선택 기록 기준 추가 |
| {{DATE}} | Start Context와 Readiness Level 기록 기준 추가 |

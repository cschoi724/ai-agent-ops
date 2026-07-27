# AI Ops Migration Plan

작성일: {{DATE}}
프로젝트: {{PROJECT_NAME}}
상태: Draft

## Purpose

이 문서는 현재 프로젝트에 AI Ops를 도입하거나 기존 운영 프로젝트를 새 core 기준으로 갱신하기 위한 승인용 계획이다.

Migration은 `.ai/bootstrap/migration_runbook.md`와 `.ai/policies/migration_policy.md`를 따른다. Discovery Phase에서는 파일을 수정하지 않고, Apply Phase는 승인된 운영 파일 범위 안에서만 진행한다.

## Current Scan

```text
{{PROJECT_STRUCTURE_SUMMARY}}
```

## Selected Context

| 항목 | 선택값 |
|---|---|
| start_context | {{START_CONTEXT}} |
| readiness_level | {{READINESS_LEVEL}} |
| recommended_next_phase | {{RECOMMENDED_NEXT_PHASE}} |
| execution_ready | yes / no |
| verification_ready | yes / no |

## Apply Scope

| 범위 | 처리 |
|---|---|
| `.ai/` | {{AI_INSTALL_ACTION}} |
| `.ai_project/` | create/update operating files |
| product code | not touched without separate task |
| product docs | source mapping only unless approved |
| Git push/PR/merge | not allowed in migration apply |

## Source Mapping

| 영역 | 기준 문서 | 상태 |
|---|---|---|
| 현재 상태 | {{CURRENT_STATUS_DOC}} | {{STATUS}} |
| 구현 계획 | {{IMPLEMENTATION_PLAN_DOC}} | {{STATUS}} |
| 아키텍처 | {{ARCHITECTURE_DOC}} | {{STATUS}} |
| 결정사항 | {{DECISIONS_DOC}} | {{STATUS}} |
| 변경 이력 | {{CHANGELOG_DOC}} | {{STATUS}} |

## Backup / Rollback

| 대상 | 백업 위치 | 롤백 조건 |
|---|---|---|
| {{TARGET}} | {{BACKUP_PATH}} | {{ROLLBACK_CONDITION}} |

## User Decisions

| 결정 항목 | 권장안 | 확정값 |
|---|---|---|
| operating_mode | {{OPERATING_MODE_RECOMMENDATION}} | {{OPERATING_MODE}} |
| team_pattern | {{TEAM_PATTERN_RECOMMENDATION}} | {{TEAM_PATTERN}} |
| workflow_policy | {{WORKFLOW_RECOMMENDATION}} | {{WORKFLOW_POLICY}} |
| branch_pr | {{BRANCH_PR_RECOMMENDATION}} | {{BRANCH_STRATEGY_MODEL}} |
| first pilot task | {{FIRST_TASK_RECOMMENDATION}} | {{FIRST_TASK_DECISION}} |

## Risks

| 리스크 | 대응 |
|---|---|
| 운영 지침 충돌 | 병합안 작성 후 승인 |
| source of truth 미정 | unresolved로 기록하고 Lead/Direction 결정 |
| 코드/빌드 영향 | 별도 제품 Task로 분리 |

## Apply Record

| 날짜 | core_version | 적용 범위 | 검증 결과 |
|---|---|---|---|
|  |  |  |  |

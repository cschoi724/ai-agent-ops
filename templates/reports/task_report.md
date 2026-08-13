# Task Report

report_type: task_report  
작성일: {{DATE}}  
작성 Agent: {{COMPLETED_BY}}  
작성 Role: {{COMPLETED_ROLE}}  
대상 Task ID: {{TASK_ID}}  
대상 Task: {{TASK_NAME}}  
Workflow: {{WORKFLOW}}  
현재 상태: {{STATUS}}  
현재 target_agent: {{TARGET_AGENT}}  
현재 target_role: {{TARGET_ROLE}}  
Team: {{TEAM}}  
Active Capabilities: {{ACTIVE_CAPABILITIES}}

## Source Task

```text
{{TASK_FILE_PATH}}
```

## Summary

-

## Scope

| 항목 | 값 |
|---|---|
| org_unit | {{ORG_UNIT}} |
| team | {{TEAM}} |
| allowed_paths | {{ALLOWED_PATHS}} |
| source_of_truth | {{SOURCE_OF_TRUTH}} |

## Changed Files

-

## Decisions

-

## Verification

| 명령/항목 | 결과 | 비고 |
|---|---|---|
|  |  |  |

## Skipped Verification

-

## Risks

-

## Transition Receipt

상태 전이 시 `templates/reports/transition_receipt.json` 형식의 receipt를 생성하고 아래에는 경로만 남긴다.

- Receipt path:
- 상세 근거가 필요한 경우 이 보고서의 Verification, Risks, Role-Specific Notes를 receipt의 evidence에서 참조한다.

## Role-Specific Notes

Lead Role이 작성한 경우:

- Scope Result:
- Ownership / Dependency Notes:
- Decision Needed:

Execution Role이 작성한 경우:

- Implementation Details:
- Developer Verification:
- Verification Handoff:

Verification Role이 작성한 경우:

- Verification Result:
- Risk Notes:
- Rework Needed:

Ops Governance Role이 작성한 경우:

- Process Issue:
- Rule Impact:
- Recommended Ops Change:

# LangGraph Adapter Draft

목표는 AI Ops의 repo-native 운영 상태를 LangGraph 상태 그래프로 변환할 수 있는 입력 계약을 제공하는 것이다.

## Input

```bash
aiops export runtime --output .ai_project/runtime_export.json
```

## Suggested Mapping

| AI Ops Export | LangGraph Concept |
|---|---|
| `tasks[]` | graph state item 또는 work item |
| `tasks[].status` | state reducer가 관리하는 workflow state |
| `tasks[].target_role` | next node routing key |
| `tasks[].depends_on` / `blocks` | graph edge 후보 |
| `handoffs[]` | node-to-node handoff payload |
| `approval_checkpoints[]` | interrupt/checkpoint 후보 |

## Guardrail

- LangGraph node는 AI Ops Task의 `allowed_paths`, `source_of_truth`, `target_role`을 입력 guardrail로 읽는다.
- 상태 전이는 AI Ops의 `runtime/workflow.md`와 `aiops task transition` 결과를 기준으로 동기화한다.
- AI Ops export는 runtime checkpoint 저장소가 아니다. LangGraph checkpoint는 LangGraph 쪽에서 별도로 관리한다.

## Not Implemented Yet

- LangGraph package dependency
- graph builder code
- tool execution policy
- durable checkpoint adapter

# OpenAI Agents SDK Adapter Draft

목표는 AI Ops의 Role, Task, Handoff, 승인 지점을 OpenAI Agents SDK 스타일의 agent/handoff/guardrail 구성으로 변환할 수 있는 입력 계약을 제공하는 것이다.

## Input

```bash
aiops export runtime --output .ai_project/runtime_export.json
```

## Suggested Mapping

| AI Ops Export | Agents SDK Concept |
|---|---|
| `agents[]` | Agent definition 후보 |
| `agents[].roles` | Agent instructions 또는 routing capability |
| `tasks[]` | run input 또는 work queue item |
| `tasks[].allowed_paths` | guardrail context |
| `tasks[].source_of_truth` | retrieval/context input |
| `handoffs[]` | handoff input/output contract |
| `approval_checkpoints[]` | human approval gate 후보 |

## Guardrail

- Agent는 `target_role`이 자신의 Role과 맞는 Task만 처리한다.
- Tool 실행 전 `allowed_paths`와 `source_of_truth`를 확인한다.
- Handoff는 `aiops handoff create`로 기록된 payload를 기준으로 다음 Agent 입력을 만든다.
- 승인, 배포, merge 같은 행위는 export만으로 자동 실행하지 않는다.

## Not Implemented Yet

- Agents SDK package dependency
- actual Agent object generation
- tool runtime execution
- tracing/session persistence integration

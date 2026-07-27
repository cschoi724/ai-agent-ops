# Runtime Adapters

`adapters/`는 AI Ops 운영 상태를 외부 Agent runtime으로 넘기기 위한 연결 계약을 정리한다.

AI Ops는 현재 runtime engine이 아니다. Task, Role, 상태, 인계, 승인 지점을 repo-native 문서와 CLI로 관리하고, 필요할 때 외부 runtime이 읽을 수 있는 snapshot을 export한다.

## Export

```bash
aiops export runtime
aiops export runtime --output .ai_project/runtime_export.json
```

Export에는 아래 정보가 포함된다.

- task graph: `tasks[].depends_on`, `tasks[].blocks`
- role assignment: `tasks[].target_role`, `agents[].roles`
- state transitions: `tasks[].status`
- handoff events: `.ai_project/handoffs/*.md`
- approval checkpoints: 승인, 완료, 차단, 재작업 관련 상태

## Boundary

- AI Ops는 LangGraph, OpenAI Agents SDK, AutoGen 같은 runtime을 직접 실행하지 않는다.
- 외부 runtime은 export를 입력으로 받아 자신의 graph/checkpoint/tool runtime으로 변환한다.
- 실제 tool 권한, 병렬 실행, durable checkpoint는 외부 runtime 책임이다.

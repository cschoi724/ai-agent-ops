# Tool Adapters

`templates/tool_adapters/`는 Agent 실행 환경별 진입 지침 템플릿을 담는다.

| Adapter | 생성 파일 | 용도 |
|---|---|---|
| `codex` | `AGENTS.md` | Codex 프로젝트 진입 지침 |
| `claude` | `CLAUDE.md` | Claude 프로젝트 진입 지침 |

CLI 사용:

```bash
aiops seed --adapter codex
aiops seed --adapter claude
aiops seed --adapter both
```

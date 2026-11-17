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

## 공통 원본

`codex/AGENTS.md`와 `claude/CLAUDE.md`는 `_source/adapter.md.erb` 하나에서 생성한다. 두 도구는 도구 이름과 파일 이름만 다르고 운영 규칙은 같다.

- 지침을 바꿀 때는 생성 파일이 아니라 `_source/adapter.md.erb`를 수정한다.
- 수정 후 `ruby scripts/build_adapters.rb`로 두 파일을 다시 생성하고 함께 커밋한다.
- 생성 파일을 커밋하는 이유: `aiops doctor`와 `aiops migrate`가 대상 프로젝트의 어댑터 파일을 템플릿과 바이트 단위로 비교한다.
- `tests/e2e_adapter_parity.sh`와 `aiops release-check`가 생성 파일이 공통 원본과 다르거나 두 어댑터가 도구 이름 이외에서 달라지면 실패한다.

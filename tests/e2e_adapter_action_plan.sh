#!/usr/bin/env sh
set -eu

repo_root="$(CDPATH= cd "$(dirname "$0")/.." && pwd)"

for adapter in codex/AGENTS.md claude/CLAUDE.md; do
  file="$repo_root/templates/tool_adapters/$adapter"
  grep -q '작업 전 Action Plan' "$file" || {
    printf '%s\n' "$adapter missing Action Plan section" >&2
    exit 1
  }
  grep -q 'aiops action plan --role ROLE --task TASK_ID --intends ACTIONS --paths PATHS --json' "$file" || {
    printf '%s\n' "$adapter missing Action Plan command" >&2
    exit 1
  }
  grep -q 'blocked_actions' "$file" || {
    printf '%s\n' "$adapter missing blocked_actions handling" >&2
    exit 1
  }
  grep -q 'requires_user_approval' "$file" || {
    printf '%s\n' "$adapter missing requires_user_approval handling" >&2
    exit 1
  }
done

grep -q '작업 전 Action Plan' "$repo_root/templates/tool_adapters/codex/AGENTS.md" || {
  printf '%s\n' "Codex adapter missing Action Plan section" >&2
  exit 1
}

grep -q '작업 전 Action Plan' "$repo_root/templates/tool_adapters/claude/CLAUDE.md" || {
  printf '%s\n' "Claude adapter missing Action Plan section" >&2
  exit 1
}

grep -q 'Action Plan은 사용자가 직접 매번 입력해야 하는 명령이 아니라' "$repo_root/docs/agent_intent.md" || {
  printf '%s\n' "agent intent missing agent-owned Action Plan guidance" >&2
  exit 1
}

printf '%s\n' "ok: adapter action plan"

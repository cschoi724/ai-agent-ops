#!/usr/bin/env sh
set -eu

repo_root="$(CDPATH= cd "$(dirname "$0")/.." && pwd)"
adapters="$repo_root/templates/tool_adapters"
tmpdir="$(mktemp -d /tmp/aiops-e2e-adapter-parity.XXXXXX)"
trap 'rm -rf "$tmpdir"' EXIT INT TERM

ruby "$repo_root/scripts/build_adapters.rb" --check >/dev/null || {
  printf '%s\n' "adapter files are stale; run ruby scripts/build_adapters.rb" >&2
  exit 1
}

# Both adapters must be identical once tool names and file names are neutralized.
normalize() {
  sed -e 's/Codex/TOOL_A/g; s/Claude/TOOL_A/g; s/AGENTS\.md/ADAPTER_FILE/g; s/CLAUDE\.md/ADAPTER_FILE/g' "$1"
}
normalize "$adapters/codex/AGENTS.md" > "$tmpdir/codex.md"
normalize "$adapters/claude/CLAUDE.md" > "$tmpdir/claude.md"
if ! cmp -s "$tmpdir/codex.md" "$tmpdir/claude.md"; then
  printf '%s\n' "Codex and Claude adapters differ beyond tool names" >&2
  diff "$tmpdir/codex.md" "$tmpdir/claude.md" >&2 || true
  exit 1
fi

# Core operating rules must stay present in every adapter.
for adapter in codex/AGENTS.md claude/CLAUDE.md; do
  file="$adapters/$adapter"
  for rule in \
    '## 7. Execution Role' \
    '## 8. Verification Role' \
    '## 9. Ops Governance Role' \
    '다음 Agent에게 전달할 말' \
    'lock을 획득하고 하나의 Task만 진행한다' \
    '템플릿 저장소인지 실제 적용 대상 프로젝트인지 먼저 구분한다' \
    'Knowledge Mode' \
    'Install Discovery' \
    '작업 전 Action Plan' \
    '사용자 승인 없이 `.ai/` 운영 문서를 수정하지 않는다.'
  do
    grep -qF -- "$rule" "$file" || {
      printf '%s\n' "$adapter is missing rule: $rule" >&2
      exit 1
    }
  done
done

printf '%s\n' "ok: adapter parity"

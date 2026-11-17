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
    '`.ai/` 안의 파일을 만들거나 고치거나 지우지 않는다.' \
    'AIOPS_ALLOW_CORE_COMMIT' \
    'aiops-verification'
  do
    grep -qF -- "$rule" "$file" || {
      printf '%s\n' "$adapter is missing rule: $rule" >&2
      exit 1
    }
  done
done

# Role subagents and skills must exist for both tools with identical instructions.
ruby -e '
  root = ARGV[0]
  claude = Dir.glob(File.join(root, "claude/project_files/dot_claude/agents/*.md")).map { |path| File.basename(path, ".md") }.sort
  codex = Dir.glob(File.join(root, "codex/project_files/dot_codex/agents/*.toml")).map { |path| File.basename(path, ".toml") }.sort
  abort "Role subagents differ: claude=#{claude} codex=#{codex}" unless claude == codex && !claude.empty?
  claude.each do |name|
    claude_body = File.read(File.join(root, "claude/project_files/dot_claude/agents/#{name}.md")).split(/^---\n/, 3)[2].to_s.sub(/\A\n/, "")
    codex_text = File.read(File.join(root, "codex/project_files/dot_codex/agents/#{name}.toml"))
    codex_body = codex_text[/developer_instructions = \x27\x27\x27\n(.*)\x27\x27\x27/m, 1].to_s
    abort "Role subagent #{name} instructions differ between tools" unless claude_body.chomp == codex_body.chomp
  end
  skills = lambda { |dir| Dir.glob(File.join(root, dir, "*", "SKILL.md")).map { |path| [File.basename(File.dirname(path)), File.read(path)] }.sort }
  claude_skills = skills.call("claude/project_files/dot_claude/skills")
  codex_skills = skills.call("codex/project_files/dot_agents/skills")
  abort "skills differ between tools" unless claude_skills == codex_skills && !claude_skills.empty?
' "$adapters" || exit 1

printf '%s\n' "ok: adapter parity"

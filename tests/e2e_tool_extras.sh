#!/usr/bin/env sh
set -eu

repo_root="$(CDPATH= cd "$(dirname "$0")/.." && pwd)"
aiops="$repo_root/bin/aiops"
tmpdir="$(mktemp -d /tmp/aiops-e2e-tool-extras.XXXXXX)"
trap 'rm -rf "$tmpdir"' EXIT INT TERM

fail() {
  printf '%s\n' "$1" >&2
  exit 1
}

roles="aiops-direction aiops-lead aiops-execution aiops-verification aiops-completion"
skills="aiops-status aiops-next aiops-handoff"

# --- both adapters get the same Role subagents, skills, and guard hooks ---
both="$tmpdir/both"
mkdir -p "$both/.claude"
git -C "$both" init -q
cat > "$both/.claude/settings.json" <<'EOF'
{
  "model": "opus",
  "hooks": {
    "PostToolUse": [
      { "matcher": "Bash", "hooks": [{ "type": "command", "command": "echo user-hook" }] }
    ]
  }
}
EOF
"$aiops" seed --target "$both" --adapter both --core "$repo_root" > "$tmpdir/both.out"

for role in $roles; do
  [ -f "$both/.claude/agents/$role.md" ] || fail "missing Claude subagent $role"
  [ -f "$both/.codex/agents/$role.toml" ] || fail "missing Codex subagent $role"
done
for skill in $skills; do
  [ -f "$both/.claude/skills/$skill/SKILL.md" ] || fail "missing Claude skill $skill"
  [ -f "$both/.agents/skills/$skill/SKILL.md" ] || fail "missing Codex skill $skill"
  cmp -s "$both/.claude/skills/$skill/SKILL.md" "$both/.agents/skills/$skill/SKILL.md" || fail "skill $skill differs between tools"
done
[ -f "$both/.codex/hooks.json" ] || fail "missing Codex hooks.json"
grep -q 'Codex에서 /hooks' "$tmpdir/both.out" || fail "seed did not explain Codex hook trust"

ruby -rjson -e '
  claude = JSON.parse(File.read(ARGV[0]))
  abort "user setting lost" unless claude["model"] == "opus"
  abort "user hook lost" unless claude.dig("hooks", "PostToolUse", 0, "hooks", 0, "command") == "echo user-hook"
  guard = Array(claude.dig("hooks", "PreToolUse")).select { |group| group["hooks"].any? { |hook| hook["command"].include?("guard pre-tool-use") } }
  abort "Claude guard hook missing or duplicated" unless guard.length == 1
  codex = JSON.parse(File.read(ARGV[1]))
  abort "Codex guard hook missing" unless codex.dig("hooks", "PreToolUse", 0, "hooks", 0, "command").include?("guard pre-tool-use --provider codex")
' "$both/.claude/settings.json" "$both/.codex/hooks.json" || fail "hook settings merge failed"

# The installed Claude hook command actually blocks .ai/ edits.
hook_command="$(ruby -rjson -e 'puts JSON.parse(File.read(ARGV[0])).dig("hooks", "PreToolUse", 0, "hooks", 0, "command")' "$both/.claude/settings.json")"
set +e
printf '{"tool_name":"Edit","cwd":"%s","tool_input":{"file_path":"%s/.ai/README.md"}}' "$both" "$both" | CLAUDE_PROJECT_DIR="$both" sh -c "$hook_command" >/dev/null 2>&1
status=$?
set -e
[ "$status" -eq 2 ] || fail "installed Claude hook did not block .ai/ edit (exit $status)"

codex_command="$(ruby -rjson -e 'puts JSON.parse(File.read(ARGV[0])).dig("hooks", "PreToolUse", 0, "hooks", 0, "command")' "$both/.codex/hooks.json")"
set +e
printf '{"tool_name":"apply_patch","cwd":"%s","tool_input":{"command":"*** Begin Patch\\n*** Update File: .ai/README.md\\n*** End Patch"}}' "$both" | (cd "$both" && sh -c "$codex_command") >/dev/null 2>&1
status=$?
set -e
[ "$status" -eq 2 ] || fail "installed Codex hook did not block .ai/ patch (exit $status)"

# --- reseeding is idempotent and keeps customized files ---
printf '\ncustom team note\n' >> "$both/.claude/agents/aiops-lead.md"
"$aiops" seed --target "$both" --adapter both --core "$repo_root" > "$tmpdir/reseed.out"
grep -q 'skip: .claude/agents/aiops-lead.md differs' "$tmpdir/reseed.out" || fail "reseed did not report customized subagent"
grep -q 'custom team note' "$both/.claude/agents/aiops-lead.md" || fail "reseed overwrote customized subagent"
grep -q 'ok: .claude/settings.json (AI Ops guard hook present)' "$tmpdir/reseed.out" || fail "reseed rewrote merged settings"
ruby -rjson -e '
  data = JSON.parse(File.read(ARGV[0]))
  count = Array(data.dig("hooks", "PreToolUse")).count { |group| group["hooks"].any? { |hook| hook["command"].include?("guard pre-tool-use") } }
  abort "guard hook duplicated after reseed" unless count == 1
' "$both/.claude/settings.json"

# --- single adapter installs only that tool ---
codex_only="$tmpdir/codex-only"
mkdir -p "$codex_only"
"$aiops" seed --target "$codex_only" --adapter codex --core "$repo_root" >/dev/null
[ -d "$codex_only/.codex/agents" ] || fail "codex seed missing .codex/agents"
[ ! -e "$codex_only/.claude" ] || fail "codex seed created .claude"

# --- opt out ---
plain="$tmpdir/plain"
mkdir -p "$plain"
"$aiops" seed --target "$plain" --adapter both --core "$repo_root" --no-tool-extras > "$tmpdir/plain.out"
grep -q 'skip: tool extras (--no-tool-extras)' "$tmpdir/plain.out" || fail "--no-tool-extras not reported"
[ ! -e "$plain/.claude" ] && [ ! -e "$plain/.codex" ] && [ ! -e "$plain/.agents" ] || fail "--no-tool-extras still installed files"

# --- doctor reports missing extras as notes without failing strict mode for that reason ---
"$aiops" doctor --target "$plain" > "$tmpdir/doctor.out" 2>&1 || true
grep -q 'note: Codex .codex/agents/aiops-lead.toml missing' "$tmpdir/doctor.out" || fail "doctor did not report missing Codex subagent"
grep -q 'note: Claude Code .claude/skills/aiops-status/SKILL.md missing' "$tmpdir/doctor.out" || fail "doctor did not report missing Claude skill"
if grep -q '^warn: .*aiops-' "$tmpdir/doctor.out"; then
  fail "doctor counted missing tool extras as warnings"
fi

printf '%s\n' "ok: tool extras"

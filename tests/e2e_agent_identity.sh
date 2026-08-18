#!/usr/bin/env sh
set -eu

repo_root="$(CDPATH= cd "$(dirname "$0")/.." && pwd)"
tmpdir="$(mktemp -d /tmp/aiops-e2e-agent-identity.XXXXXX)"
trap 'rm -rf "$tmpdir"' EXIT INT TERM

project="$tmpdir/project"
mkdir -p \
  "$project/.ai_project/tasks/active" \
  "$project/.ai_project/tasks/backlog" \
  "$project/.ai_project/tasks/archive"
ln -s "$repo_root" "$project/.ai"

cat > "$project/.ai_project/agent_registry.md" <<'EOF'
---
schema: aiops.agent_registry.v1
project: AgentIdentityFixture
agents:
  - agent: Builder Agent
    status: enabled
    team: Development Team
    roles:
      - Execution Role
    capabilities:
      - implementation
---

# Agent Registry
EOF

cat > "$project/.ai_project/source_of_truth.md" <<'EOF'
# Source of Truth
EOF

write_task() {
  scope="$1"
  task_id="$2"
  status="$3"
  agent="$4"
  cat > "$project/.ai_project/tasks/$scope/$task_id.md" <<EOF
---
schema: aiops.task.v1
id: $task_id
title: Agent identity fixture
status: $status
type: feature
priority: medium
workflow: feature
target_agent: $agent
target_role: Execution Role
required_capabilities:
  - implementation
depends_on: []
blocks: []
allowed_paths:
  - src/
source_of_truth:
  - .ai_project/source_of_truth.md
report_to: .ai_project/reports/${task_id}_task-report.md
---

# Agent identity fixture
EOF
}

write_task active T-20260818-001 approved "Execution Agent"
write_task archive T-20260818-002 done "Retired Agent"

if "$repo_root/bin/aiops" agent inspect --target "$project" --json > "$tmpdir/stale.json"; then
  printf '%s\n' "Agent inspection accepted a stale current reference" >&2
  exit 1
fi
"$repo_root/bin/aiops" validate agent-identity-audit "$tmpdir/stale.json" >/dev/null
ruby -rjson -e '
  data = JSON.parse(File.read(ARGV[0]))
  abort "audit should not be ready" if data["ready"]
  abort "current error count mismatch" unless data.dig("summary", "errors") == 1
  abort "historical warning count mismatch" unless data.dig("summary", "warnings") == 1
  active = data["references"].find { |entry| entry["task_id"] == "T-20260818-001" }
  archive = data["references"].find { |entry| entry["task_id"] == "T-20260818-002" }
  abort "active stale reference missing" unless active && active["scope"] == "active" && active["state"] == "unresolved"
  abort "archive history missing" unless archive && archive["scope"] == "archive" && archive["state"] == "unresolved"
' "$tmpdir/stale.json"

if "$repo_root/bin/aiops" task accept T-20260818-001 \
  --target "$project" --check > "$tmpdir/lifecycle-stale.out" 2>&1; then
  printf '%s\n' "lifecycle accepted a stale current Agent reference" >&2
  exit 1
fi
grep -q 'actor is not registered: Execution Agent' "$tmpdir/lifecycle-stale.out"

perl -0pi -e 's/target_agent: Execution Agent/target_agent: Builder Agent/' \
  "$project/.ai_project/tasks/active/T-20260818-001.md"

"$repo_root/bin/aiops" agent inspect --target "$project" --json > "$tmpdir/ready.json"
"$repo_root/bin/aiops" validate agent-identity-audit "$tmpdir/ready.json" >/dev/null
ruby -rjson -e '
  data = JSON.parse(File.read(ARGV[0]))
  abort "audit should be ready" unless data["ready"]
  abort "current references should be clean" unless data.dig("summary", "errors") == 0
  abort "historical reference should remain a warning" unless data.dig("summary", "warnings") == 1
' "$tmpdir/ready.json"

"$repo_root/bin/aiops" agent inspect --target "$project" > "$tmpdir/ko.out"
"$repo_root/bin/aiops" agent inspect --target "$project" --locale en > "$tmpdir/en.out"
grep -q '^AI Ops Agent 참조 점검$' "$tmpdir/ko.out"
grep -q '^AI Ops Agent reference inspection$' "$tmpdir/en.out"
grep -q 'Builder Agent' "$tmpdir/ready.json"

ruby -rjson -e '
  data = JSON.parse(File.read(ARGV[0]))
  data["ready"] = "yes"
  File.write(ARGV[1], JSON.pretty_generate(data))
' "$tmpdir/ready.json" "$tmpdir/invalid.json"
if "$repo_root/bin/aiops" validate agent-identity-audit "$tmpdir/invalid.json" >/dev/null 2>&1; then
  printf '%s\n' "Agent identity audit validator accepted invalid ready type" >&2
  exit 1
fi

ruby -rjson -e '
  data = JSON.parse(File.read(ARGV[0]))
  data["ready"] = false
  File.write(ARGV[1], JSON.pretty_generate(data))
' "$tmpdir/ready.json" "$tmpdir/invalid-semantics.json"
if "$repo_root/bin/aiops" validate agent-identity-audit "$tmpdir/invalid-semantics.json" >/dev/null 2>&1; then
  printf '%s\n' "Agent identity audit validator accepted inconsistent ready state" >&2
  exit 1
fi

perl -0pi -e 's/(  - agent: Builder Agent.*?      - implementation)/$1\n  - agent: Builder Agent\n    status: enabled\n    team: Other Team\n    roles:\n      - Execution Role\n    capabilities:\n      - implementation/s' \
  "$project/.ai_project/agent_registry.md"

if "$repo_root/bin/aiops" agent inspect --target "$project" --json > "$tmpdir/duplicate.json"; then
  printf '%s\n' "Agent inspection accepted duplicate Agent names" >&2
  exit 1
fi
grep -q 'duplicate_agent_name' "$tmpdir/duplicate.json"
grep -q 'target_agent_ambiguous' "$tmpdir/duplicate.json"

if "$repo_root/bin/aiops" task accept T-20260818-001 \
  --target "$project" --check > "$tmpdir/lifecycle-duplicate.out" 2>&1; then
  printf '%s\n' "lifecycle accepted duplicate Agent names" >&2
  exit 1
fi
grep -q 'agent registry has duplicate Agent name: Builder Agent' "$tmpdir/lifecycle-duplicate.out"

if "$repo_root/bin/aiops" agent inspect --target "$project" --unknown \
  > "$tmpdir/invalid-option.out" 2>&1; then
  printf '%s\n' "Agent inspection accepted an unknown option" >&2
  exit 1
fi
grep -q '^error: agent identity audit failed:' "$tmpdir/invalid-option.out"
if grep -q 'runtime/agent_identity.rb:' "$tmpdir/invalid-option.out"; then
  printf '%s\n' "Agent inspection leaked a Ruby stack trace" >&2
  exit 1
fi

printf '%s\n' "ok: Agent identity reference audit"

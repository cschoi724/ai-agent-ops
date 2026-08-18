#!/usr/bin/env sh
set -eu

repo_root="$(CDPATH= cd "$(dirname "$0")/.." && pwd)"
tmpdir="$(mktemp -d /tmp/aiops-e2e-agent-migration.XXXXXX)"
trap 'rm -rf "$tmpdir"' EXIT INT TERM

project="$tmpdir/project"
mkdir -p "$project/.ai_project/tasks/active" "$project/.ai_project/tasks/backlog" \
  "$project/.ai_project/tasks/archive" "$project/.ai_project/.runtime/agent_identity"
git -C "$project" init -q
ln -s "$repo_root" "$project/.ai"
printf '%s\n' '.ai_project/.runtime/' > "$project/.gitignore"

"$repo_root/bin/aiops" agent rename --help > "$tmpdir/rename-help.txt"
"$repo_root/bin/aiops" agent migrate-identities --help > "$tmpdir/migrate-help.txt"
grep -q -- '--to NAME' "$tmpdir/rename-help.txt"
if grep -q -- '--map NAME=ID' "$tmpdir/rename-help.txt"; then
  printf '%s\n' "rename help exposed migration-only --map" >&2
  exit 1
fi
grep -q -- '--map NAME=ID' "$tmpdir/migrate-help.txt"
if grep -q -- '--to NAME' "$tmpdir/migrate-help.txt"; then
  printf '%s\n' "migration help exposed rename-only --to" >&2
  exit 1
fi

cat > "$project/.ai_project/agent_registry.md" <<'EOF'
---
schema: aiops.agent_registry.v1
project: AgentMigrationFixture
agents:
  - agent: Build Agent
    status: enabled
    team: Development Team
    roles: [Execution Role]
    capabilities: [implementation]
  - agent: Verification Agent
    status: enabled
    team: Quality Team
    roles: [Verification Role]
    capabilities: [qa, validation]
---

# Agent Registry
EOF

write_task() {
  scope="$1"
  task_id="$2"
  agent="$3"
  role="$4"
  cat > "$project/.ai_project/tasks/$scope/$task_id.md" <<EOF
---
schema: aiops.task.v1
id: $task_id
title: Agent identity migration fixture
status: proposed
type: feature
priority: medium
workflow: feature
target_agent: $agent
target_role: $role
required_capabilities: [implementation]
depends_on: []
blocks: []
allowed_paths: [src/]
source_of_truth: [.ai_project/agent_registry.md]
---

# Historical body keeps $agent unchanged.
EOF
}

write_task active T-20260818-301 "Build Agent" "Execution Role"
write_task backlog T-20260818-302 "Verification Agent" "Verification Role"
write_task archive T-20260818-303 "Build Agent" "Execution Role"

git -C "$project" add .gitignore .ai_project
git -C "$project" -c user.name='AI Ops Test' -c user.email='test@example.invalid' commit -q -m fixture

tracked_hash() {
  (cd "$project" && git ls-files -z | xargs -0 shasum -a 256)
}

archive="$project/.ai_project/tasks/archive/T-20260818-303.md"
archive_before="$(shasum -a 256 "$archive" | awk '{print $1}')"
tracked_hash > "$tmpdir/before-check.sha"
"$repo_root/bin/aiops" agent migrate-identities --target "$project" --check --json > "$tmpdir/migrate-plan.json"
tracked_hash > "$tmpdir/after-check.sha"
cmp -s "$tmpdir/before-check.sha" "$tmpdir/after-check.sha"
[ ! -e "$project/.git/aiops-locks/agent-identity-migration.lock" ]
"$repo_root/bin/aiops" validate agent-identity-migration-plan "$tmpdir/migrate-plan.json" >/dev/null
grep -q '"agent_id": "build-agent"' "$tmpdir/migrate-plan.json"
"$repo_root/bin/aiops" agent migrate-identities --target "$project" --check --locale en --json > "$tmpdir/migrate-plan-en.json"
ruby -rjson -e '
  left = JSON.parse(File.read(ARGV[0])); right = JSON.parse(File.read(ARGV[1]))
  left.delete("generated_at"); right.delete("generated_at")
  abort "locale changed migration plan JSON" unless left == right
' "$tmpdir/migrate-plan.json" "$tmpdir/migrate-plan-en.json"

set +e
"$repo_root/bin/aiops" agent migrate-identities --target "$project" --check --json \
  --map 'Build Agent=primary-build' --map 'Build-Agent=BAD_ID' > "$tmpdir/invalid-map.out" 2>&1
invalid_map_status="$?"
set -e
[ "$invalid_map_status" -ne 0 ]
grep -q '^error: invalid mapped Agent ID: BAD_ID$' "$tmpdir/invalid-map.out"
if grep -qE 'agent_identity_migration\.rb:[0-9]+|from .*agent_identity_migration' "$tmpdir/invalid-map.out"; then
  printf '%s\n' "invalid mapping exposed a Ruby stack trace" >&2
  exit 1
fi

"$repo_root/bin/aiops" agent migrate-identities --target "$project" --apply --json > "$tmpdir/migrate-receipt.json"
"$repo_root/bin/aiops" validate agent-identity-migration-receipt "$tmpdir/migrate-receipt.json" >/dev/null
migrate_receipt="$(ruby -rjson -e 'puts JSON.parse(File.read(ARGV[0])).fetch("receipt_path")' "$tmpdir/migrate-receipt.json")"
[ -f "$project/$migrate_receipt" ]
grep -q '^  id: build-agent$' "$project/.ai_project/agent_registry.md"
grep -q '^target_agent_id: build-agent$' "$project/.ai_project/tasks/active/T-20260818-301.md"
grep -q '^target_agent_id: verification-agent$' "$project/.ai_project/tasks/backlog/T-20260818-302.md"
[ "$archive_before" = "$(shasum -a 256 "$archive" | awk '{print $1}')" ]

git -C "$project" add .ai_project
git -C "$project" -c user.name='AI Ops Test' -c user.email='test@example.invalid' commit -q -m migrated

# Failed writes restore both content and permissions.
registry="$project/.ai_project/agent_registry.md"
active="$project/.ai_project/tasks/active/T-20260818-301.md"
chmod 0640 "$registry" "$active"
registry_hash="$(shasum -a 256 "$registry" | awk '{print $1}')"
active_hash="$(shasum -a 256 "$active" | awk '{print $1}')"
set +e
AIOPS_TEST_AGENT_IDENTITY_FAIL=after_first_write \
  "$repo_root/bin/aiops" agent rename build-agent --to "Build Platform Agent" \
  --target "$project" --apply > "$tmpdir/rollback.out" 2>&1
rollback_status="$?"
set -e
[ "$rollback_status" -ne 0 ]
[ "$registry_hash" = "$(shasum -a 256 "$registry" | awk '{print $1}')" ]
[ "$active_hash" = "$(shasum -a 256 "$active" | awk '{print $1}')" ]
[ "$(stat -f '%Lp' "$registry" 2>/dev/null || stat -c '%a' "$registry")" = "640" ]
[ "$(stat -f '%Lp' "$active" 2>/dev/null || stat -c '%a' "$active")" = "640" ]
if find "$project/.ai_project" -name '.aiops-agent-identity-*' -print | grep -q .; then
  printf '%s\n' "Agent identity rollback left temporary files" >&2
  exit 1
fi

# Concurrent apply: one process owns the shared Git lock and the other fails.
AIOPS_TEST_AGENT_IDENTITY_HOLD_SECONDS=2 \
  "$repo_root/bin/aiops" agent rename build-agent --to "Build Platform Agent" \
  --target "$project" --apply --json > "$tmpdir/concurrent-first.json" 2> "$tmpdir/concurrent-first.err" &
first_pid="$!"
sleep 1
set +e
"$repo_root/bin/aiops" agent rename build-agent --to "Build Platform Agent" \
  --target "$project" --apply > "$tmpdir/concurrent-second.out" 2>&1
second_status="$?"
set -e
wait "$first_pid"
[ "$second_status" -ne 0 ]
grep -q 'already running' "$tmpdir/concurrent-second.out"

"$repo_root/bin/aiops" validate agent-rename-receipt "$tmpdir/concurrent-first.json" >/dev/null
rename_receipt="$(ruby -rjson -e 'puts JSON.parse(File.read(ARGV[0])).fetch("receipt_path")' "$tmpdir/concurrent-first.json")"
[ -f "$project/$rename_receipt" ]
grep -q '^- agent: Build Platform Agent$' "$registry"
grep -q '^  - Build Agent$' "$registry"
grep -q '^target_agent: Build Platform Agent$' "$active"
[ "$archive_before" = "$(shasum -a 256 "$archive" | awk '{print $1}')" ]

"$repo_root/bin/aiops" agent rename build-agent --to "Build Platform Agent" --target "$project" --check > "$tmpdir/ko.out"
"$repo_root/bin/aiops" agent rename build-agent --to "Build Platform Agent" --target "$project" --check --locale en > "$tmpdir/en.out"
grep -q '변경 계획' "$tmpdir/ko.out"
grep -q 'identity plan' "$tmpdir/en.out"

# Re-applying the same target name is a no-op and creates no new receipt.
receipt_count_before="$(find "$project/.ai_project/.runtime/agent_identity" -name '*-receipt.json' | wc -l | tr -d ' ')"
"$repo_root/bin/aiops" agent rename build-agent --to "Build Platform Agent" \
  --target "$project" --apply --json > "$tmpdir/idempotent.json"
"$repo_root/bin/aiops" validate agent-rename-receipt "$tmpdir/idempotent.json" >/dev/null
receipt_count_after="$(find "$project/.ai_project/.runtime/agent_identity" -name '*-receipt.json' | wc -l | tr -d ' ')"
[ "$receipt_count_before" = "$receipt_count_after" ]

# Unsafe names and collision-prone migration mappings fail closed.
for unsafe in 'Bad;touch' 'Bad$HOME' 'Bad|Name'; do
  if "$repo_root/bin/aiops" agent rename build-agent --to "$unsafe" --target "$project" --check >/dev/null 2>&1; then
    printf '%s\n' "unsafe Agent name was accepted: $unsafe" >&2
    exit 1
  fi
done
if "$repo_root/bin/aiops" agent migrate-identities --target "$project" --map 'Unknown Agent=unknown-agent' --check >/dev/null 2>&1; then
  printf '%s\n' "mapping for unknown Agent was accepted" >&2
  exit 1
fi

# Action semantic mutations are rejected even when array length remains four.
ruby -rjson -e '
  data = JSON.parse(File.read(ARGV[0]))
  data["actions"][1] = Marshal.load(Marshal.dump(data["actions"][0]))
  File.write(ARGV[1], JSON.pretty_generate(data))
' "$tmpdir/migrate-plan.json" "$tmpdir/duplicate-action.json"
if "$repo_root/bin/aiops" validate agent-identity-migration-plan "$tmpdir/duplicate-action.json" >/dev/null 2>&1; then
  printf '%s\n' "migration plan accepted duplicate actions" >&2
  exit 1
fi
ruby -rjson -e '
  data = JSON.parse(File.read(ARGV[0]))
  data["actions"][1] = Marshal.load(Marshal.dump(data["actions"][0]))
  File.write(ARGV[1], JSON.pretty_generate(data))
' "$tmpdir/concurrent-first.json" "$tmpdir/duplicate-receipt-action.json"
if "$repo_root/bin/aiops" validate agent-rename-receipt "$tmpdir/duplicate-receipt-action.json" >/dev/null 2>&1; then
  printf '%s\n' "rename receipt accepted duplicate actions" >&2
  exit 1
fi

# A project-external Task symlink is never followed for writes.
external="$tmpdir/external-task.md"
cp "$active" "$external"
ln -s "$external" "$project/.ai_project/tasks/active/T-20260818-399.md"
if "$repo_root/bin/aiops" agent rename build-agent --to "Another Name" --target "$project" --check >/dev/null 2>&1; then
  printf '%s\n' "project-external Task symlink was accepted" >&2
  exit 1
fi

# Keep every Tempfile object alive until a large atomic bundle has been validated and renamed.
large="$tmpdir/large-project"
mkdir -p "$large/.ai_project/tasks/active" "$large/.ai_project/.runtime/agent_identity"
git -C "$large" init -q
printf '%s\n' '.ai_project/.runtime/' > "$large/.gitignore"
cat > "$large/.ai_project/agent_registry.md" <<'EOF'
---
schema: aiops.agent_registry.v1
project: LargeAgentMigrationFixture
agents:
  - agent: Build Agent
    status: enabled
    team: Development Team
    roles: [Execution Role]
    capabilities: [implementation]
---
EOF
for number in $(seq 1 81); do
  suffix="$(printf '%03d' "$number")"
  cat > "$large/.ai_project/tasks/active/T-20260818-$suffix.md" <<EOF
---
schema: aiops.task.v1
id: T-20260818-$suffix
title: Large Agent migration fixture $suffix
status: proposed
type: feature
priority: medium
workflow: feature
target_agent: Build Agent
target_role: Execution Role
required_capabilities: [implementation]
depends_on: []
blocks: []
allowed_paths: [src/]
source_of_truth: [.ai_project/agent_registry.md]
---

# Large fixture $suffix
EOF
done
git -C "$large" add .gitignore .ai_project
git -C "$large" -c user.name='AI Ops Test' -c user.email='test@example.invalid' commit -q -m fixture
"$repo_root/bin/aiops" agent migrate-identities --target "$large" --apply --json > "$tmpdir/large-receipt.json"
"$repo_root/bin/aiops" validate agent-identity-migration-receipt "$tmpdir/large-receipt.json" >/dev/null
[ "$(grep -rl '^target_agent_id: build-agent$' "$large/.ai_project/tasks/active" | wc -l | tr -d ' ')" = "81" ]
if find "$large/.ai_project" -name '.aiops-agent-identity-*' -print | grep -q .; then
  printf '%s\n' "large migration left temporary files" >&2
  exit 1
fi

printf '%s\n' "ok: Agent identity rename and migration"

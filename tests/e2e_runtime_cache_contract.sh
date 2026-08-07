#!/usr/bin/env sh
set -eu

repo_root="$(CDPATH= cd "$(dirname "$0")/.." && pwd)"
tmpdir="$(mktemp -d /tmp/aiops-e2e-runtime-cache.XXXXXX)"
trap 'rm -rf "$tmpdir"' EXIT INT TERM

remote="$tmpdir/remote.git"
project="$tmpdir/project"
core_version="$(cat "$repo_root/VERSION")"

git init --bare "$remote" >/dev/null 2>&1
git init -b develop "$project" >/dev/null
git -C "$project" config user.email "aiops@example.test"
git -C "$project" config user.name "AI Ops Test"
git -C "$project" remote add origin "$remote"

ln -s "$repo_root" "$project/.ai"
mkdir -p "$project/.ai_project/tasks/active" "$project/.ai_project/tasks/backlog" "$project/.ai_project/tasks/archive"

for file in current_context.md source_of_truth.md task_board.md ops_decisions.md ops_issues.md agent_registry.md; do
  printf '# %s\n' "$file" > "$project/.ai_project/$file"
done

cat > "$project/.ai_project/operating_model.md" <<EOF
---
schema: aiops.operating_model.v1
project: RuntimeCacheProject
bootstrap_mode: fast_track
core_version: $core_version
core_source: symlink
core_update_policy: manual_review
start_context: assigned_or_existing_project
readiness_level: implementation_ready
operating_mode: team_pr
team_pattern: single_team
workflow_policy: standard_vnext
ownership_model: path_plus_domain
coordination: parallel_with_locks
board_model: project_board_only
branch_pr: pending_decision
canonical_status_ref: origin/develop
knowledge_mode: minimal
release_role: inactive
active_roles: []
deferred_roles: []
---

# Project Operating Model
EOF

git -C "$project" add .ai .ai_project >/dev/null
git -C "$project" commit -m "seed runtime cache fixture" >/dev/null
git -C "$project" push -u origin develop >/dev/null 2>&1

"$repo_root/bin/aiops" sync-status --target "$project" >/tmp/aiops-e2e-runtime-cache-sync.out
grep -q 'recorded: .ai_project/.runtime/status_ref' /tmp/aiops-e2e-runtime-cache-sync.out || {
  printf '%s\n' "sync-status did not record runtime status ref" >&2
  exit 1
}
grep -q 'runtime_cache: local_only' /tmp/aiops-e2e-runtime-cache-sync.out || {
  printf '%s\n' "sync-status did not mark runtime cache local-only" >&2
  exit 1
}
grep -Eq '^\.ai_project/\.runtime/$' "$project/.gitignore" || {
  printf '%s\n' "sync-status did not add runtime cache gitignore rule" >&2
  exit 1
}

if git -C "$project" status --short -- .ai_project/.runtime/status_ref | grep -q .; then
  printf '%s\n' "runtime status ref appeared in git status" >&2
  exit 1
fi

"$repo_root/bin/aiops" project health --target "$project" --json >/tmp/aiops-e2e-runtime-cache-health.json
ruby -rjson -e '
  data = JSON.parse(File.read(ARGV[0]))
  abort("wrong status ref state") unless data.dig("git", "status_ref_state") == "recorded_current"
  abort("wrong multi agent readiness") unless data.dig("readiness", "multi_agent") == "ready"
  abort("unexpected blockers") unless data.dig("summary", "blockers") == 0
' /tmp/aiops-e2e-runtime-cache-health.json

git -C "$project" add .gitignore >/dev/null
git -C "$project" commit -m "ignore runtime cache" >/dev/null
git -C "$project" add -f .ai_project/.runtime/status_ref >/dev/null

"$repo_root/bin/aiops" doctor --target "$project" >/tmp/aiops-e2e-runtime-cache-doctor.out
grep -q 'warn: .ai_project/.runtime/status_ref is tracked' /tmp/aiops-e2e-runtime-cache-doctor.out || {
  printf '%s\n' "doctor did not warn on tracked runtime cache" >&2
  exit 1
}

"$repo_root/bin/aiops" project health --target "$project" --json >/tmp/aiops-e2e-runtime-cache-tracked-health.json
ruby -rjson -e '
  data = JSON.parse(File.read(ARGV[0]))
  ids = data.fetch("checks").map { |check| check["code"] }
  abort("tracked runtime cache warning missing") unless ids.include?("runtime_status_ref_tracked")
' /tmp/aiops-e2e-runtime-cache-tracked-health.json

"$repo_root/bin/aiops" migrate --target "$project" --plan >/tmp/aiops-e2e-runtime-cache-migrate.out
grep -q 'tracked .ai_project/.runtime/status_ref removal' /tmp/aiops-e2e-runtime-cache-migrate.out || {
  printf '%s\n' "migrate plan did not report tracked runtime cache removal" >&2
  exit 1
}

printf '%s\n' "ok: runtime cache contract"

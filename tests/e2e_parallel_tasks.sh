#!/usr/bin/env sh
set -eu

repo_root="$(CDPATH= cd "$(dirname "$0")/.." && pwd)"
aiops="$repo_root/bin/aiops"
tmpdir="$(mktemp -d /tmp/aiops-e2e-parallel.XXXXXX)"
trap 'rm -rf "$tmpdir"' EXIT INT TERM

fail() {
  printf '%s\n' "$1" >&2
  exit 1
}

expect_fail() {
  label="$1"
  pattern="$2"
  shift 2
  if "$@" >"$tmpdir/out.txt" 2>&1; then
    cat "$tmpdir/out.txt" >&2
    fail "$label: expected failure"
  fi
  grep -q -- "$pattern" "$tmpdir/out.txt" || {
    cat "$tmpdir/out.txt" >&2
    fail "$label: missing message '$pattern'"
  }
}

ok() {
  label="$1"
  shift
  "$@" >"$tmpdir/out.txt" 2>&1 || {
    cat "$tmpdir/out.txt" >&2
    fail "$label failed"
  }
}

project="$tmpdir/project"
mkdir -p "$project/.ai_project/tasks/active" "$project/.ai_project/reports" "$project/.ai_project/qa" \
  "$project/.ai_project/handoffs" "$project/src/a" "$project/src/b"
ln -s "$repo_root" "$project/.ai"
printf '# Source of Truth\n' > "$project/.ai_project/source_of_truth.md"
printf 'a\n' > "$project/src/a/a.txt"
printf 'b\n' > "$project/src/b/b.txt"
printf '.ai\n.worktrees/\n.ai_project/\n' > "$project/.gitignore"

cat > "$project/.ai_project/agent_registry.md" <<'EOF'
---
schema: aiops.agent_registry.v1
project: ParallelFixture
agents:
  - agent: Charlie Project Agent
    status: enabled
    team: Silo Charlie
    roles: [Direction Role, Lead Role, Completion Role, Operator Role]
    capabilities: [planning, completion_review]
  - agent: Charlie Execution Agent
    status: enabled
    team: Silo Charlie
    runtime: subagent
    roles: [Execution Role]
    capabilities: [implementation]
  - agent: Charlie Verification Agent
    status: enabled
    team: Silo Charlie
    runtime: subagent
    roles: [Verification Role]
    capabilities: [qa_review]
---

# Agent Registry
EOF

write_model() {
  cat > "$project/.ai_project/operating_model.md" <<EOF
---
schema: aiops.operating_model.v1
parallel_tasks:
  Silo Charlie: $1
---

# Operating Model
EOF
}
write_model 2

git -C "$project" init -q -b main
git -C "$project" -c user.name=t -c user.email=t@example.com add .
git -C "$project" -c user.name=t -c user.email=t@example.com commit -qm init
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@example.com GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@example.com

write_task() {
  task_id="$1"
  status="$2"
  path="$3"
  cat > "$project/.ai_project/tasks/active/$task_id.md" <<EOF
---
schema: aiops.task.v1
id: $task_id
title: Parallel fixture $task_id
status: $status
type: feature
priority: medium
workflow: feature
team: Silo Charlie
target_agent: Charlie Execution Agent
target_role: Execution Role
required_capabilities:
  - implementation
depends_on: []
blocks: []
allowed_paths:
  - $path
source_of_truth:
  - .ai_project/source_of_truth.md
approved_by:
locked_by:
locked_at:
lock_session:
updated_at: 2026-11-18
report_to: .ai_project/reports/${task_id}_task-report.md
qa_to: .ai_project/qa/${task_id}_qa-report.md
---

# Parallel fixture
EOF
}

field() {
  ruby -ryaml -rdate -e 'text = File.read(Dir.glob(File.join(ARGV[0], ".ai_project/tasks/**/#{ARGV[1]}.md")).first); data = YAML.safe_load(text[/\A---\n(.*?)\n---\n/m, 1], permitted_classes: [Date, Time]); value = ARGV[2].split(".").reduce(data) { |d, k| d.is_a?(Hash) ? d[k] : nil }; puts value' "$project" "$1" "$2"
}

a=T-20261118-101
b=T-20261118-102
c=T-20261118-103
write_task "$a" approved src/a
write_task "$b" approved src/b
write_task "$c" approved src/a/deep

# --- parallel Tasks need their own worktree ---
expect_fail "start without worktree" "need their own worktree" \
  "$aiops" task accept "$a" --target "$project" --check
"$aiops" orchestrate plan "$a" --target "$project" --operator "Charlie Project Agent" --json > "$tmpdir/plan.json"
ruby -rjson -e 'plan = JSON.parse(File.read(ARGV[0])); abort "prepare missing" unless plan.dig("next", "prepare") == ["aiops", "worktree", "create", ARGV[1]]' "$tmpdir/plan.json" "$a"
"$aiops" validate orchestration-plan "$tmpdir/plan.json" >/dev/null || fail "plan with prepare should match the schema"

ok "worktree create a" "$aiops" worktree create "$a" --target "$project"
ok "worktree create b" "$aiops" worktree create "$b" --target "$project"
wt_a="$(field "$a" worktree_path)"
wt_b="$(field "$b" worktree_path)"
[ -d "$wt_a" ] && [ -d "$wt_b" ] || fail "Task worktrees were not created"
[ "$(field "$a" branch.name)" = "silo-charlie/$a" ] || fail "Task branch name not recorded"
[ "$(field "$a" branch.base)" = "main" ] || fail "Task base branch not recorded"
[ "$(field "$a" worktree_role)" = "active" ] || fail "worktree_role not active"
ok "worktree create is idempotent" "$aiops" worktree create "$a" --target "$project"

ok "accept a" "$aiops" task accept "$a" --target "$project" --dispatched-by "Charlie Project Agent"
ok "accept b in parallel" "$aiops" task accept "$b" --target "$project" --dispatched-by "Charlie Project Agent"

# --- the team limit and path overlap are enforced ---
ok "worktree create c" "$aiops" worktree create "$c" --target "$project"
expect_fail "third Task over the limit" "limit 2" \
  "$aiops" task accept "$c" --target "$project" --check
write_model 3
expect_fail "overlapping allowed_paths" "allowed_paths overlap with running Task $a" \
  "$aiops" task accept "$c" --target "$project" --check
write_model 2

"$aiops" orchestrate next --operator "Charlie Project Agent" --target "$project" --json > "$tmpdir/next.json"
ruby -rjson -e 'batch = JSON.parse(File.read(ARGV[0])); abort "limit" unless batch["parallel_limit"] == 2 && batch["running"] == 2; abort "start_now should be empty when slots are full" unless batch["start_now"].empty?; abort "tasks" unless batch["tasks"].length == 3' "$tmpdir/next.json"

# --- path checks run inside the Task worktree ---
printf 'outside\n' > "$wt_a/src/b/stray.txt"
printf '# Report\n' > "$project/.ai_project/reports/${a}_task-report.md"
expect_fail "out-of-scope change in Task worktree" "outside Task allowed_paths: src/b/stray.txt" \
  "$aiops" task advance "$a" --target "$project" --evidence ".ai_project/reports/${a}_task-report.md" --check
rm "$wt_a/src/b/stray.txt"
printf 'a2\n' > "$wt_a/src/a/a.txt"
git -C "$wt_a" commit -qam "a 변경"
ok "in-scope advance check" "$aiops" task advance "$a" --target "$project" --evidence ".ai_project/reports/${a}_task-report.md" --check

# --- done needs the Task branch merged first ---
sed -i.bak 's/^status: in_progress$/status: completion_review/; s/^target_agent: .*/target_agent: Charlie Project Agent/; s/^target_role: .*/target_role: Completion Role/; s/^locked_by: .*/locked_by:/; s/^lock_session: .*/lock_session:/; s/^locked_at: .*/locked_at:/' "$project/.ai_project/tasks/active/$a.md"
rm -f "$project/.ai_project/tasks/active/$a.md.bak"
expect_fail "done before merge" "run aiops worktree merge $a before done" \
  "$aiops" task advance "$a" --target "$project" --check
"$aiops" orchestrate plan "$a" --target "$project" --operator "Charlie Project Agent" --json > "$tmpdir/plan.json"
ruby -rjson -e 'plan = JSON.parse(File.read(ARGV[0])); abort "merge prepare missing" unless plan.dig("next", "prepare") == ["aiops", "worktree", "merge", ARGV[1]]' "$tmpdir/plan.json" "$a"

# --- merge: rebase onto the base, fast-forward, remove the worktree ---
printf 'b2\n' > "$wt_b/src/b/b.txt"
git -C "$wt_b" commit -qam "b 변경"
printf 'dirty\n' >> "$wt_a/src/a/a.txt"
expect_fail "merge with uncommitted changes" "uncommitted changes" "$aiops" worktree merge "$a" --target "$project"
git -C "$wt_a" checkout -q -- src/a/a.txt
ok "merge a" "$aiops" worktree merge "$a" --target "$project"
ok "merge b after a" "$aiops" worktree merge "$b" --target "$project"
[ ! -d "$wt_a" ] && [ ! -d "$wt_b" ] || fail "merged worktrees were not removed"
[ "$(git -C "$project" show main:src/a/a.txt)" = "a2" ] || fail "main is missing the a change"
[ "$(git -C "$project" show main:src/b/b.txt)" = "b2" ] || fail "main is missing the b change"
[ "$(git -C "$project" rev-list --merges --count main)" = "0" ] || fail "merge should not create merge commits"
git -C "$project" show -s --format=%s main | grep -q 'b 변경' || fail "commit message should stay as written"
if git -C "$project" rev-parse --verify -q "silo-charlie/$a" >/dev/null; then
  fail "merged Task branch should be deleted"
fi
[ "$(field "$a" worktree_role)" = "merged" ] || fail "worktree_role should be merged"
[ -n "$(field "$b" merged_sha)" ] || fail "merged_sha missing"
ok "advance check after merge uses the merged range" "$aiops" task advance "$a" --target "$project" --check

# --- conflicts stop the merge without touching the base ---
d=T-20261118-104
write_task "$d" approved src/b
ok "worktree create d" "$aiops" worktree create "$d" --target "$project"
wt_d="$(field "$d" worktree_path)"
printf 'from d\n' > "$wt_d/src/a/a.txt"
git -C "$wt_d" commit -qam "d 변경"
printf 'from main\n' > "$project/src/a/a.txt"
git -C "$project" commit -qam "main 변경"
before="$(git -C "$project" rev-parse main)"
expect_fail "conflicting merge" "hit conflicts" "$aiops" worktree merge "$d" --target "$project"
[ "$(git -C "$project" rev-parse main)" = "$before" ] || fail "failed merge changed main"

# --- teams without an Operator or a setting are not limited ---
plain="$tmpdir/plain"
mkdir -p "$plain/.ai_project/tasks/active"
ln -s "$repo_root" "$plain/.ai"
printf -- '---\nagents: []\n---\n' > "$plain/.ai_project/agent_registry.md"
ruby -I"$repo_root/runtime" -rtask_worktree -e 'abort "unexpected limit" unless TaskWorktree.parallel_limit(ARGV[0], "Silo Bravo").nil?' "$plain"

# --- the Owner approves several Tasks at once ---
e=T-20261118-105
f=T-20261118-106
write_task "$e" scoped src/e
write_task "$f" scoped src/f
for id in "$e" "$f"; do
  sed -i.bak 's/^target_agent: .*/target_agent: Charlie Project Agent/; s/^target_role: .*/target_role: Lead Role/' "$project/.ai_project/tasks/active/$id.md"
  rm -f "$project/.ai_project/tasks/active/$id.md.bak"
done
(cd "$project" && "$aiops" approve) > "$tmpdir/approve.out" 2>&1 && fail "aiops approve without ID should stop when several Tasks wait"
grep -q 'aiops approve --all' "$tmpdir/approve.out" || fail "aiops approve should suggest --all"
(cd "$project" && "$aiops" approve --all) > "$tmpdir/approve.out" 2>&1 || { cat "$tmpdir/approve.out" >&2; fail "aiops approve --all failed"; }
[ "$(field "$e" status)" = "approved" ] && [ "$(field "$f" status)" = "approved" ] || fail "approve --all did not approve both Tasks"

printf '%s\n' "ok: parallel tasks"

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

cat > "$project/.ai_project/operating_model.md" <<EOF
---
schema: aiops.operating_model.v1
---

# Operating Model
EOF

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
d=T-20261118-104

# --- no running-Task limit: Tasks with separate paths start together in one folder ---
"$aiops" orchestrate next --operator "Charlie Project Agent" --target "$project" --json > "$tmpdir/next.json"
ruby -rjson -e 'batch = JSON.parse(File.read(ARGV[0])); abort "start_now #{batch["start_now"]}" unless batch["start_now"] == [ARGV[1], ARGV[2]]; abort "waiting #{batch["waiting"]}" unless batch["waiting"].keys == [ARGV[3]]; abort "no limit fields" if batch.key?("parallel_limit")' "$tmpdir/next.json" "$a" "$b" "$c"
"$aiops" orchestrate plan "$a" --target "$project" --operator "Charlie Project Agent" --json > "$tmpdir/plan.json"
ruby -rjson -e 'plan = JSON.parse(File.read(ARGV[0])); abort "prepare should be gone" if plan["next"].key?("prepare")' "$tmpdir/plan.json"
"$aiops" validate orchestration-plan "$tmpdir/plan.json" >/dev/null || fail "plan should match the schema"

ok "accept a" "$aiops" task accept "$a" --target "$project" --dispatched-by "Charlie Project Agent"
ok "accept b in parallel" "$aiops" task accept "$b" --target "$project" --dispatched-by "Charlie Project Agent"
write_task "$d" approved src/d
ok "accept d: no running-Task limit" "$aiops" task accept "$d" --target "$project" --dispatched-by "Charlie Project Agent"
expect_fail "overlapping allowed_paths" "allowed_paths overlap with running Task $a" \
  "$aiops" task accept "$c" --target "$project" --check

# --- changed-path checks skip paths of running neighbor Tasks in the same folder ---
printf 'a2\n' > "$project/src/a/a.txt"
printf 'b2\n' > "$project/src/b/b.txt"
printf '# Report\n' > "$project/.ai_project/reports/${a}_task-report.md"
ok "a sees b's change as b's" "$aiops" task advance "$a" --target "$project" --evidence ".ai_project/reports/${a}_task-report.md" --check
printf 'stray\n' > "$project/src/stray.txt"
expect_fail "change owned by no running Task" "outside Task allowed_paths: src/stray.txt" \
  "$aiops" task advance "$a" --target "$project" --evidence ".ai_project/reports/${a}_task-report.md" --check
rm "$project/src/stray.txt"

# --- Tasks of other teams in other folders do not block each other ---
ruby -I"$repo_root/runtime" -rtask_worktree -e '
  dir = ARGV[0]
  task = { "id" => "T-X", "team" => "Silo Bravo", "worktree_path" => File.join(dir, ".worktrees/bravo"), "allowed_paths" => ["src/a"] }
  abort "other team in another folder should not block" unless TaskWorktree.start_problem(dir, task).nil?
  same_folder = task.merge("team" => "Silo Bravo", "worktree_path" => "")
  abort "same folder should block" unless TaskWorktree.start_problem(dir, same_folder).to_s.include?(ARGV[1])
  a = TaskWorktree.product_paths("allowed_paths" => [".ai_project/checks/test_a.py", ".ai_project/reports/x.md", ".worktrees/silo-charlie-main/src/a"])
  abort "product paths: #{a}" unless a == [".ai_project/checks/test_a.py", "src/a"]
  abort "overlap on a shared check" unless TaskWorktree.overlap(a, [".ai_project/checks"])
' "$project" "$a"

# --- doctor warns about running Tasks nobody has touched for a while ---
"$aiops" doctor --target "$project" > "$tmpdir/doctor.out" 2>&1 || true
if grep -q "stale running Task" "$tmpdir/doctor.out"; then cat "$tmpdir/doctor.out" >&2; fail "fresh running Tasks are not stale"; fi
sed -i.bak 's/^updated_at: .*/updated_at: 2026-01-02/' "$project/.ai_project/tasks/active/$d.md" && rm -f "$project/.ai_project/tasks/active/$d.md.bak"
"$aiops" doctor --target "$project" > "$tmpdir/doctor.out" 2>&1 || true
grep -q "warn: stale running Task $d (in_progress, Silo Charlie, .* days since 2026-01-02) holds src/d" "$tmpdir/doctor.out" || { cat "$tmpdir/doctor.out" >&2; fail "doctor should warn about the stale running Task"; }
printf -- '---\nschema: aiops.operating_model.v1\nstale_task_days: 100000\n---\n' > "$project/.ai_project/operating_model.md"
"$aiops" doctor --target "$project" > "$tmpdir/doctor.out" 2>&1 || true
if grep -q "stale running Task" "$tmpdir/doctor.out"; then fail "stale_task_days should raise the threshold"; fi

# --- project checks live in .ai_project/checks and run against any folder ---
expect_fail "checks without run.sh" "project checks are not set up" "$aiops" worktree checks --target "$project" --dir "$project"
mkdir -p "$project/.ai_project/checks" "$tmpdir/other/src"
cat > "$project/.ai_project/checks/run.sh" <<'SH'
echo "root=$AIOPS_PROJECT_ROOT checks=$AIOPS_CHECKS_DIR wt=$AIOPS_WORKTREE task=${AIOPS_TASK_ID:-}"
[ "$(pwd -P)" = "$(cd "$AIOPS_WORKTREE" && pwd -P)" ] || exit 3
[ ! -f "$AIOPS_WORKTREE/src/broken" ]
SH
ok "checks for a Task use its folder" "$aiops" worktree checks "$a" --target "$project"
grep -q "task=$a" "$tmpdir/out.txt" || fail "checks should receive AIOPS_TASK_ID"
grep -q "wt=$project" "$tmpdir/out.txt" || fail "checks should run in the Task folder"
printf 'x\n' > "$tmpdir/other/src/broken"
expect_fail "checks on another folder" "checks failed" "$aiops" worktree checks --target "$project" --dir "$tmpdir/other"
for gone in create merge; do
  "$aiops" worktree "$gone" "$a" --target "$project" >/dev/null 2>&1 && fail "aiops worktree $gone should be removed"
done

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

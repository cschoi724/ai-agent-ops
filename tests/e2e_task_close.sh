#!/usr/bin/env sh
set -eu

repo_root="$(CDPATH= cd "$(dirname "$0")/.." && pwd)"
tmpdir="$(mktemp -d /tmp/aiops-e2e-task-close.XXXXXX)"
trap 'rm -rf "$tmpdir"' EXIT INT TERM

task_id="T-20260814-001"
task_branch="task/T-20260814-001-cleanup"

setup_fixture() {
  label="$1"
  remote="$tmpdir/$label-remote.git"
  project="$tmpdir/$label-project"
  task_worktree="$tmpdir/$label-task-worktree"

  git init --bare --initial-branch=main "$remote" >/dev/null
  git clone "$remote" "$project" >/dev/null 2>&1
  git -C "$project" config user.name "AI Ops Test"
  git -C "$project" config user.email "aiops@example.invalid"
  git -C "$project" checkout -b main >/dev/null 2>&1
  mkdir -p "$project/.ai_project/tasks/archive" "$project/.ai_project/.runtime/task_cleanup"
  cat > "$project/.gitignore" <<'EOF'
.ai_project/.runtime/
EOF
  cat > "$project/.ai_project/operating_model.md" <<'EOF'
---
schema: aiops.operating_model.v1
project: TaskCloseFixture
bootstrap_mode: guided_full
core_version: 0.14.0
start_context: assigned_or_existing_project
readiness_level: implementation_ready
operating_mode: team_pr
team_pattern: single_team
workflow_policy: standard_vnext
ownership_model: path_plus_domain
coordination: parallel_with_locks
board_model: project_board_only
knowledge_mode: minimal
canonical_status_ref: origin/main
---
EOF
  cat > "$project/.ai_project/branch_pr_strategy.md" <<'EOF'
# Branch Strategy

```yaml
branch_strategy:
  base_branch: main
  canonical_status_ref: origin/main
merge:
  method: squash
  delete_branch_after_merge: true
```
EOF
  cat > "$project/.ai_project/tasks/archive/$task_id.md" <<EOF
---
schema: aiops.task.v1
id: $task_id
title: Safe task close fixture
status: done
type: feature
priority: medium
workflow: feature
target_agent:
target_role:
required_capabilities:
  - implementation
depends_on: []
blocks: []
allowed_paths:
  - src/
source_of_truth:
  - .ai_project/operating_model.md
created_by: AI Ops Test
report_to: .ai_project/reports/${task_id}_task-report.md
qa_to: .ai_project/qa/${task_id}_qa-report.md
worktree_path: $task_worktree
branch:
  name: $task_branch
  base: main
pr:
  status: merged
---

# Safe task close fixture
EOF
  mkdir -p "$project/src"
  printf '%s\n' "base" > "$project/src/value.txt"
  git -C "$project" add .
  git -C "$project" commit -m "seed task close fixture" >/dev/null
  git -C "$project" push -u origin main >/dev/null 2>&1
  git -C "$project" worktree add -b "$task_branch" "$task_worktree" main >/dev/null 2>&1
  git -C "$task_worktree" push -u origin "$task_branch" >/dev/null 2>&1
}

assert_fails() {
  output="$1"
  shift
  if "$@" >"$output" 2>&1; then
    printf '%s\n' "expected command to fail: $*" >&2
    exit 1
  fi
}

# Expected user errors must stay concise outside a Git worktree.
mkdir -p "$tmpdir/non-git"
assert_fails "$tmpdir/non-git.out" "$repo_root/bin/aiops" task close T-20260814-999 --target "$tmpdir/non-git" --check
grep -q 'task close requires a Git worktree' "$tmpdir/non-git.out"
if grep -qE 'NoMethodError|task_cleanup\.rb:[0-9]+' "$tmpdir/non-git.out"; then
  printf '%s\n' "non-Git cleanup exposed a Ruby stack trace" >&2
  exit 1
fi

# Clean merged branch: plan, apply, receipt, and idempotent retry.
setup_fixture clean
task_hash_before="$(git -C "$project" hash-object ".ai_project/tasks/archive/$task_id.md")"
"$repo_root/bin/aiops" task close "$task_id" --target "$project" --check --json > "$tmpdir/clean-plan.json"
"$repo_root/bin/aiops" validate task-cleanup-plan "$tmpdir/clean-plan.json" >/dev/null
grep -q '"method": "git_ancestor"' "$tmpdir/clean-plan.json"
grep -q '"action": "remove_worktree"' "$tmpdir/clean-plan.json"
grep -q '"status": "planned"' "$tmpdir/clean-plan.json"
[ -d "$task_worktree" ]
git -C "$project" show-ref --verify --quiet "refs/heads/$task_branch"
"$repo_root/bin/aiops" task close "$task_id" --target "$project" --json > "$tmpdir/default-plan.json"
"$repo_root/bin/aiops" validate task-cleanup-plan "$tmpdir/default-plan.json" >/dev/null
[ -d "$task_worktree" ]
assert_fails "$tmpdir/check-apply.out" "$repo_root/bin/aiops" task close "$task_id" --target "$project" --check --apply
grep -q -- '--check and --apply cannot be used together' "$tmpdir/check-apply.out"

"$repo_root/bin/aiops" task close "$task_id" --target "$project" --apply --delete-remote --by "Completion Agent" --json > "$tmpdir/clean-receipt.json"
receipt="$project/.ai_project/.runtime/task_cleanup/$task_id-cleanup-receipt.json"
"$repo_root/bin/aiops" validate task-cleanup-receipt "$receipt" >/dev/null
grep -q '"result": "complete"' "$tmpdir/clean-receipt.json"
[ ! -d "$task_worktree" ]
if git -C "$project" show-ref --verify --quiet "refs/heads/$task_branch"; then
  printf '%s\n' "local Task branch was not deleted" >&2
  exit 1
fi
if git --git-dir="$remote" show-ref --verify --quiet "refs/heads/$task_branch"; then
  printf '%s\n' "remote Task branch was not deleted" >&2
  exit 1
fi
task_hash_after="$(git -C "$project" hash-object ".ai_project/tasks/archive/$task_id.md")"
[ "$task_hash_before" = "$task_hash_after" ]
receipt_hash="$(shasum -a 256 "$receipt" | awk '{print $1}')"
"$repo_root/bin/aiops" task close "$task_id" --target "$project" --apply --delete-remote --json > "$tmpdir/clean-repeat.json"
[ "$receipt_hash" = "$(shasum -a 256 "$receipt" | awk '{print $1}')" ]
grep -q '"result": "complete"' "$tmpdir/clean-repeat.json"

# Dirty linked worktree is protected.
setup_fixture dirty
printf '%s\n' "dirty" >> "$task_worktree/src/value.txt"
assert_fails "$tmpdir/dirty.out" "$repo_root/bin/aiops" task close "$task_id" --target "$project" --check
grep -q 'Task worktree is dirty' "$tmpdir/dirty.out"
[ -d "$task_worktree" ]

# The currently checked out Task branch cannot close itself.
setup_fixture current
assert_fails "$tmpdir/current.out" "$repo_root/bin/aiops" task close "$task_id" --target "$task_worktree" --check
grep -q 'cannot close the current branch' "$tmpdir/current.out"

# Unpushed and unmerged commits are rejected independently.
setup_fixture unpushed
printf '%s\n' "local-only" >> "$task_worktree/src/value.txt"
git -C "$task_worktree" add src/value.txt
git -C "$task_worktree" commit -m "local only" >/dev/null
assert_fails "$tmpdir/unpushed.out" "$repo_root/bin/aiops" task close "$task_id" --target "$project" --check
grep -q 'unpushed commit' "$tmpdir/unpushed.out"

setup_fixture unmerged
printf '%s\n' "not merged" >> "$task_worktree/src/value.txt"
git -C "$task_worktree" add src/value.txt
git -C "$task_worktree" commit -m "not merged" >/dev/null
git -C "$task_worktree" push origin "$task_branch" >/dev/null 2>&1
assert_fails "$tmpdir/unmerged.out" "$repo_root/bin/aiops" task close "$task_id" --target "$project" --check
grep -q 'no matching merged PR' "$tmpdir/unmerged.out"

# A branch shared by another Task is never deleted.
setup_fixture shared
cat > "$project/.ai_project/tasks/archive/T-20260814-002.md" <<EOF
---
schema: aiops.task.v1
id: T-20260814-002
title: Shared branch fixture
status: done
workflow: feature
target_role:
required_capabilities: [implementation]
branch:
  name: $task_branch
---
EOF
git -C "$project" add ".ai_project/tasks/archive/T-20260814-002.md"
git -C "$project" commit -m "record shared branch" >/dev/null
git -C "$project" push origin main >/dev/null 2>&1
assert_fails "$tmpdir/shared.out" "$repo_root/bin/aiops" task close "$task_id" --target "$project" --check
grep -q 'is shared by T-20260814-002' "$tmpdir/shared.out"

# Project policy can explicitly disable post-merge deletion.
setup_fixture policy
perl -0pi -e 's/delete_branch_after_merge: true/delete_branch_after_merge: false/' "$project/.ai_project/branch_pr_strategy.md"
assert_fails "$tmpdir/policy.out" "$repo_root/bin/aiops" task close "$task_id" --target "$project" --check
grep -q 'project policy disables' "$tmpdir/policy.out"

# Cleanup receipts must remain an ignored local runtime cache.
setup_fixture runtime-ignore
printf '%s\n' '# no runtime ignore' > "$project/.gitignore"
assert_fails "$tmpdir/runtime-ignore.out" "$repo_root/bin/aiops" task close "$task_id" --target "$project" --check
grep -q 'must be Git-ignored' "$tmpdir/runtime-ignore.out"

# Configured protected branches and stale canonical cache are fail-closed.
setup_fixture configured-protected
perl -0pi -e "s|base_branch: main|base_branch: $task_branch|" "$project/.ai_project/branch_pr_strategy.md"
assert_fails "$tmpdir/configured-protected.out" "$repo_root/bin/aiops" task close "$task_id" --target "$project" --check
grep -q 'protected branch' "$tmpdir/configured-protected.out"

setup_fixture stale-canonical
cat > "$project/.ai_project/.runtime/status_ref" <<'EOF'
status_ref: origin/main
status_ref_sha: 0000000000000000000000000000000000000000
EOF
assert_fails "$tmpdir/stale-canonical.out" "$repo_root/bin/aiops" task close "$task_id" --target "$project" --check
grep -q 'recorded canonical status is stale' "$tmpdir/stale-canonical.out"

# Recorded worktree metadata must match the registered Task branch worktree.
setup_fixture metadata
mkdir -p "$tmpdir/unregistered-task-path"
perl -0pi -e "s|worktree_path: .*|worktree_path: $tmpdir/unregistered-task-path|" "$project/.ai_project/tasks/archive/$task_id.md"
assert_fails "$tmpdir/metadata.out" "$repo_root/bin/aiops" task close "$task_id" --target "$project" --check
grep -q 'worktree_path does not match' "$tmpdir/metadata.out"

# A linked branch worktree is not Task-owned without matching Task metadata.
setup_fixture metadata-missing
perl -0pi -e 's/\nworktree_path: .*\n/\n/' "$project/.ai_project/tasks/archive/$task_id.md"
assert_fails "$tmpdir/metadata-missing.out" "$repo_root/bin/aiops" task close "$task_id" --target "$project" --apply
grep -q 'worktree_path is not recorded' "$tmpdir/metadata-missing.out"
[ -d "$task_worktree" ]
git -C "$project" show-ref --verify --quiet "refs/heads/$task_branch"

# Cleanup metadata accepts only conservative machine-safe branch names.
setup_fixture unsafe-branch
perl -0pi -e "s|name: $task_branch|name: task/evil;touch|" "$project/.ai_project/tasks/archive/$task_id.md"
assert_fails "$tmpdir/unsafe-branch.out" "$repo_root/bin/aiops" task close "$task_id" --target "$project" --check
grep -q 'invalid Task branch name' "$tmpdir/unsafe-branch.out"

# Missing linked worktree directories are pruned before branch deletion.
setup_fixture prunable
mv "$task_worktree" "$task_worktree-moved"
"$repo_root/bin/aiops" task close "$task_id" --target "$project" --apply --json > "$tmpdir/prunable.json"
grep -q '"result": "complete"' "$tmpdir/prunable.json"
if git -C "$project" worktree list --porcelain | grep -q "worktree $task_worktree"; then
  printf '%s\n' "stale worktree metadata was not pruned" >&2
  exit 1
fi
if git -C "$project" show-ref --verify --quiet "refs/heads/$task_branch"; then
  printf '%s\n' "branch using stale worktree metadata was not deleted" >&2
  exit 1
fi

# A partial failure keeps Task done, records a partial receipt, and can resume.
setup_fixture partial
task_hash_before="$(git -C "$project" hash-object ".ai_project/tasks/archive/$task_id.md")"
working_remote="$remote"
git -C "$project" remote set-url origin "$tmpdir/missing-remote.git"
set +e
"$repo_root/bin/aiops" task close "$task_id" --target "$project" --apply --delete-remote --json \
  >"$tmpdir/partial.json" 2>"$tmpdir/partial.err"
partial_status="$?"
set -e
[ "$partial_status" -ne 0 ] || {
  cat "$tmpdir/partial.json" >&2
  cat "$tmpdir/partial.err" >&2
  printf '%s\n' "injected cleanup failure should return non-zero" >&2
  exit 1
}
receipt="$project/.ai_project/.runtime/task_cleanup/$task_id-cleanup-receipt.json"
"$repo_root/bin/aiops" validate task-cleanup-receipt "$receipt" >/dev/null
grep -q '"result": "partial"' "$receipt"
grep -q '^status: done$' "$project/.ai_project/tasks/archive/$task_id.md"
[ "$task_hash_before" = "$(git -C "$project" hash-object ".ai_project/tasks/archive/$task_id.md")" ]
if git -C "$project" show-ref --verify --quiet "refs/heads/$task_branch"; then
  printf '%s\n' "partial cleanup did not retain completed local deletion" >&2
  exit 1
fi
git --git-dir="$remote" show-ref --verify --quiet "refs/heads/$task_branch"
git -C "$project" remote set-url origin "$working_remote"
"$repo_root/bin/aiops" task close "$task_id" --target "$project" --apply --delete-remote --json > "$tmpdir/partial-resume.json"
grep -q '"result": "complete"' "$tmpdir/partial-resume.json"

# Squash merge evidence comes from a matching merged GitHub PR.
setup_fixture squash
printf '%s\n' "squashed" >> "$task_worktree/src/value.txt"
git -C "$task_worktree" add src/value.txt
git -C "$task_worktree" commit -m "task branch change" >/dev/null
git -C "$task_worktree" push origin "$task_branch" >/dev/null 2>&1
printf '%s\n' "squashed" >> "$project/src/value.txt"
git -C "$project" add src/value.txt
git -C "$project" commit -m "squash task change" >/dev/null
git -C "$project" push origin main >/dev/null 2>&1
canonical_sha="$(git -C "$project" rev-parse HEAD)"
task_head_sha="$(git -C "$project" rev-parse "$task_branch")"
stale_head_sha="$(git -C "$project" rev-parse "$task_branch^")"
git -C "$project" remote set-url origin git@github.com:example/fixture.git
fake_bin="$tmpdir/fake-bin"
mkdir -p "$fake_bin"
cat > "$fake_bin/gh" <<EOF
#!/bin/sh
if [ "\$1" = "pr" ]; then
  printf '%s\n' '[{"number":41,"url":"https://github.com/example/fixture/pull/41","headRefName":"task/T-20260814-001-cleanup","headRefOid":"$stale_head_sha","baseRefName":"main","mergeCommit":{"oid":"$canonical_sha"},"mergedAt":"2026-08-13T00:00:00Z"}]'
  exit 0
fi
printf '%s\n' 'Not Found (HTTP 404)' >&2
exit 1
EOF
chmod +x "$fake_bin/gh"
assert_fails "$tmpdir/stale-pr-head.out" env PATH="$fake_bin:$PATH" \
  "$repo_root/bin/aiops" task close "$task_id" --target "$project" --check
grep -q 'no matching merged PR' "$tmpdir/stale-pr-head.out"
[ -d "$task_worktree" ]

cat > "$fake_bin/gh" <<EOF
#!/bin/sh
if [ "\$1" = "pr" ]; then
  printf '%s\n' '[{"number":42,"url":"https://github.com/example/fixture/pull/42","headRefName":"task/T-20260814-001-cleanup","headRefOid":"$task_head_sha","baseRefName":"main","mergeCommit":{"oid":"$canonical_sha"},"mergedAt":"2026-08-14T00:00:00Z"}]'
  exit 0
fi
printf '%s\n' 'Not Found (HTTP 404)' >&2
exit 1
EOF
chmod +x "$fake_bin/gh"
PATH="$fake_bin:$PATH" "$repo_root/bin/aiops" task close "$task_id" --target "$project" --check --json > "$tmpdir/squash-plan.json"
grep -q '"method": "github_pull_request"' "$tmpdir/squash-plan.json"
grep -q '"number": 42' "$tmpdir/squash-plan.json"
PATH="$fake_bin:$PATH" "$repo_root/bin/aiops" task close "$task_id" --target "$project" --apply --json > "$tmpdir/squash-receipt.json"
grep -q '"result": "complete"' "$tmpdir/squash-receipt.json"

# GitHub protected branch rules block requested remote deletion.
setup_fixture protected
git -C "$project" remote set-url origin git@github.com:example/fixture.git
cat > "$fake_bin/gh" <<'EOF'
#!/bin/sh
if [ "$1" = "api" ]; then
  printf '%s\n' '[{"type":"deletion"}]'
  exit 0
fi
printf '%s\n' '[]'
EOF
chmod +x "$fake_bin/gh"
assert_fails "$tmpdir/protected.out" env PATH="$fake_bin:$PATH" \
  "$repo_root/bin/aiops" task close "$task_id" --target "$project" --delete-remote --check
grep -q 'GitHub protected branch' "$tmpdir/protected.out"

# Schema mutation checks.
ruby -rjson -e '
  data = JSON.parse(File.read(ARGV[0]))
  data["ready"] = "yes"
  File.write(ARGV[1], JSON.pretty_generate(data))
' "$tmpdir/clean-plan.json" "$tmpdir/invalid-plan.json"
assert_fails "$tmpdir/invalid-plan.out" "$repo_root/bin/aiops" validate task-cleanup-plan "$tmpdir/invalid-plan.json"

ruby -rjson -e '
  data = JSON.parse(File.read(ARGV[0]))
  data["result"] = "unknown"
  File.write(ARGV[1], JSON.pretty_generate(data))
' "$tmpdir/clean-receipt.json" "$tmpdir/invalid-receipt.json"
assert_fails "$tmpdir/invalid-receipt.out" "$repo_root/bin/aiops" validate task-cleanup-receipt "$tmpdir/invalid-receipt.json"

ruby -rjson -e '
  data = JSON.parse(File.read(ARGV[0]))
  data["actions"][-1] = data["actions"][0].dup
  File.write(ARGV[1], JSON.pretty_generate(data))
' "$tmpdir/clean-plan.json" "$tmpdir/duplicate-plan-action.json"
assert_fails "$tmpdir/duplicate-plan-action.out" "$repo_root/bin/aiops" validate task-cleanup-plan "$tmpdir/duplicate-plan-action.json"
grep -q 'duplicate actions' "$tmpdir/duplicate-plan-action.out"

ruby -rjson -e '
  data = JSON.parse(File.read(ARGV[0]))
  data["actions"] << data["actions"][0].dup
  File.write(ARGV[1], JSON.pretty_generate(data))
' "$tmpdir/clean-receipt.json" "$tmpdir/duplicate-receipt-action.json"
assert_fails "$tmpdir/duplicate-receipt-action.out" "$repo_root/bin/aiops" validate task-cleanup-receipt "$tmpdir/duplicate-receipt-action.json"
grep -q 'duplicate actions' "$tmpdir/duplicate-receipt-action.out"

ruby -rjson -e '
  data = JSON.parse(File.read(ARGV[0]))
  data["result"] = "partial"
  data["blockers"] = ["injected blocker"]
  data["actions"] = []
  File.write(ARGV[1], JSON.pretty_generate(data))
' "$tmpdir/clean-receipt.json" "$tmpdir/empty-partial-receipt.json"
assert_fails "$tmpdir/empty-partial-receipt.out" "$repo_root/bin/aiops" validate task-cleanup-receipt "$tmpdir/empty-partial-receipt.json"
grep -q 'partial cleanup receipt must contain' "$tmpdir/empty-partial-receipt.out"

printf '%s\n' "ok: safe task close cleanup"

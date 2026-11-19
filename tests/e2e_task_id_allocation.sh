#!/usr/bin/env sh
set -eu

repo_root="$(CDPATH= cd "$(dirname "$0")/.." && pwd)"
aiops="$repo_root/bin/aiops"
tmpdir="$(mktemp -d /tmp/aiops-e2e-task-id.XXXXXX)"
trap 'rm -rf "$tmpdir"' EXIT INT TERM

fail() {
  printf '%s\n' "$1" >&2
  exit 1
}

project="$tmpdir/project"
mkdir -p "$project/.ai_project/tasks/active" "$project/.ai_project/tasks/backlog" "$project/.ai_project/tasks/archive"
ln -s "$repo_root" "$project/.ai"
printf '# Source of Truth\n' > "$project/.ai_project/source_of_truth.md"

create_task() {
  "$aiops" task create --target "$project" --queue "$1" --title "Parallel create $2" \
    --workflow feature --role "Lead Role" --capability planning --allowed-path src/ \
    --source-of-truth .ai_project/source_of_truth.md --created-by "Lead Agent"
}

# --- concurrent creates get distinct IDs ---
pids=""
for n in 1 2 3 4 5 6; do
  queue=active
  [ $((n % 2)) -eq 0 ] && queue=backlog
  create_task "$queue" "$n" >"$tmpdir/create-$n.out" 2>&1 &
  pids="$pids $!"
done
for pid in $pids; do
  wait "$pid" || { cat "$tmpdir"/create-*.out >&2; fail "concurrent task create failed"; }
done
ids="$(sed -n 's/^task_id: //p' "$tmpdir"/create-*.out | sort)"
[ "$(printf '%s\n' "$ids" | wc -l | tr -d ' ')" -eq 6 ] || fail "expected 6 created IDs: $ids"
[ "$(printf '%s\n' "$ids" | uniq | wc -l | tr -d ' ')" -eq 6 ] || fail "concurrent creates reused a Task ID: $ids"
[ ! -e "$project/.ai_project/.runtime/locks/task-create.lock" ] || fail "task create lock was not released"

# --- an explicit ID already used in another queue is refused ---
first_id="$(printf '%s\n' "$ids" | head -n 1)"
if "$aiops" task create --target "$project" --queue archive --id "$first_id" --title "Dup" \
  --workflow feature --role "Lead Role" --capability planning --allowed-path src/ \
  --source-of-truth .ai_project/source_of_truth.md --created-by "Lead Agent" >"$tmpdir/dup.out" 2>&1; then
  fail "task create should refuse an ID used in another queue"
fi
grep -q "task already exists" "$tmpdir/dup.out" || { cat "$tmpdir/dup.out" >&2; fail "missing duplicate create message"; }

# --- a stale lock left by a killed process is recovered ---
mkdir -p "$project/.ai_project/.runtime/locks/task-create.lock"
touch -t 202001010000 "$project/.ai_project/.runtime/locks/task-create.lock"
create_task active stale >"$tmpdir/stale.out" 2>&1 || { cat "$tmpdir/stale.out" >&2; fail "stale lock should be recovered"; }

# --- duplicate Task files are reported and block lookups ---
src="$(find "$project/.ai_project/tasks" -name "$first_id.md")"
case "$src" in
  */active/*) cp "$src" "$project/.ai_project/tasks/backlog/$first_id.md" ;;
  *) cp "$src" "$project/.ai_project/tasks/active/$first_id.md" ;;
esac
if "$aiops" task status "$first_id" --target "$project" >"$tmpdir/status.out" 2>&1; then
  fail "task status should refuse a duplicated Task ID"
fi
grep -q "multiple Task files found for $first_id" "$tmpdir/status.out" || { cat "$tmpdir/status.out" >&2; fail "missing duplicate lookup message"; }
"$aiops" doctor --target "$project" >"$tmpdir/doctor.out" 2>&1 || true
grep -q "warn: duplicate Task ID $first_id" "$tmpdir/doctor.out" || { cat "$tmpdir/doctor.out" >&2; fail "doctor should report the duplicate Task ID"; }
if "$aiops" doctor --target "$project" --strict >/dev/null 2>&1; then
  fail "doctor --strict should fail on a duplicate Task ID"
fi

printf '%s\n' "ok: task id allocation"

#!/usr/bin/env sh
set -eu

repo_root="$(CDPATH= cd "$(dirname "$0")/.." && pwd)"
aiops="$repo_root/bin/aiops"
tmpdir="$(mktemp -d /tmp/aiops-e2e-history-guard.XXXXXX)"
trap 'rm -rf "$tmpdir"' EXIT INT TERM

fail() {
  printf '%s\n' "$1" >&2
  exit 1
}

project="$tmpdir/project"
history="$project/.ai_project/history"
today="$(date +%Y-%m-%d)"
mkdir -p "$project/src" "$history/2026-01-02-old-cleanup" "$history/$today-new-record" "$history/2026-01-03-draft"
ln -s "$repo_root" "$project/.ai"
printf '# 예전 정리\n\n## 배경\n\n보고서 30GB.\n' > "$history/2026-01-02-old-cleanup/README.md"
printf 'diff --git a/x b/x\n' > "$history/2026-01-02-old-cleanup/restore.patch"
printf '# 오늘 기록\n\n## 배경\n\n쓰는 중.\n' > "$history/$today-new-record/README.md"
printf '# 초안\n\n## 배경\n\n(작성 전) 배경.\n' > "$history/2026-01-03-draft/README.md"
printf '# History Index\n\n| a |\n' > "$history/INDEX.md"
old=".ai_project/history/2026-01-02-old-cleanup/README.md"

expect() {
  expected="$1"
  label="$2"
  payload="$3"
  set +e
  printf '%s' "$payload" | (cd "$project" && env -u CLAUDE_PROJECT_DIR "$aiops" guard pre-tool-use >/dev/null 2>"$tmpdir/guard.err")
  status=$?
  set -e
  [ "$status" -eq "$expected" ] || {
    cat "$tmpdir/guard.err" >&2
    fail "guard $label: expected exit $expected, got $status"
  }
}
tool() {
  ruby -rjson -e 'puts JSON.generate("tool_name" => ARGV[0], "cwd" => ARGV[1], "tool_input" => JSON.parse(ARGV[2]))' -- "$1" "$project" "$2"
}
bash_payload() {
  tool Bash "$(ruby -rjson -e 'puts JSON.generate("command" => ARGV[0])' -- "$1")"
}
edit() {
  ruby -rjson -e 'puts JSON.generate("tool_name" => "Edit", "cwd" => ARGV[0], "tool_input" => { "file_path" => ARGV[1], "old_string" => ARGV[2], "new_string" => ARGV[3] })' -- "$project" "$1" "$2" "$3"
}
write() {
  ruby -rjson -e 'puts JSON.generate("tool_name" => "Write", "cwd" => ARGV[0], "tool_input" => { "file_path" => ARGV[1], "content" => ARGV[2] })' -- "$project" "$1" "$2"
}
patch() {
  ruby -rjson -e 'puts JSON.generate("tool_name" => "apply_patch", "cwd" => ARGV[0], "tool_input" => { "command" => ARGV[1] })' -- "$project" "$1"
}

# --- past records: append only ---
expect 0 "edit appends a correction" "$(edit "$old" '보고서 30GB.' '보고서 30GB.

## 정정 (2026-01-05)

실제로는 28GB였다.')"
expect 2 "edit changes a past line" "$(edit "$old" '보고서 30GB.' '보고서 28GB.')"
grep -q "덧붙이기만" "$tmpdir/guard.err" || fail "the block message should explain append-only"
expect 2 "write replaces a past record" "$(write "$old" '# new')"
grep -q "지난 기록입니다" "$tmpdir/guard.err" || fail "write should be blocked as a past record"
expect 0 "write keeps every line and adds more" "$(tool Write "$(ruby -rjson -e 'puts JSON.generate("file_path" => ARGV[0], "content" => File.read(File.join(ARGV[1], ARGV[0])) + "\n## 정정\n\n추가.\n")' -- "$old" "$project")")"
expect 0 "codex patch appends" "$(patch "*** Begin Patch
*** Update File: $old
@@
 보고서 30GB.
+추가 메모.
*** End Patch")"
expect 2 "codex patch removes a past line" "$(patch "*** Begin Patch
*** Update File: $old
@@
-보고서 30GB.
+보고서 1GB.
*** End Patch")"
expect 2 "codex patch deletes a past record" "$(patch "*** Begin Patch
*** Delete File: $old
*** End Patch")"
expect 2 "shell overwrite" "$(bash_payload "echo x > $old")"
expect 0 "shell append" "$(bash_payload "echo x >> $old")"
expect 0 "tee -a appends" "$(bash_payload "echo x | tee -a $old")"
expect 2 "tee overwrites" "$(bash_payload "echo x | tee $old")"
expect 2 "sed -i" "$(bash_payload "sed -i '' 's/30/1/' $old")"
expect 2 "cp onto a past record" "$(bash_payload "cp src/a $old")"
expect 0 "touch a past record" "$(bash_payload "touch $old")"

# --- deleting or moving records and the history folder ---
expect 2 "rm a past file" "$(bash_payload "rm .ai_project/history/2026-01-02-old-cleanup/restore.patch")"
expect 2 "rm -rf a past record folder" "$(bash_payload "rm -rf .ai_project/history/2026-01-02-old-cleanup")"
expect 2 "rm -rf the history folder" "$(bash_payload "rm -rf .ai_project/history")"
expect 2 "rm -rf .ai_project" "$(bash_payload "rm -rf .ai_project")"
expect 2 "cd then rm -rf" "$(bash_payload "cd .ai_project && rm -rf history")"
expect 2 "mv a past record" "$(bash_payload "mv .ai_project/history/2026-01-02-old-cleanup /tmp/x")"
expect 2 "find -delete" "$(bash_payload "find .ai_project -name '*.md' -delete")"
expect 2 "git rm" "$(bash_payload "git rm -r .ai_project/history/2026-01-02-old-cleanup")"
expect 0 "rm elsewhere" "$(bash_payload "rm -rf .ai_project/reports/T-1 src/tmp")"
expect 0 "find -delete elsewhere" "$(bash_payload "find src -name '*.tmp' -delete")"

# --- drafts, today's records, new files, and INDEX stay editable ---
expect 0 "edit today's record" "$(edit ".ai_project/history/$today-new-record/README.md" '쓰는 중.' '다 썼다.')"
expect 0 "rm today's record folder" "$(bash_payload "rm -rf .ai_project/history/$today-new-record")"
expect 0 "edit a draft with the draft mark" "$(edit ".ai_project/history/2026-01-03-draft/README.md" '(작성 전) 배경.' '배경을 채웠다.')"
expect 0 "add a file to a past record" "$(tool Write '{"file_path":".ai_project/history/2026-01-02-old-cleanup/notes.md","content":"x"}')"
expect 0 "add a new record" "$(write ".ai_project/history/$today-other/README.md" x)"
expect 0 "mkdir a record folder" "$(bash_payload "mkdir -p .ai_project/history/$today-other")"
expect 0 "edit INDEX" "$(edit ".ai_project/history/INDEX.md" '| a |' '| b |')"
expect 0 "aiops history new" "$(bash_payload "aiops history new disk-cleanup --category cleanup")"
expect 0 "read records" "$(bash_payload "grep -r 30GB .ai_project/history")"

printf '%s\n' "ok: history guard"

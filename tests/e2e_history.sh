#!/usr/bin/env sh
set -eu

repo_root="$(CDPATH= cd "$(dirname "$0")/.." && pwd)"
aiops="$repo_root/bin/aiops"
tmpdir="$(mktemp -d /tmp/aiops-e2e-history.XXXXXX)"
trap 'rm -rf "$tmpdir"' EXIT INT TERM

fail() {
  printf '%s\n' "$1" >&2
  [ -f "$tmpdir/out.txt" ] && cat "$tmpdir/out.txt" >&2
  exit 1
}

project="$tmpdir/project"
history="$project/.ai_project/history"
mkdir -p "$project/.ai_project/tasks/archive" "$project/.ai_project/reports" "$history/2026-01-02-old-cleanup"
printf -- '---\nschema: aiops.operating_model.v1\n---\n' > "$project/.ai_project/operating_model.md"

# --- older records (before INDEX) are adopted by index, never rewritten ---
printf '# 예전 정리 기록\n\nT-20260102-001 보고서를 지우기 전에 남긴다.\n' > "$history/2026-01-02-old-cleanup/README.md"
printf '{"raw": true}\n' > "$history/2026-01-02-old-cleanup/dump.json"
printf '# 보관 Task 목록\n\n보관 이유.\n' > "$history/2026-01-03-task-archive.md"
before="$(cat "$history/2026-01-02-old-cleanup/README.md")"

"$aiops" history lint --target "$project" > "$tmpdir/out.txt" 2>&1 && fail "lint should fail without INDEX.md"
grep -q "INDEX.md missing" "$tmpdir/out.txt" || fail "lint should ask for INDEX.md"
"$aiops" history index --target "$project" > "$tmpdir/out.txt" 2>&1 || fail "history index failed"
grep -q "listed: 2026-01-02-old-cleanup" "$tmpdir/out.txt" || fail "index should list the old folder record"
grep -q "listed: 2026-01-03-task-archive.md" "$tmpdir/out.txt" || fail "index should list the old file record"
grep -q '| 2026-01-02 | other | 예전 정리 기록 | T-20260102-001 | T-20260102-001 보고서를 지우기 전에 남긴다. | \[2026-01-02-old-cleanup\](2026-01-02-old-cleanup/README.md) |' "$history/INDEX.md" || fail "index row for the old record"
[ "$(cat "$history/2026-01-02-old-cleanup/README.md")" = "$before" ] || fail "index must not rewrite records"
"$aiops" history index --target "$project" > "$tmpdir/out.txt" 2>&1 || fail "second index failed"
grep -q "lists every record" "$tmpdir/out.txt" || fail "index should be idempotent"
[ "$(grep -c '2026-01-02-old-cleanup' "$history/INDEX.md")" = "1" ] || fail "index must not duplicate rows"
"$aiops" history lint --target "$project" > "$tmpdir/out.txt" 2>&1 || fail "older records only get notes"
grep -q "note: 2026-01-02-old-cleanup: older record .*non-text files (1)" "$tmpdir/out.txt" || fail "lint should note the json file in an older record"

# --- new records: template, INDEX row, and rules ---
"$aiops" history new bad_slug --target "$project" > "$tmpdir/out.txt" 2>&1 && fail "slug must be lowercase and hyphens"
"$aiops" history new disk-cleanup --category nope --target "$project" > "$tmpdir/out.txt" 2>&1 && fail "unknown category must fail"
(cd "$project/.ai_project/tasks" && "$aiops" history new disk-cleanup --category cleanup --task T-20260105-001 \
  --title "디스크 정리: 빌드 폴더" --summary "빌드 폴더 30GB 정리" --date 2026-01-05) > "$tmpdir/out.txt" 2>&1 || fail "history new failed"
record="$history/2026-01-05-disk-cleanup/README.md"
grep -q "created: .ai_project/history/2026-01-05-disk-cleanup/README.md" "$tmpdir/out.txt" || fail "new should print the path"
grep -q '^schema: aiops.history.v1$' "$record" || fail "record front matter schema"
grep -q "^title: \"디스크 정리: 빌드 폴더\"$" "$record" || fail "title with a colon must be quoted"
grep -q '^tasks: \[T-20260105-001\]$' "$record" || fail "record tasks"
grep -q '## Owner 발언' "$record" || fail "template sections"
grep -q '| 2026-01-05 | cleanup | 디스크 정리: 빌드 폴더 | T-20260105-001 | 빌드 폴더 30GB 정리 | \[2026-01-05-disk-cleanup\](2026-01-05-disk-cleanup/README.md) |' "$history/INDEX.md" || fail "new should add an INDEX row"
"$aiops" history new disk-cleanup --date 2026-01-05 --target "$project" > "$tmpdir/out.txt" 2>&1 && fail "existing record must not be overwritten"

"$aiops" history lint --target "$project" > "$tmpdir/out.txt" 2>&1 && fail "unwritten record should fail lint"
grep -q 'section "## 배경" is not written yet' "$tmpdir/out.txt" || fail "lint should flag the unwritten background"
ruby -e 'path = ARGV[0]; text = File.read(path); text.sub!(/(## 배경\n\n).*?\n/m, "\\1빌드 폴더가 30GB였다.\n"); text.sub!(/(## 판단과 이유\n\n).*?\n/m, "\\1다시 만들 수 있어 지운다.\n"); File.write(path, text)' "$record"
"$aiops" history lint --target "$project" > "$tmpdir/out.txt" 2>&1 || fail "written record should pass lint"

dd if=/dev/zero of="$history/2026-01-05-disk-cleanup/build.log.gz" bs=1024 count=2 2>/dev/null
"$aiops" history lint --target "$project" > "$tmpdir/out.txt" 2>&1 && fail "binary file in a new record should fail"
grep -q "2026-01-05-disk-cleanup: non-text files (1)" "$tmpdir/out.txt" || fail "lint should name the non-text file"
rm "$history/2026-01-05-disk-cleanup/build.log.gz"
printf -- '---\nschema: aiops.operating_model.v1\nhistory_record_max_kb: 1\n---\n' > "$project/.ai_project/operating_model.md"
head -c 3000 /dev/zero | tr '\0' 'a' > "$history/2026-01-05-disk-cleanup/notes.txt"
"$aiops" history lint --target "$project" > "$tmpdir/out.txt" 2>&1 && fail "oversized record should fail"
grep -q "is over 1 KB (history_record_max_kb)" "$tmpdir/out.txt" || fail "lint should report the size limit"
rm "$history/2026-01-05-disk-cleanup/notes.txt"
printf -- '---\nschema: aiops.operating_model.v1\n---\n' > "$project/.ai_project/operating_model.md"

mkdir "$history/2026-01-06-unlisted"
printf '# x\n' > "$history/2026-01-06-unlisted/README.md"
printf '| 2026-01-07 | other | gone | | | [2026-01-07-gone](2026-01-07-gone/README.md) |\n' >> "$history/INDEX.md"
"$aiops" history lint --target "$project" > "$tmpdir/out.txt" 2>&1 && fail "unlisted and dangling entries should fail"
grep -q "2026-01-06-unlisted: not listed in INDEX.md" "$tmpdir/out.txt" || fail "lint should flag the unlisted record"
grep -q "link 2026-01-07-gone/README.md points to a missing file" "$tmpdir/out.txt" || fail "lint should flag the dangling row"

# --- doctor: history problems and Task evidence removed without a record ---
"$aiops" doctor --target "$project" > "$tmpdir/doctor.out" 2>&1 || true
grep -q "warn: history 2026-01-06-unlisted: not listed" "$tmpdir/doctor.out" || { cat "$tmpdir/doctor.out" >&2; fail "doctor should report history lint errors"; }
rm -r "$history/2026-01-06-unlisted"
grep -v '2026-01-07-gone' "$history/INDEX.md" > "$tmpdir/index" && cp "$tmpdir/index" "$history/INDEX.md"

write_archived() {
  cat > "$project/.ai_project/tasks/archive/$1.md" <<TASK
---
schema: aiops.task.v1
id: $1
title: archived $1
status: done
report_to: .ai_project/reports/$1_task-report.md
---
TASK
}
write_archived T-20260102-001
write_archived T-20260108-001
write_archived T-20260108-002
printf '# report\n' > "$project/.ai_project/reports/T-20260108-002_task-report.md"
"$aiops" doctor --target "$project" > "$tmpdir/doctor.out" 2>&1 || true
grep -q "ok: .ai_project/history" "$tmpdir/doctor.out" || { cat "$tmpdir/doctor.out" >&2; fail "doctor should pass a clean history"; }
grep -q "warn: Task evidence removed without a history record: T-20260108-001" "$tmpdir/doctor.out" || { cat "$tmpdir/doctor.out" >&2; fail "doctor should warn about removed evidence"; }
if grep -q "without a history record: T-20260102-001" "$tmpdir/doctor.out"; then fail "a Task named in a record is covered"; fi
if grep -q "without a history record: T-20260108-002" "$tmpdir/doctor.out"; then fail "a Task with its report is fine"; fi

printf '%s\n' "ok: history"

#!/usr/bin/env sh
set -eu

repo_root="$(CDPATH= cd "$(dirname "$0")/.." && pwd)"
tmpdir="$(mktemp -d /tmp/aiops-e2e-migrate-apply.XXXXXX)"
trap 'rm -rf "$tmpdir"' EXIT INT TERM

current_version="$(cat "$repo_root/VERSION")"

ln -s "$repo_root" "$tmpdir/.ai"
cp -R "$repo_root/templates/ai_project/fast_track" "$tmpdir/.ai_project"
rm -rf "$tmpdir/.ai_project/tasks"

awk '{ gsub(/\{\{CORE_VERSION\}\}/, "0.0.0"); print }' \
  "$tmpdir/.ai_project/operating_model.md" > "$tmpdir/.ai_project/operating_model.tmp"
mv "$tmpdir/.ai_project/operating_model.tmp" "$tmpdir/.ai_project/operating_model.md"

"$repo_root/bin/aiops" migrate --target "$tmpdir" --apply >/tmp/aiops-e2e-migrate-apply.out

grep -q "| core_version | $current_version |" "$tmpdir/.ai_project/operating_model.md" || {
  printf '%s\n' "migrate apply did not update core_version" >&2
  exit 1
}

for dir in active backlog archive; do
  [ -d "$tmpdir/.ai_project/tasks/$dir" ] || {
    printf 'migrate apply did not create tasks/%s\n' "$dir" >&2
    exit 1
  }
done

for file in ops_migration_plan.md ops_decisions.md ops_issues.md; do
  [ -f "$tmpdir/.ai_project/$file" ] || {
    printf 'migrate apply did not create %s\n' "$file" >&2
    exit 1
  }
done

"$repo_root/bin/aiops" knowledge lint --target "$tmpdir" >/tmp/aiops-e2e-migrate-apply-knowledge.out
"$repo_root/bin/aiops" doctor --target "$tmpdir" --strict >/tmp/aiops-e2e-migrate-apply-doctor.out

grep -q 'Verifying migration state' /tmp/aiops-e2e-migrate-apply.out || {
  printf '%s\n' "migrate apply did not run verification" >&2
  exit 1
}

grep -q 'verification: passed' /tmp/aiops-e2e-migrate-apply.out || {
  printf '%s\n' "migrate apply did not report verification pass" >&2
  exit 1
}

printf '%s\n' "ok: migrate apply safe fixes"

#!/usr/bin/env sh
set -eu

repo_root="$(CDPATH= cd "$(dirname "$0")/.." && pwd)"
tmpdir="$(mktemp -d /tmp/aiops-e2e-migrate-clean.XXXXXX)"
trap 'rm -rf "$tmpdir"' EXIT INT TERM

current_version="$(cat "$repo_root/VERSION")"

ln -s "$repo_root" "$tmpdir/.ai"
cp -R "$repo_root/templates/ai_project/fast_track" "$tmpdir/.ai_project"
mkdir -p \
  "$tmpdir/.ai_project/tasks/active" \
  "$tmpdir/.ai_project/tasks/backlog" \
  "$tmpdir/.ai_project/tasks/archive"
cp "$repo_root/templates/ai_project/guided_full/ops_migration_plan.md" "$tmpdir/.ai_project/ops_migration_plan.md"
"$repo_root/bin/aiops" knowledge init --target "$tmpdir" --mode minimal >/tmp/aiops-e2e-migrate-clean-knowledge.out

awk -v version="$current_version" '{ gsub(/\{\{CORE_VERSION\}\}/, version); print }' \
  "$tmpdir/.ai_project/operating_model.md" > "$tmpdir/.ai_project/operating_model.tmp"
mv "$tmpdir/.ai_project/operating_model.tmp" "$tmpdir/.ai_project/operating_model.md"

before="$(find "$tmpdir" -type f -print | sort | xargs cksum | cksum)"
"$repo_root/bin/aiops" migrate --target "$tmpdir" >/tmp/aiops-e2e-migrate-clean.out
after="$(find "$tmpdir" -type f -print | sort | xargs cksum | cksum)"

grep -q 'mode: check' /tmp/aiops-e2e-migrate-clean.out || {
  printf '%s\n' "migrate check did not report check mode" >&2
  exit 1
}

grep -q 'migration_status: up_to_date' /tmp/aiops-e2e-migrate-clean.out || {
  printf '%s\n' "migrate check did not report up_to_date" >&2
  exit 1
}

[ "$before" = "$after" ] || {
  printf '%s\n' "migrate check modified files" >&2
  exit 1
}

printf '%s\n' "ok: migrate check clean"

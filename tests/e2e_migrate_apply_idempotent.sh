#!/usr/bin/env sh
set -eu

repo_root="$(CDPATH= cd "$(dirname "$0")/.." && pwd)"
tmpdir="$(mktemp -d /tmp/aiops-e2e-migrate-idempotent.XXXXXX)"
trap 'rm -rf "$tmpdir"' EXIT INT TERM

current_version="$(cat "$repo_root/VERSION")"

ln -s "$repo_root" "$tmpdir/.ai"
cp -R "$repo_root/templates/ai_project/fast_track" "$tmpdir/.ai_project"
mkdir -p \
  "$tmpdir/.ai_project/tasks/active" \
  "$tmpdir/.ai_project/tasks/backlog" \
  "$tmpdir/.ai_project/tasks/archive"
cp "$repo_root/templates/ai_project/guided_full/ops_migration_plan.md" "$tmpdir/.ai_project/ops_migration_plan.md"
"$repo_root/bin/aiops" knowledge init --target "$tmpdir" --mode minimal >/tmp/aiops-e2e-migrate-idempotent-knowledge.out

awk -v version="$current_version" '{ gsub(/\{\{CORE_VERSION\}\}/, version); print }' \
  "$tmpdir/.ai_project/operating_model.md" > "$tmpdir/.ai_project/operating_model.tmp"
mv "$tmpdir/.ai_project/operating_model.tmp" "$tmpdir/.ai_project/operating_model.md"

before="$(find "$tmpdir" -type f -print | sort | xargs cksum | cksum)"
"$repo_root/bin/aiops" migrate --target "$tmpdir" --apply >/tmp/aiops-e2e-migrate-idempotent.out
after="$(find "$tmpdir" -type f -print | sort | xargs cksum | cksum)"

grep -q 'No migration changes needed.' /tmp/aiops-e2e-migrate-idempotent.out || {
  printf '%s\n' "migrate apply did not report no-op" >&2
  exit 1
}

[ "$before" = "$after" ] || {
  printf '%s\n' "migrate apply should be idempotent when up to date" >&2
  exit 1
}

printf '%s\n' "ok: migrate apply idempotent"

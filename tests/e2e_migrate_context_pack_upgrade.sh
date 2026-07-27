#!/usr/bin/env sh
set -eu

repo_root="$(CDPATH= cd "$(dirname "$0")/.." && pwd)"
tmpdir="$(mktemp -d /tmp/aiops-e2e-migrate-context-pack.XXXXXX)"
trap 'rm -rf "$tmpdir"' EXIT INT TERM

current_version="$(cat "$repo_root/VERSION")"

ln -s "$repo_root" "$tmpdir/.ai"
cp -R "$repo_root/templates/ai_project/fast_track" "$tmpdir/.ai_project"
mkdir -p \
  "$tmpdir/.ai_project/tasks/active" \
  "$tmpdir/.ai_project/tasks/backlog" \
  "$tmpdir/.ai_project/tasks/archive" \
  "$tmpdir/.ai_project/handoffs" \
  "$tmpdir/.ai_knowledge"
cp "$repo_root/templates/ai_project/guided_full/ops_migration_plan.md" "$tmpdir/.ai_project/ops_migration_plan.md"
cp "$repo_root/templates/ai_knowledge/README.md" "$tmpdir/.ai_knowledge/README.md"
cp "$repo_root/templates/ai_knowledge/index.md" "$tmpdir/.ai_knowledge/index.md"
cp "$repo_root/templates/ai_knowledge/log.md" "$tmpdir/.ai_knowledge/log.md"
cp "$repo_root/templates/ai_knowledge/project_brief.md" "$tmpdir/.ai_knowledge/project_brief.md"

awk -v version="$current_version" '{ gsub(/\{\{CORE_VERSION\}\}/, version); print }' \
  "$tmpdir/.ai_project/operating_model.md" > "$tmpdir/.ai_project/operating_model.tmp"
mv "$tmpdir/.ai_project/operating_model.tmp" "$tmpdir/.ai_project/operating_model.md"

"$repo_root/bin/aiops" migrate --target "$tmpdir" --plan >/tmp/aiops-e2e-migrate-context-pack-plan.out

grep -q '.ai_knowledge/context_packs' /tmp/aiops-e2e-migrate-context-pack-plan.out || {
  printf '%s\n' "migrate plan did not include context_packs safe fix" >&2
  exit 1
}

"$repo_root/bin/aiops" migrate --target "$tmpdir" --apply >/tmp/aiops-e2e-migrate-context-pack-apply.out

[ -f "$tmpdir/.ai_knowledge/context_packs/_template.md" ] || {
  printf '%s\n' "migrate apply did not add context pack template" >&2
  exit 1
}

grep -q 'verification: passed' /tmp/aiops-e2e-migrate-context-pack-apply.out || {
  printf '%s\n' "migrate context pack upgrade did not verify" >&2
  exit 1
}

printf '%s\n' "ok: migrate context pack upgrade"

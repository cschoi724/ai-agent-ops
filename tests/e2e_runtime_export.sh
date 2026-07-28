#!/usr/bin/env sh
set -eu

repo_root="$(CDPATH= cd "$(dirname "$0")/.." && pwd)"
tmpdir="$(mktemp -d /tmp/aiops-e2e-runtime-export.XXXXXX)"
trap 'rm -rf "$tmpdir"' EXIT INT TERM

ln -s "$repo_root" "$tmpdir/.ai"
cp -R "$repo_root/templates/ai_project/fast_track" "$tmpdir/.ai_project"
mkdir -p \
  "$tmpdir/.ai_project/tasks/active" \
  "$tmpdir/.ai_project/tasks/backlog" \
  "$tmpdir/.ai_project/tasks/archive" \
  "$tmpdir/.ai_project/handoffs"

"$repo_root/bin/aiops" task create \
  --target "$tmpdir" \
  --id T-20260727-001 \
  --title "Runtime export task" \
  --workflow feature \
  --role "Lead Role" \
  --capability implementation \
  >/tmp/aiops-e2e-runtime-export-create.out

"$repo_root/bin/aiops" task transition T-20260727-001 \
  --target "$tmpdir" \
  --to approved \
  --role "Direction Role" \
  --by "Direction Agent" \
  --reason "approved for export test" \
  >/tmp/aiops-e2e-runtime-export-approved.out

"$repo_root/bin/aiops" task transition T-20260727-001 \
  --target "$tmpdir" \
  --to in_progress \
  --role "Execution Role" \
  --by "Execution Agent" \
  --reason "start export test" \
  >/tmp/aiops-e2e-runtime-export-progress.out

"$repo_root/bin/aiops" task transition T-20260727-001 \
  --target "$tmpdir" \
  --to verification_ready \
  --role "Execution Role" \
  --by "Execution Agent" \
  --reason "ready for verification" \
  >/tmp/aiops-e2e-runtime-export-ready.out

"$repo_root/bin/aiops" handoff create T-20260727-001 \
  --target "$tmpdir" \
  --from "Execution Role" \
  --to "Verification Role" \
  --from-agent "Execution Agent" \
  --to-agent "Verification Agent" \
  --next-action "verify exported task" \
  >/tmp/aiops-e2e-runtime-export-handoff.out

export_file="$tmpdir/.ai_project/runtime_export.json"
"$repo_root/bin/aiops" export runtime --target "$tmpdir" --output "$export_file" >/tmp/aiops-e2e-runtime-export.out

[ -f "$export_file" ] || {
  printf '%s\n' "runtime export file was not created" >&2
  exit 1
}

ruby -rjson -e '
  data = JSON.parse(File.read(ARGV[0]))
  abort("wrong schema") unless data["schema"] == "aiops.runtime_export.v1"
  abort("missing task") unless data["tasks"].any? { |task| task["id"] == "T-20260727-001" && task["status"] == "verification_ready" }
  abort("missing handoff") unless data["handoffs"].any? { |handoff| handoff["task_id"] == "T-20260727-001" && handoff["to_role"] == "Verification Role" }
  abort("missing checkpoint") unless data["approval_checkpoints"].any? { |checkpoint| checkpoint["task_id"] == "T-20260727-001" }
  abort("missing adapter contract") unless data["adapter_contract"]["handoff_events"] == "handoffs[]"
' "$export_file"

"$repo_root/bin/aiops" export runtime --target "$tmpdir" >/tmp/aiops-e2e-runtime-export-stdout.json
ruby -rjson -e 'JSON.parse(File.read(ARGV[0])); puts "ok"' /tmp/aiops-e2e-runtime-export-stdout.json >/tmp/aiops-e2e-runtime-export-json.out

printf '%s\n' "ok: runtime export"

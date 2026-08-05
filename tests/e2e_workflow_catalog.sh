#!/usr/bin/env sh
set -eu

repo_root="$(CDPATH= cd "$(dirname "$0")/.." && pwd)"
tmpdir="$(mktemp -d /tmp/aiops-e2e-workflow-catalog.XXXXXX)"
trap 'rm -rf "$tmpdir"' EXIT INT TERM

"$repo_root/bin/aiops" validate workflow-catalog --core "$repo_root" >/tmp/aiops-e2e-workflow-catalog-validate.out
grep -q 'ok: workflow catalog' /tmp/aiops-e2e-workflow-catalog-validate.out || {
  printf '%s\n' "workflow catalog validate did not pass" >&2
  exit 1
}

ruby -rjson -e '
  catalog = JSON.parse(File.read(ARGV[0]))
  abort("wrong schema") unless catalog["schema"] == "aiops.workflow_catalog.v1"
  feature = catalog.fetch("workflows").fetch("feature")
  statuses = feature.fetch("statuses")
  abort("approved should be checkpoint") unless statuses.fetch("approved").fetch("checkpoint") == true
  abort("approved should be required") unless statuses.fetch("approved").fetch("canonical_publish") == "required"
  abort("in_progress should not be checkpoint") unless statuses.fetch("in_progress").fetch("checkpoint") == false
  abort("in_progress should not require publish") unless statuses.fetch("in_progress").fetch("canonical_publish") == "not_required"
  abort("verification_ready should be recommended") unless statuses.fetch("verification_ready").fetch("canonical_publish") == "recommended"
  abort("bugfix should inherit feature") unless catalog.fetch("workflows").fetch("bugfix").fetch("inherits") == "feature"
' "$repo_root/runtime/workflows.json"

ln -s "$repo_root" "$tmpdir/.ai"
mkdir -p "$tmpdir/.ai_project/tasks/active" "$tmpdir/.ai_project/tasks/backlog" "$tmpdir/.ai_project/tasks/archive"
printf '# Source of Truth\n' > "$tmpdir/.ai_project/source_of_truth.md"

"$repo_root/bin/aiops" task create \
  --target "$tmpdir" \
  --id T-20260805-005 \
  --title "Workflow catalog checkpoint" \
  --workflow feature \
  --role "Lead Role" \
  --capability planning \
  --allowed-path src/ \
  --source-of-truth .ai_project/source_of_truth.md \
  --created-by "Lead Agent" \
  >/tmp/aiops-e2e-workflow-catalog-create.out

"$repo_root/bin/aiops" task transition T-20260805-005 \
  --target "$tmpdir" \
  --to approved \
  --role "Direction Role" \
  --by "Direction Agent" \
  --reason "checkpoint metadata" \
  >/tmp/aiops-e2e-workflow-catalog-transition.out

grep -q 'workflow: feature' /tmp/aiops-e2e-workflow-catalog-transition.out || {
  printf '%s\n' "transition did not report workflow" >&2
  exit 1
}
grep -q 'checkpoint: true' /tmp/aiops-e2e-workflow-catalog-transition.out || {
  printf '%s\n' "transition did not report checkpoint" >&2
  exit 1
}
grep -q 'canonical_publish: required' /tmp/aiops-e2e-workflow-catalog-transition.out || {
  printf '%s\n' "transition did not report canonical publish policy" >&2
  exit 1
}
grep -q 'checkpoint_note: publish this checkpoint to the project canonical status ref' /tmp/aiops-e2e-workflow-catalog-transition.out || {
  printf '%s\n' "transition did not explain checkpoint publish guidance" >&2
  exit 1
}

printf '%s\n' "ok: workflow catalog"

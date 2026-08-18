#!/usr/bin/env sh
set -eu

repo_root="$(CDPATH= cd "$(dirname "$0")/.." && pwd)"
tmpdir="$(mktemp -d /tmp/aiops-e2e-handoff-flow.XXXXXX)"
trap 'rm -rf "$tmpdir"' EXIT INT TERM

ln -s "$repo_root" "$tmpdir/.ai"
mkdir -p "$tmpdir/.ai_project/tasks/active" "$tmpdir/.ai_project/tasks/backlog" "$tmpdir/.ai_project/tasks/archive"
printf '# Source of Truth\n' > "$tmpdir/.ai_project/source_of_truth.md"

"$repo_root/bin/aiops" task create \
  --target "$tmpdir" \
  --id T-20260727-010 \
  --title "Handoff flow validation" \
  --workflow feature \
  --role "Lead Role" \
  --capability planning \
  --allowed-path src/ \
  --source-of-truth .ai_project/source_of_truth.md \
  --created-by "Lead Agent" \
  >/tmp/aiops-e2e-handoff-task-create.out

"$repo_root/bin/aiops" task transition T-20260727-010 \
  --target "$tmpdir" \
  --to approved \
  --role "Direction Role" \
  --by "Lead Agent" \
  >/tmp/aiops-e2e-handoff-task-approved.out

"$repo_root/bin/aiops" task transition T-20260727-010 \
  --target "$tmpdir" \
  --to in_progress \
  --role "Execution Role" \
  --by "Dev Agent" \
  >/tmp/aiops-e2e-handoff-task-progress.out

"$repo_root/bin/aiops" task transition T-20260727-010 \
  --target "$tmpdir" \
  --to verification_ready \
  --role "Execution Role" \
  --by "Dev Agent" \
  >/tmp/aiops-e2e-handoff-task-ready.out

"$repo_root/bin/aiops" handoff create T-20260727-010 \
  --target "$tmpdir" \
  --from "Execution Role" \
  --to "Verification Role" \
  --from-agent "Dev Agent" \
  --to-agent "QA Agent" \
  --next-action "task report와 변경 파일을 기준으로 검증" \
  --summary "implementation ready for verification" \
  --changed-path src/ \
  --validation-result not_run \
  >/tmp/aiops-e2e-handoff-create.out

grep -q 'created: .ai_project/handoffs/T-20260727-010_execution_to_verification.md' /tmp/aiops-e2e-handoff-create.out || {
  printf '%s\n' "handoff create did not report expected path" >&2
  exit 1
}

handoff_file="$tmpdir/.ai_project/handoffs/T-20260727-010_execution_to_verification.md"

"$repo_root/bin/aiops" handoff validate "$handoff_file" --strict >/tmp/aiops-e2e-handoff-validate-file.out
grep -q 'ok: handoff metadata' /tmp/aiops-e2e-handoff-validate-file.out || {
  printf '%s\n' "handoff validate file did not pass" >&2
  exit 1
}

"$repo_root/bin/aiops" handoff validate T-20260727-010 --target "$tmpdir" --strict >/tmp/aiops-e2e-handoff-validate-task.out
grep -q 'ok: handoff metadata' /tmp/aiops-e2e-handoff-validate-task.out || {
  printf '%s\n' "handoff validate by task id did not pass" >&2
  exit 1
}

"$repo_root/bin/aiops" validate handoff "$handoff_file" --strict >/tmp/aiops-e2e-handoff-validate-subject.out
grep -q 'ok: handoff metadata' /tmp/aiops-e2e-handoff-validate-subject.out || {
  printf '%s\n' "validate handoff subject did not pass" >&2
  exit 1
}

handoff_with_ids="$tmpdir/.ai_project/handoffs/T-20260727-010_with_ids.md"
cp "$handoff_file" "$handoff_with_ids"
perl -0pi -e 's/from_agent: Dev Agent/from_agent_id: dev-agent\nfrom_agent: Dev Agent/; s/to_agent: QA Agent/to_agent_id: qa-agent\nto_agent: QA Agent/' "$handoff_with_ids"
"$repo_root/bin/aiops" validate handoff "$handoff_with_ids" --strict >/dev/null

for mutation in numeric bad_pattern control_character; do
  invalid_id_handoff="$tmpdir/.ai_project/handoffs/T-20260727-010_${mutation}.md"
  cp "$handoff_with_ids" "$invalid_id_handoff"
  case "$mutation" in
    numeric) perl -0pi -e 's/from_agent_id: dev-agent/from_agent_id: 42/' "$invalid_id_handoff" ;;
    bad_pattern) perl -0pi -e 's/to_agent_id: qa-agent/to_agent_id: BAD_ID/' "$invalid_id_handoff" ;;
    control_character) perl -0pi -e 's/to_agent_id: qa-agent/to_agent_id: "qa\\tagent"/' "$invalid_id_handoff" ;;
  esac
  if "$repo_root/bin/aiops" validate handoff "$invalid_id_handoff" --strict >/dev/null 2>&1; then
    printf '%s\n' "handoff accepted invalid Agent ID: $mutation" >&2
    exit 1
  fi
done

cat > "$tmpdir/.ai_project/handoffs/T-20260727-010_bad.md" <<'EOF'
---
schema: aiops.handoff.v1
task_id: T-20260727-010
from_role: Execution Role
to_role: Verification Role
current_status: verification_ready
next_action: 검증
source_of_truth:
  - .ai_project/source_of_truth.md
---

# Bad Handoff
EOF

if "$repo_root/bin/aiops" handoff validate "$tmpdir/.ai_project/handoffs/T-20260727-010_bad.md" --strict >/tmp/aiops-e2e-handoff-invalid.out 2>&1; then
  printf '%s\n' "invalid handoff should fail" >&2
  exit 1
fi

grep -q 'missing: allowed_paths' /tmp/aiops-e2e-handoff-invalid.out || {
  printf '%s\n' "invalid handoff did not report missing allowed_paths" >&2
  exit 1
}

grep -q 'handoff: Execution Role -> Verification Role' "$tmpdir/.ai_project/tasks/active/T-20260727-010.md" || {
  printf '%s\n' "task event did not record handoff" >&2
  exit 1
}

printf '%s\n' "ok: handoff flow"

#!/usr/bin/env sh
set -eu

repo_root="$(CDPATH= cd "$(dirname "$0")/.." && pwd)"
tmpdir="$(mktemp -d /tmp/aiops-e2e-transition-receipt.XXXXXX)"
trap 'rm -rf "$tmpdir"' EXIT INT TERM

cat > "$tmpdir/valid.json" <<'EOF'
{
  "schema": "aiops.transition_receipt.v1",
  "task_id": "T-20260813-001",
  "transition": {
    "from": "in_progress",
    "to": "verification_ready"
  },
  "actor": {
    "agent": "iOS Agent",
    "role": "Execution Role"
  },
  "next": {
    "agent": "iOS QA Agent",
    "role": "Verification Role",
    "action": "독립 검증"
  },
  "result": "ready",
  "summary": "구현 및 자체 검증 완료",
  "evidence": [".ai_project/reports/T-20260813-001-task-report.md"],
  "risks": [],
  "blockers": []
}
EOF

"$repo_root/bin/aiops" validate transition-receipt "$tmpdir/valid.json" >"$tmpdir/valid.out"
grep -q 'ok: transition receipt' "$tmpdir/valid.out" || {
  printf '%s\n' "valid transition receipt did not pass" >&2
  exit 1
}

cat > "$tmpdir/skip.json" <<'EOF'
{
  "schema": "aiops.transition_receipt.v1",
  "task_id": "T-20260813-002",
  "transition": {"from": "approved", "to": "in_progress"},
  "actor": {"agent": "Docs Agent", "role": "Execution Role"},
  "next": {"role": "Completion Role", "action": "변경 범위 확인"},
  "result": "ready",
  "summary": "문서 상태 전이",
  "evidence": [],
  "validation_skip_reason": "제품 코드 변경이 없는 상태-only 전이",
  "risks": [],
  "blockers": []
}
EOF

"$repo_root/bin/aiops" validate transition-receipt "$tmpdir/skip.json" >/dev/null

for field in task_id transition actor next result summary evidence risks blockers; do
  ruby -rjson -e 'data = JSON.parse(File.read(ARGV[0])); data.delete(ARGV[1]); puts JSON.pretty_generate(data)' \
    "$tmpdir/valid.json" "$field" >"$tmpdir/missing-$field.json"
  if "$repo_root/bin/aiops" validate transition-receipt "$tmpdir/missing-$field.json" >"$tmpdir/missing-$field.out" 2>&1; then
    printf '%s\n' "receipt missing $field should fail" >&2
    exit 1
  fi
done

ruby -rjson -e '
  data = JSON.parse(File.read(ARGV[0]))
  data["next"].delete("agent")
  data["next"].delete("role")
  puts JSON.pretty_generate(data)
' "$tmpdir/valid.json" >"$tmpdir/missing-next-owner.json"
if "$repo_root/bin/aiops" validate transition-receipt "$tmpdir/missing-next-owner.json" >/dev/null 2>&1; then
  printf '%s\n' "receipt missing next owner should fail" >&2
  exit 1
fi

ruby -rjson -e '
  data = JSON.parse(File.read(ARGV[0]))
  data["evidence"] = []
  puts JSON.pretty_generate(data)
' "$tmpdir/valid.json" >"$tmpdir/missing-evidence.json"
if "$repo_root/bin/aiops" validate transition-receipt "$tmpdir/missing-evidence.json" >/dev/null 2>&1; then
  printf '%s\n' "receipt missing evidence and skip reason should fail" >&2
  exit 1
fi

printf '%s\n' "ok: transition receipt contract"

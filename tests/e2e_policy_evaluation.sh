#!/usr/bin/env sh
set -eu

repo_root="$(CDPATH= cd "$(dirname "$0")/.." && pwd)"
tmpdir="$(mktemp -d /tmp/aiops-e2e-policy-evaluation.XXXXXX)"
trap 'rm -rf "$tmpdir"' EXIT INT TERM

empty_project="$tmpdir/empty"
mkdir -p "$empty_project"

"$repo_root/bin/aiops" policy evaluate --target "$empty_project" --json > "$tmpdir/empty-policy.json"
"$repo_root/bin/aiops" project snapshot --target "$empty_project" --json > "$tmpdir/empty-snapshot.json"
"$repo_root/bin/aiops" validate policy-evaluation "$tmpdir/empty-policy.json" >/dev/null
ruby -rjson -e '
  data = JSON.parse(File.read(ARGV[0]))
  snapshot = JSON.parse(File.read(ARGV[1]))
  ids = data.fetch("matched_rules").map { |rule| rule["id"] }
  snapshot_ids = snapshot.dig("policy", "matched_rules").map { |rule| rule["id"] }
  abort("core_missing not matched") unless ids.include?("core_missing")
  abort("project_config_missing not matched") unless ids.include?("project_config_missing")
  abort("snapshot core_missing not matched") unless snapshot_ids.include?("core_missing")
  abort("snapshot project_config_missing not matched") unless snapshot_ids.include?("project_config_missing")
  abort("expected blocker summary") unless data.dig("summary", "blocker").to_i >= 2
' "$tmpdir/empty-policy.json" "$tmpdir/empty-snapshot.json"

partial_project="$tmpdir/partial"
mkdir -p "$partial_project/.ai_project/tasks/active"
ln -s "$repo_root" "$partial_project/.ai"
cat > "$partial_project/.ai_project/operating_model.md" <<'EOF'
---
schema: aiops.operating_model.v1
project: PartialPolicyProject
operating_mode: solo_light
workflow_policy: standard_vnext
knowledge_mode: minimal
---

# Partial Policy Project
EOF

"$repo_root/bin/aiops" policy evaluate --target "$partial_project" --json > "$tmpdir/partial-policy.json"
"$repo_root/bin/aiops" validate policy-evaluation "$tmpdir/partial-policy.json" >/dev/null
ruby -rjson -e '
  data = JSON.parse(File.read(ARGV[0]))
  ids = data.fetch("matched_rules").map { |rule| rule["id"] }
  abort("required_project_file_missing not matched") unless ids.include?("required_project_file_missing")
  abort("required_project_dir_missing not matched") unless ids.include?("required_project_dir_missing")
' "$tmpdir/partial-policy.json"

team_project="$tmpdir/team"
mkdir -p \
  "$team_project/.ai_project/tasks/active" \
  "$team_project/.ai_project/tasks/backlog" \
  "$team_project/.ai_project/tasks/archive"
ln -s "$repo_root" "$team_project/.ai"
for file in current_context.md source_of_truth.md task_board.md ops_decisions.md ops_issues.md; do
  printf '# %s\n' "$file" > "$team_project/.ai_project/$file"
done
cat > "$team_project/.ai_project/operating_model.md" <<'EOF'
---
schema: aiops.operating_model.v1
project: TeamPolicyProject
operating_mode: team_basic
team_pattern: multi_team
coordination: parallel_with_locks
workflow_policy: standard_vnext
knowledge_mode: minimal
---

# Team Policy Project
EOF
cat > "$team_project/.ai_project/agent_registry.md" <<'EOF'
---
schema: aiops.agent_registry.v1
project: TeamPolicyProject
agents: []
---

# Agent Registry
EOF

"$repo_root/bin/aiops" policy evaluate --target "$team_project" --strict-level basic --json > "$tmpdir/team-basic-policy.json"
"$repo_root/bin/aiops" policy evaluate --target "$team_project" --strict-level team --json > "$tmpdir/team-team-policy.json"
ruby -rjson -e '
  basic = JSON.parse(File.read(ARGV[0]))
  team = JSON.parse(File.read(ARGV[1]))
  basic_ids = basic.fetch("matched_rules").map { |rule| rule["id"] }
  team_ids = team.fetch("matched_rules").map { |rule| rule["id"] }
  abort("team-only rule matched in basic") if basic_ids.include?("canonical_status_ref_required_for_team")
  abort("team-only rule missing in team") unless team_ids.include?("canonical_status_ref_required_for_team")
' "$tmpdir/team-basic-policy.json" "$tmpdir/team-team-policy.json"

if "$repo_root/bin/aiops" policy evaluate --target "$team_project" --strict-level unknown --json >/tmp/aiops-e2e-policy-eval-invalid-level.out 2>&1; then
  printf '%s\n' "unknown strict level should fail" >&2
  exit 1
fi
grep -q 'unknown strict level' /tmp/aiops-e2e-policy-eval-invalid-level.out || {
  printf '%s\n' "unknown strict level error absent" >&2
  cat /tmp/aiops-e2e-policy-eval-invalid-level.out >&2
  exit 1
}

stale_remote="$tmpdir/remote.git"
stale_project="$tmpdir/stale"
git init --bare "$stale_remote" >/dev/null 2>&1
git init -b develop "$stale_project" >/dev/null
git -C "$stale_project" config user.email "aiops@example.test"
git -C "$stale_project" config user.name "AI Ops Test"
git -C "$stale_project" remote add origin "$stale_remote"
ln -s "$repo_root" "$stale_project/.ai"
mkdir -p \
  "$stale_project/.ai_project/tasks/active" \
  "$stale_project/.ai_project/tasks/backlog" \
  "$stale_project/.ai_project/tasks/archive"
for file in current_context.md source_of_truth.md task_board.md ops_decisions.md ops_issues.md; do
  printf '# %s\n' "$file" > "$stale_project/.ai_project/$file"
done
cat > "$stale_project/.ai_project/operating_model.md" <<'EOF'
---
schema: aiops.operating_model.v1
project: StalePolicyProject
operating_mode: team_basic
team_pattern: multi_team
coordination: parallel_with_locks
workflow_policy: standard_vnext
canonical_status_ref: origin/develop
policy_level: team
knowledge_mode: minimal
---

# Stale Policy Project
EOF
cat > "$stale_project/.ai_project/agent_registry.md" <<'EOF'
---
schema: aiops.agent_registry.v1
project: StalePolicyProject
agents: []
---

# Agent Registry
EOF
git -C "$stale_project" add .ai .ai_project >/dev/null
git -C "$stale_project" commit -m "seed stale policy fixture" >/dev/null
git -C "$stale_project" push -u origin develop >/dev/null 2>&1
"$repo_root/bin/aiops" sync-status --target "$stale_project" >/dev/null
printf '%s\n' "advance" > "$stale_project/advance.txt"
git -C "$stale_project" add advance.txt >/dev/null
git -C "$stale_project" commit -m "advance canonical" >/dev/null
git -C "$stale_project" push origin develop >/dev/null 2>&1
git -C "$stale_project" fetch origin develop >/dev/null 2>&1

"$repo_root/bin/aiops" project snapshot --target "$stale_project" --json > "$tmpdir/stale-snapshot.json"
"$repo_root/bin/aiops" validate project-snapshot "$tmpdir/stale-snapshot.json" >/dev/null
"$repo_root/bin/aiops" policy evaluate --snapshot "$tmpdir/stale-snapshot.json" --json > "$tmpdir/stale-policy.json"
"$repo_root/bin/aiops" validate policy-evaluation "$tmpdir/stale-policy.json" >/dev/null
before_snapshot="$(cksum "$tmpdir/stale-snapshot.json")"
"$repo_root/bin/aiops" policy evaluate --snapshot "$tmpdir/stale-snapshot.json" --json >/dev/null
after_snapshot="$(cksum "$tmpdir/stale-snapshot.json")"
[ "$before_snapshot" = "$after_snapshot" ] || {
  printf '%s\n' "policy evaluate modified snapshot input" >&2
  exit 1
}
ruby -rjson -e '
  snapshot = JSON.parse(File.read(ARGV[0]))
  policy = JSON.parse(File.read(ARGV[1]))
  snapshot_ids = snapshot.dig("policy", "matched_rules").map { |rule| rule["id"] }
  policy_ids = policy.fetch("matched_rules").map { |rule| rule["id"] }
  abort("snapshot policy missing canonical_status_stale") unless snapshot_ids.include?("canonical_status_stale")
  abort("policy evaluate missing canonical_status_stale") unless policy_ids.include?("canonical_status_stale")
  abort("snapshot can_transition should be false") unless snapshot.dig("control", "can_transition") == false
' "$tmpdir/stale-snapshot.json" "$tmpdir/stale-policy.json"

custom_project="$tmpdir/custom"
mkdir -p \
  "$custom_project/.ai/runtime" \
  "$custom_project/.ai_project/tasks/active" \
  "$custom_project/.ai_project/tasks/backlog" \
  "$custom_project/.ai_project/tasks/archive"
printf '%s\n' "0.0.0-test" > "$custom_project/.ai/VERSION"
cp "$repo_root/runtime/workflows.json" "$custom_project/.ai/runtime/workflows.json"
cat > "$custom_project/.ai/runtime/policy_rules.json" <<'EOF'
{
  "schema": "aiops.policy_rules.v1",
  "version": "0.0.0-test",
  "strict_levels": [
    {
      "id": "basic",
      "description": "Basic"
    }
  ],
  "rules": [
    {
      "id": "custom_core_present",
      "severity": "info",
      "source": "project_snapshot",
      "message": "Custom local policy catalog was used.",
      "applies_to": ["basic"],
      "when": {
        "core.present": true
      }
    }
  ]
}
EOF
for file in current_context.md source_of_truth.md task_board.md ops_decisions.md ops_issues.md; do
  printf '# %s\n' "$file" > "$custom_project/.ai_project/$file"
done
cat > "$custom_project/.ai_project/operating_model.md" <<'EOF'
---
schema: aiops.operating_model.v1
project: CustomPolicyProject
operating_mode: solo_light
workflow_policy: standard_vnext
knowledge_mode: minimal
---

# Custom Policy Project
EOF
cat > "$custom_project/.ai_project/agent_registry.md" <<'EOF'
---
schema: aiops.agent_registry.v1
project: CustomPolicyProject
agents: []
---

# Agent Registry
EOF
"$repo_root/bin/aiops" project snapshot --target "$custom_project" --json > "$tmpdir/custom-snapshot.json"
"$repo_root/bin/aiops" policy evaluate --target "$custom_project" --json > "$tmpdir/custom-policy-target.json"
"$repo_root/bin/aiops" policy evaluate --snapshot "$tmpdir/custom-snapshot.json" --json > "$tmpdir/custom-policy-snapshot.json"
ruby -rjson -e '
  snapshot = JSON.parse(File.read(ARGV[0]))
  target_policy = JSON.parse(File.read(ARGV[1]))
  snapshot_policy = JSON.parse(File.read(ARGV[2]))
  snapshot_ids = snapshot.dig("policy", "matched_rules").map { |rule| rule["id"] }
  target_ids = target_policy.fetch("matched_rules").map { |rule| rule["id"] }
  from_snapshot_ids = snapshot_policy.fetch("matched_rules").map { |rule| rule["id"] }
  abort("snapshot did not use custom policy catalog") unless snapshot_ids.include?("custom_core_present")
  abort("--target did not use custom policy catalog") unless target_ids.include?("custom_core_present")
  abort("--snapshot did not use snapshot target policy catalog") unless from_snapshot_ids.include?("custom_core_present")
' "$tmpdir/custom-snapshot.json" "$tmpdir/custom-policy-target.json" "$tmpdir/custom-policy-snapshot.json"

printf '%s\n' "not-json" > "$tmpdir/bad-snapshot.json"
if "$repo_root/bin/aiops" policy evaluate --snapshot "$tmpdir/bad-snapshot.json" --json >/tmp/aiops-e2e-policy-eval-bad-snapshot.out 2>&1; then
  printf '%s\n' "bad snapshot should fail" >&2
  exit 1
fi

printf '{}\n' > "$tmpdir/schema-invalid-snapshot.json"
if "$repo_root/bin/aiops" policy evaluate --snapshot "$tmpdir/schema-invalid-snapshot.json" --json >/tmp/aiops-e2e-policy-eval-invalid-snapshot.out 2>&1; then
  printf '%s\n' "schema-invalid snapshot should fail" >&2
  exit 1
fi
grep -q 'snapshot failed project-snapshot schema validation' /tmp/aiops-e2e-policy-eval-invalid-snapshot.out || {
  printf '%s\n' "schema-invalid snapshot error absent" >&2
  cat /tmp/aiops-e2e-policy-eval-invalid-snapshot.out >&2
  exit 1
}

printf '%s\n' "ok: policy evaluation"

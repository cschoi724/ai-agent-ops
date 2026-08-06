#!/usr/bin/env sh
set -eu

repo_root="$(CDPATH= cd "$(dirname "$0")/.." && pwd)"
tmpdir="$(mktemp -d /tmp/aiops-e2e-project-snapshot.XXXXXX)"
trap 'rm -rf "$tmpdir"' EXIT INT TERM

assert_snapshot_contract() {
  "$repo_root/bin/aiops" validate project-snapshot "$1" >/dev/null
  ruby -rjson -e '
    data = JSON.parse(File.read(ARGV[0]))

    abort("wrong schema") unless data["schema"] == "aiops.project_snapshot.v1"
    %w[schema core_version generated_at target source_refs core project agents tasks workflow policy health control checks next].each do |key|
      abort("missing required snapshot key #{key}") unless data.key?(key)
    end

    abort("health overall invalid") unless %w[ok warning blocked].include?(data.dig("health", "overall"))
    abort("health warnings not numeric") unless data.dig("health", "warnings").is_a?(Integer)
    abort("health blockers not numeric") unless data.dig("health", "blockers").is_a?(Integer)
    abort("tasks total not numeric") unless data.dig("tasks", "total").is_a?(Integer)
    abort("tasks active not numeric") unless data.dig("tasks", "active").is_a?(Integer)
    abort("status_ref_state invalid") unless %w[unresolved ref_not_found_locally not_recorded recorded_current recorded_stale].include?(data.dig("source_refs", "status_ref_state"))
    abort("policy strict level missing") unless data.dig("policy", "strict_level").is_a?(String)
    abort("policy matched_rules not array") unless data.dig("policy", "matched_rules").is_a?(Array)

    control = data.fetch("control")
    %w[can_start_task can_transition can_commit can_push can_merge].each do |key|
      abort("control #{key} not boolean") unless [true, false].include?(control[key])
    end
    %w[commit push create_pr merge deploy external_configuration_changes].each do |action|
      abort("approval missing #{action}") unless control.fetch("requires_user_approval").include?(action)
    end

    data.fetch("checks").each do |check|
      abort("check id missing") unless check["id"].is_a?(String) && !check["id"].empty?
      abort("check severity invalid") unless %w[info warn blocker].include?(check["severity"])
      abort("check confidence invalid") unless %w[low medium high].include?(check["confidence"])
      abort("check message missing") unless check["message"].is_a?(String) && !check["message"].empty?
      abort("check evidence missing") unless check["evidence"].is_a?(Hash)
    end

    data.fetch("next").each do |step|
      abort("next audience invalid") unless %w[agent user].include?(step["audience"])
      abort("next action missing") unless step["action"].is_a?(String) && !step["action"].empty?
      abort("next command or message missing") unless step["command"].is_a?(String) || step["message"].is_a?(String)
    end
  ' "$1"
}

empty_project="$tmpdir/empty"
mkdir -p "$empty_project"
"$repo_root/bin/aiops" project snapshot --target "$empty_project" --json > "$tmpdir/empty.json"
assert_snapshot_contract "$tmpdir/empty.json"
ruby -rjson -e '
  data = JSON.parse(File.read(ARGV[0]))
  abort("empty project should be blocked") unless data.dig("health", "overall") == "blocked"
  abort("core_missing missing") unless data["checks"].any? { |check| check["id"] == "core_missing" && check["severity"] == "blocker" }
  abort("project_config_missing missing") unless data["checks"].any? { |check| check["id"] == "project_config_missing" && check["severity"] == "blocker" }
  abort("can_start_task should be false") unless data.dig("control", "can_start_task") == false
' "$tmpdir/empty.json"

seed_project="$tmpdir/seed-only"
mkdir -p "$seed_project"
"$repo_root/bin/aiops" seed --target "$seed_project" --adapter both --mode link --core "$repo_root" >/dev/null
"$repo_root/bin/aiops" project snapshot --target "$seed_project" --json > "$tmpdir/seed-only.json"
assert_snapshot_contract "$tmpdir/seed-only.json"
ruby -rjson -e '
  data = JSON.parse(File.read(ARGV[0]))
  abort("seed-only core should be present") unless data.dig("core", "present") == true
  abort("seed-only adapters missing") unless data.dig("core", "adapters", "codex") == true && data.dig("core", "adapters", "claude") == true
  abort("seed-only project should be missing") unless data.dig("project", "present") == false
' "$tmpdir/seed-only.json"

fast_project="$tmpdir/fast"
mkdir -p "$fast_project"
ln -s "$repo_root" "$fast_project/.ai"
cp -R "$repo_root/templates/ai_project/fast_track" "$fast_project/.ai_project"
mkdir -p "$fast_project/.ai_project/tasks/active" "$fast_project/.ai_project/tasks/backlog" "$fast_project/.ai_project/tasks/archive"
"$repo_root/bin/aiops" project snapshot --target "$fast_project" --json > "$tmpdir/fast.json"
assert_snapshot_contract "$tmpdir/fast.json"
ruby -rjson -e '
  data = JSON.parse(File.read(ARGV[0]))
  abort("fast project should be present") unless data.dig("project", "present") == true
  abort("fast project name should be a string") unless data.dig("project", "name").is_a?(String)
  abort("fast operating_mode should be a string") unless data.dig("project", "operating_mode").is_a?(String)
  abort("fast workflow_policy should be a string") unless data.dig("project", "workflow_policy").is_a?(String)
  abort("fast placeholder warning missing") unless data["checks"].any? { |check| check["id"] == "project_field_type_invalid" }
  abort("fast project should have unresolved status ref") unless data.dig("source_refs", "status_ref_state") == "unresolved"
' "$tmpdir/fast.json"
ruby -rjson -e '
  data = JSON.parse(File.read(ARGV[0]))
  data["project"]["name"] = { "placeholder" => "PROJECT_NAME" }
  File.write(ARGV[1], JSON.pretty_generate(data))
' "$tmpdir/fast.json" "$tmpdir/invalid-snapshot.json"
if "$repo_root/bin/aiops" validate project-snapshot "$tmpdir/invalid-snapshot.json" >/dev/null 2>&1; then
  printf '%s\n' "invalid project snapshot unexpectedly passed" >&2
  exit 1
fi

guided_project="$tmpdir/guided"
mkdir -p "$guided_project"
ln -s "$repo_root" "$guided_project/.ai"
cp -R "$repo_root/templates/ai_project/guided_full" "$guided_project/.ai_project"
mkdir -p "$guided_project/.ai_project/tasks/active" "$guided_project/.ai_project/tasks/backlog" "$guided_project/.ai_project/tasks/archive"
"$repo_root/bin/aiops" project snapshot --target "$guided_project" --json > "$tmpdir/guided.json"
assert_snapshot_contract "$tmpdir/guided.json"
ruby -rjson -e '
  data = JSON.parse(File.read(ARGV[0]))
  abort("guided project name should be a string") unless data.dig("project", "name").is_a?(String)
  abort("guided operating_mode should be a string") unless data.dig("project", "operating_mode").is_a?(String)
  abort("guided workflow_policy should be a string") unless data.dig("project", "workflow_policy").is_a?(String)
  abort("guided placeholder warning missing") unless data["checks"].any? { |check| check["id"] == "project_field_type_invalid" }
' "$tmpdir/guided.json"

space_project="$tmpdir/space project"
mkdir -p "$space_project"
"$repo_root/bin/aiops" project snapshot --target "$space_project" --json > "$tmpdir/space.json"
assert_snapshot_contract "$tmpdir/space.json"
ruby -rjson -rshellwords -e '
  data = JSON.parse(File.read(ARGV[0]))
  target = ARGV[1]
  command = data.fetch("next").find { |step| step["action"] == "seed_project" }.fetch("command")
  parts = Shellwords.split(command)
  index = parts.index("--target")
  abort("seed command missing --target") unless index
  abort("space target was not preserved") unless parts[index + 1] == target
' "$tmpdir/space.json" "$space_project"

remote="$tmpdir/remote.git"
stale_project="$tmpdir/stale"
git init --bare "$remote" >/dev/null 2>&1
git init -b develop "$stale_project" >/dev/null
git -C "$stale_project" config user.email "aiops@example.test"
git -C "$stale_project" config user.name "AI Ops Test"
git -C "$stale_project" remote add origin "$remote"
ln -s "$repo_root" "$stale_project/.ai"
cp -R "$repo_root/templates/ai_project/fast_track" "$stale_project/.ai_project"
mkdir -p "$stale_project/.ai_project/tasks/active" "$stale_project/.ai_project/tasks/backlog" "$stale_project/.ai_project/tasks/archive"

ruby -e '
  path = ARGV[0]
  text = File.read(path)
  text = text.gsub(/^canonical_status_ref:.*$/, "canonical_status_ref: origin/develop")
  File.write(path, text)
' "$stale_project/.ai_project/operating_model.md"

git -C "$stale_project" add .ai .ai_project >/dev/null
git -C "$stale_project" commit -m "seed stale fixture" >/dev/null
git -C "$stale_project" push -u origin develop >/dev/null 2>&1
"$repo_root/bin/aiops" sync-status --target "$stale_project" >/dev/null
printf '%s\n' "stale marker" > "$stale_project/stale.txt"
git -C "$stale_project" add stale.txt >/dev/null
git -C "$stale_project" commit -m "advance canonical ref" >/dev/null
git -C "$stale_project" push origin develop >/dev/null 2>&1
git -C "$stale_project" fetch origin develop >/dev/null 2>&1

before_hash="$(find "$stale_project" -type f -not -path '*/.git/*' -print | sort | xargs shasum -a 256 | shasum -a 256 | awk "{print \$1}")"
"$repo_root/bin/aiops" project snapshot --target "$stale_project" --json > "$tmpdir/stale.json"
after_hash="$(find "$stale_project" -type f -not -path '*/.git/*' -print | sort | xargs shasum -a 256 | shasum -a 256 | awk "{print \$1}")"
[ "$before_hash" = "$after_hash" ] || {
  printf '%s\n' "snapshot command modified project files" >&2
  exit 1
}
assert_snapshot_contract "$tmpdir/stale.json"
ruby -rjson -e '
  data = JSON.parse(File.read(ARGV[0]))
  abort("expected recorded_stale") unless data.dig("source_refs", "status_ref_state") == "recorded_stale"
  abort("expected blocked transition") unless data.dig("control", "blocked_actions").any? { |action| action["action"] == "task_transition" && action["reason"].include?("canonical") }
  abort("expected stale check") unless data["checks"].any? { |check| check["id"] == "canonical_status_stale" && check["severity"] == "warn" }
' "$tmpdir/stale.json"

printf '%s\n' "ok: project snapshot"

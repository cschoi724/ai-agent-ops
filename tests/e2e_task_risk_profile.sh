#!/usr/bin/env sh
set -eu

repo_root="$(CDPATH= cd "$(dirname "$0")/.." && pwd)"
tmpdir="$(mktemp -d "${TMPDIR:-/tmp}/aiops-e2e-risk-profile.XXXXXX")"
trap 'rm -rf "$tmpdir"' EXIT INT TERM
project="$tmpdir/project"
mkdir -p "$project/.ai_project/tasks/active" "$project/.ai_project/reports" "$project/.ai_project/handoffs" "$project/docs" "$project/src" "$project/schemas"
ln -s "$repo_root" "$project/.ai"

cat > "$project/.ai_project/agent_registry.md" <<'EOF'
---
schema: aiops.agent_registry.v1
project: Risk Profile Fixture
agents:
  - id: Lead Agent
    agent: Lead Agent
    status: enabled
    team: Core Team
    roles: [Lead Role, Execution Role, Completion Role]
    capabilities: [planning, implementation, completion]
  - id: QA Agent
    agent: QA Agent
    status: enabled
    team: Quality Team
    roles: [Verification Role]
    capabilities: [qa, validation]
---
EOF

cat > "$project/.ai_project/task_board.md" <<'EOF'
# Task Board
EOF
cat > "$project/.ai_project/operating_model.md" <<'EOF'
---
schema: aiops.operating_model.v1
project: Risk Profile Fixture
canonical_status_ref:
---
EOF
cat > "$project/.ai_project/source_of_truth.md" <<'EOF'
# Source
EOF
cat > "$project/docs/README.md" <<'EOF'
# Docs
EOF
cat > "$project/src/app.rb" <<'EOF'
puts "app"
EOF
cat > "$project/schemas/public.schema.json" <<'EOF'
{}
EOF

create_task() {
  id="$1"
  workflow="$2"
  type="$3"
  status="$4"
  allowed_path="$5"
  profile="${6:-}"
  cat > "$project/.ai_project/tasks/active/${id}.md" <<EOF
---
schema: aiops.task.v1
id: $id
title: $id profile fixture
status: $status
type: $type
priority: medium
risk_profile: ${profile:-null}
workflow: $workflow
target_agent: Lead Agent
target_role: Execution Role
required_capabilities: [implementation]
depends_on: []
blocks: []
allowed_paths: [$allowed_path]
source_of_truth: [.ai_project/source_of_truth.md]
created_by: Test
locked_by:
locked_at:
lock_session:
report_to: .ai_project/reports/${id}_task-report.md
qa_to: .ai_project/qa/${id}_qa-report.md
---

# $id
EOF
}

create_task T-20260813-101 docs docs approved docs/
create_task T-20260813-102 feature feature approved src/
create_task T-20260813-103 feature feature approved schemas/
create_task T-20260813-104 feature feature approved schemas/ light
create_task T-20260813-105 docs docs in_progress docs/

profile_json() {
  "$repo_root/bin/aiops" task profile "$1" --target "$project" --json > "$tmpdir/$1.json"
  "$repo_root/bin/aiops" validate task-risk-profile "$tmpdir/$1.json" >/dev/null
}

profile_json T-20260813-101
profile_json T-20260813-102
profile_json T-20260813-103

ruby -rjson -e '
  source = JSON.parse(File.read(ARGV[0]))
  mutations = {
    "bad-schema" => source.merge("schema" => "wrong"),
    "bad-profile" => source.merge("selected_profile" => "fast"),
    "extra-requirement" => Marshal.load(Marshal.dump(source)).tap { |data| data["requirements"]["extra"] = true },
    "string-command" => Marshal.load(Marshal.dump(source)).tap { |data| data["validation"][0]["command"] = "git diff --check" }
  }
  mutations.each { |name, data| File.write(File.join(ARGV[1], "#{name}.json"), JSON.pretty_generate(data)) }
' "$tmpdir/T-20260813-103.json" "$tmpdir"
for invalid in bad-schema bad-profile extra-requirement string-command; do
  if "$repo_root/bin/aiops" validate task-risk-profile "$tmpdir/$invalid.json" >/dev/null 2> "$tmpdir/$invalid.err"; then
    printf '%s\n' "invalid risk profile projection should fail: $invalid" >&2
    exit 1
  fi
  grep -q 'schema_error:' "$tmpdir/$invalid.err"
done

ruby -rjson -e '
  light = JSON.parse(File.read(ARGV[0]))
  standard = JSON.parse(File.read(ARGV[1]))
  strict = JSON.parse(File.read(ARGV[2]))
  abort("docs profile should be light") unless light["selected_profile"] == "light"
  abort("light should skip independent verification") unless light.dig("requirements", "independent_verification") == false
  abort("light should use targeted CI") unless light.dig("requirements", "ci_scope") == "targeted"
  abort("product code profile should be standard") unless standard["selected_profile"] == "standard"
  abort("standard should require independent verification") unless standard.dig("requirements", "independent_verification") == true
  abort("schema profile should be strict") unless strict["selected_profile"] == "strict"
  abort("strict should require full CI") unless strict.dig("requirements", "ci_scope") == "full"
  abort("strict should include release gate") unless strict.dig("requirements", "gates").include?("release_gate")
  abort("validation commands must be argv arrays") unless strict["validation"].all? { |step| step["command"].is_a?(Array) }
  abort("light should use fewer Role sessions than standard") unless light.dig("metrics", "estimated_role_sessions") < standard.dig("metrics", "estimated_role_sessions")
  abort("strict should plan more validation than light") unless strict.dig("metrics", "validation_step_count") > light.dig("metrics", "validation_step_count")
' "$tmpdir/T-20260813-101.json" "$tmpdir/T-20260813-102.json" "$tmpdir/T-20260813-103.json"

if "$repo_root/bin/aiops" task profile T-20260813-104 --target "$project" --json > "$tmpdir/lowered.json" 2> "$tmpdir/lowered.err"; then
  printf '%s\n' "strict risk signal should reject a light Task override" >&2
  exit 1
fi
ruby -rjson -e '
  data = JSON.parse(File.read(ARGV[0]))
  abort("lowered profile should not be ready") unless data["ready"] == false
  abort("requested override should be preserved") unless data["requested_profile"] == "light"
  abort("required minimum should remain strict") unless data["recommended_profile"] == "strict"
  abort("selected profile must remain strict") unless data["selected_profile"] == "strict"
  abort("lowered profile blocker missing") if data["blockers"].empty?
' "$tmpdir/lowered.json"

"$repo_root/bin/aiops" task profile T-20260813-101 --target "$project" --profile strict --json > "$tmpdir/raised.json"
ruby -rjson -e '
  data = JSON.parse(File.read(ARGV[0]))
  abort("CLI override should raise to strict") unless data["selected_profile"] == "strict"
  abort("CLI override source missing") unless data["selection_source"] == "cli_override"
' "$tmpdir/raised.json"

"$repo_root/bin/aiops" task status T-20260813-101 --target "$project" > "$tmpdir/status.out"
grep -q '^risk_profile: light$' "$tmpdir/status.out"

"$repo_root/bin/aiops" task transition T-20260813-102 \
  --target "$project" --to in_progress --role "Execution Role" --by "Lead Agent" \
  > "$tmpdir/standard-progress.out"
if "$repo_root/bin/aiops" task transition T-20260813-102 \
  --target "$project" --to completion_review --role "Execution Role" --by "Lead Agent" \
  > "$tmpdir/standard-direct-completion.out" 2>&1; then
  printf '%s\n' "Standard task used the Light-only direct completion transition" >&2
  exit 1
fi
grep -q 'invalid transition: in_progress -> completion_review' "$tmpdir/standard-direct-completion.out"

"$repo_root/bin/aiops" project context --target "$project" --role execution \
  --task T-20260813-102 --json > "$tmpdir/standard-context.json"
"$repo_root/bin/aiops" project context --target "$project" --role execution \
  --task T-20260813-105 --json > "$tmpdir/light-context.json"
ruby -rjson -e '
  standard = JSON.parse(File.read(ARGV[0]))
  light = JSON.parse(File.read(ARGV[1]))
  abort("Standard context exposed Light-only completion") if standard["valid_next_transitions"].any? { |item| item["to"] == "completion_review" }
  abort("Standard context omitted verification") unless standard["valid_next_transitions"].any? { |item| item["to"] == "verification_ready" }
  abort("Light context omitted direct completion") unless light["valid_next_transitions"].any? { |item| item["to"] == "completion_review" }
' "$tmpdir/standard-context.json" "$tmpdir/light-context.json"

if "$repo_root/bin/aiops" task advance T-20260813-105 --target "$project" --check --json > /dev/null 2> "$tmpdir/light-evidence.err"; then
  printf '%s\n' "Light transition without targeted evidence should fail" >&2
  exit 1
fi
grep -q 'requires targeted validation evidence' "$tmpdir/light-evidence.err"
"$repo_root/bin/aiops" task advance T-20260813-105 --target "$project" --check --json --evidence docs/README.md > "$tmpdir/light-transition.json"
"$repo_root/bin/aiops" validate task-transition-plan "$tmpdir/light-transition.json" >/dev/null
ruby -rjson -e '
  data = JSON.parse(File.read(ARGV[0]))
  abort("light transition profile missing") unless data["profile"] == "light"
  abort("light flow should skip verification") unless data.dig("transition", "to") == "completion_review"
  abort("light flow should route to completion") unless data.dig("next", "role") == "Completion Role"
' "$tmpdir/light-transition.json"

"$repo_root/bin/aiops" project snapshot --target "$project" --json > "$tmpdir/snapshot.json"
"$repo_root/bin/aiops" project dashboard --target "$project" --json > "$tmpdir/dashboard.json"
"$repo_root/bin/aiops" validate project-dashboard "$tmpdir/dashboard.json" >/dev/null
ruby -rjson -e '
  snapshot = JSON.parse(File.read(ARGV[0]))
  dashboard = JSON.parse(File.read(ARGV[1]))
  task = snapshot.dig("tasks", "items").find { |item| item["id"] == "T-20260813-101" }
  shown = dashboard.dig("tasks", "items").find { |item| item["id"] == "T-20260813-101" }
  abort("snapshot profile missing") unless task["risk_profile"] == "light"
  abort("dashboard profile missing") unless shown["risk_profile"] == "light"
' "$tmpdir/snapshot.json" "$tmpdir/dashboard.json"

ruby -rjson -e '
  dashboard = JSON.parse(File.read(ARGV[0]))
  snapshot = JSON.parse(File.read(ARGV[1]))
  [dashboard, snapshot].each do |data|
    item = data.fetch("tasks").fetch("items").first
    item["risk_profile"] = {"unexpected" => true}
    item["recommended_risk_profile"] = 42
    item["risk_profile_ready"] = "yes"
  end
  File.write(ARGV[2], JSON.pretty_generate(dashboard))
  File.write(ARGV[3], JSON.pretty_generate(snapshot))
' "$tmpdir/dashboard.json" "$tmpdir/snapshot.json" "$tmpdir/invalid-dashboard.json" "$tmpdir/invalid-snapshot.json"
if "$repo_root/bin/aiops" validate project-dashboard "$tmpdir/invalid-dashboard.json" >/dev/null 2>&1; then
  printf '%s\n' "dashboard accepted invalid risk profile field types" >&2
  exit 1
fi
if "$repo_root/bin/aiops" validate project-snapshot "$tmpdir/invalid-snapshot.json" >/dev/null 2>&1; then
  printf '%s\n' "snapshot accepted invalid risk profile field types" >&2
  exit 1
fi

"$repo_root/bin/aiops" project dashboard --target "$project" --format html --output "$tmpdir/dashboard.html"
grep -q '운영 프로필' "$tmpdir/dashboard.html"
grep -q '>Light<' "$tmpdir/dashboard.html"

if "$repo_root/bin/aiops" task profile T-20260813-101 --target "$project" --profile invalid >/dev/null 2> "$tmpdir/invalid-profile.err"; then
  printf '%s\n' "invalid profile should fail" >&2
  exit 1
fi
grep -q 'supports: light, standard, strict' "$tmpdir/invalid-profile.err"

git init -b main "$project" >/dev/null
git -C "$project" config user.email "aiops@example.test"
git -C "$project" config user.name "AI Ops Test"
git -C "$project" add .
git -C "$project" commit -m "seed base-less risk fixture" >/dev/null
mkdir -p "$project/schemas"
printf '{}\n' > "$project/schemas/payment.schema.json"

if "$repo_root/bin/aiops" task profile T-20260813-105 --target "$project" --json \
  > "$tmpdir/base-less-profile.json" 2> "$tmpdir/base-less-profile.err"; then
  :
fi
ruby -rjson -e '
  data = JSON.parse(File.read(ARGV[0]))
  abort("base-less untracked schema must select Strict") unless data["selected_profile"] == "strict"
  abort("untracked schema path missing") unless data["paths"].include?("schemas/payment.schema.json")
  abort("Git changes should be reported as path source") unless data["path_source"] == "git_changes"
' "$tmpdir/base-less-profile.json"
ruby -ryaml -rjson -rdate -I"$repo_root/runtime" -rtask_risk_profile -e '
  project = ARGV.fetch(0)
  original = Open3.method(:capture3)
  calls = []
  Open3.define_singleton_method(:capture3) do |*args|
    calls << args
    original.call(*args)
  end
  read_task = lambda do |id|
    text = File.read(File.join(project, ".ai_project", "tasks", "active", "#{id}.md"))
    body = text.lines
    closing = body[1..].find_index { |line| line.strip == "---" } + 1
    YAML.safe_load(body[1...closing].join, permitted_classes: [Date, Time, Symbol], aliases: true)
  end
  catalog = JSON.parse(File.read(File.join(project, ".ai", "runtime", "workflows.json")))
  cache = {}
  %w[T-20260813-101 T-20260813-105].each do |id|
    TaskRiskProfiles.evaluate(task: read_task.call(id), target: project, catalog: catalog, git_cache: cache)
  end
  git_calls = calls.select { |args| args.first == "git" }
  abort("repository lookup was not cached") unless git_calls.count { |args| args.include?("--is-inside-work-tree") } == 1
  abort("untracked lookup was not cached") unless git_calls.count { |args| args.include?("--others") } == 1
  abort("unstaged lookup was not cached") unless git_calls.count { |args| args.include?("diff") && !args.include?("--cached") } == 1
  abort("staged lookup was not cached") unless git_calls.count { |args| args.include?("--cached") } == 1
' "$project"
if "$repo_root/bin/aiops" task advance T-20260813-105 --target "$project" --check --json \
  --next-agent "QA Agent" --evidence docs/README.md > "$tmpdir/base-less-advance.out" 2>&1; then
  printf '%s\n' "base-less Task ignored an untracked path outside allowed_paths" >&2
  exit 1
fi
grep -q 'changed paths outside Task allowed_paths: schemas/payment.schema.json' "$tmpdir/base-less-advance.out"

printf '%s\n' "ok: task risk profiles"

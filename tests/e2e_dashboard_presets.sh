#!/usr/bin/env sh
set -eu

repo_root="$(CDPATH= cd "$(dirname "$0")/.." && pwd)"
tmpdir="$(mktemp -d /tmp/aiops-e2e-dashboard-presets.XXXXXX)"
project="$tmpdir/project"
trap 'rm -rf "$tmpdir"' EXIT INT TERM

"$repo_root/bin/aiops" project dashboard preset --help > "$tmpdir/preset-help.out"
grep -q 'preset add NAME' "$tmpdir/preset-help.out" || {
  printf '%s\n' "dashboard preset help is missing add usage" >&2
  exit 1
}
"$repo_root/bin/aiops" project dashboard preset add --help > "$tmpdir/preset-add-help.out"
grep -q 'Explicit dashboard options override' "$tmpdir/preset-add-help.out" || {
  printf '%s\n' "dashboard preset add help is missing precedence guidance" >&2
  exit 1
}

mkdir -p "$project/.ai_project"
ln -s "$repo_root" "$project/.ai"
printf '# Agent Instructions\n' > "$project/AGENTS.md"

"$repo_root/bin/aiops" project dashboard preset list --target "$project" > "$tmpdir/list-builtins.out"
for preset in overview work-current risk-review agent-load release-readiness; do
  grep -q "^$preset  \[built-in\]" "$tmpdir/list-builtins.out" || {
    printf '%s\n' "built-in dashboard preset missing: $preset" >&2
    exit 1
  }
done

"$repo_root/bin/aiops" project dashboard preset show overview --target "$project" > "$tmpdir/show-overview.out"
grep -q '^source: built-in$' "$tmpdir/show-overview.out" || {
  printf '%s\n' "built-in dashboard preset source missing" >&2
  exit 1
}
grep -q '^  view: main$' "$tmpdir/show-overview.out" || {
  printf '%s\n' "built-in dashboard preset option missing" >&2
  exit 1
}

"$repo_root/bin/aiops" project dashboard --target "$project" --preset overview --json > "$tmpdir/preset-overview.json"
"$repo_root/bin/aiops" project dashboard --target "$project" --view main --level standard --format terminal --json > "$tmpdir/explicit-overview.json"
ruby -rjson -e '
  preset = JSON.parse(File.read(ARGV[0]))
  explicit = JSON.parse(File.read(ARGV[1]))
  preset.delete("generated_at")
  explicit.delete("generated_at")
  abort("built-in preset projection differs") unless preset == explicit
' "$tmpdir/preset-overview.json" "$tmpdir/explicit-overview.json"

for preset_spec in \
  work-current:work:standard \
  risk-review:risk:detail \
  agent-load:agents:standard \
  release-readiness:release:detail
do
  preset_name="${preset_spec%%:*}"
  remainder="${preset_spec#*:}"
  expected_view="${remainder%%:*}"
  expected_level="${remainder#*:}"
  "$repo_root/bin/aiops" project dashboard --target "$project" --preset "$preset_name" --json > "$tmpdir/preset-built-in.json"
  ruby -rjson -e '
    data = JSON.parse(File.read(ARGV[0]))
    abort("built-in preset view mismatch") unless data["view"] == ARGV[1]
    abort("built-in preset level mismatch") unless data["level"] == ARGV[2]
  ' "$tmpdir/preset-built-in.json" "$expected_view" "$expected_level"
done

if "$repo_root/bin/aiops" project dashboard --target "$project" --preset DOES_NOT_EXIST > "$tmpdir/unknown.out" 2>&1; then
  printf '%s\n' "unknown dashboard preset should fail" >&2
  exit 1
fi
grep -q 'unknown dashboard preset: DOES_NOT_EXIST; available:' "$tmpdir/unknown.out" || {
  printf '%s\n' "unknown dashboard preset guidance missing" >&2
  exit 1
}
if "$repo_root/bin/aiops" project dashboard --target "$project" --preset overview --preset work-current > "$tmpdir/multiple.out" 2>&1; then
  printf '%s\n' "multiple dashboard presets should fail" >&2
  exit 1
fi
grep -q 'only one --preset may be used' "$tmpdir/multiple.out" || {
  printf '%s\n' "multiple dashboard preset guidance missing" >&2
  exit 1
}

"$repo_root/bin/aiops" project dashboard preset add team-work \
  --target "$project" \
  --description "팀 작업 화면" \
  --view work \
  --level detail \
  --format terminal

preset_file="$project/.ai_project/dashboard_presets.json"
[ -f "$preset_file" ] || {
  printf '%s\n' "project dashboard preset file missing" >&2
  exit 1
}
"$repo_root/bin/aiops" validate dashboard-presets "$preset_file" > "$tmpdir/validate.out"
grep -q '^ok: dashboard presets$' "$tmpdir/validate.out" || {
  printf '%s\n' "dashboard preset schema validation missing" >&2
  exit 1
}
ruby -rjson -e '
  data = JSON.parse(File.read(ARGV[0]))
  abort("dashboard preset schema marker missing") unless data["schema"] == "aiops.dashboard_presets.v1"
  preset = data.dig("presets", "team-work")
  abort("local dashboard preset missing") unless preset
  abort("local dashboard preset view missing") unless preset["view"] == "work"
  abort("local dashboard preset description missing") unless preset["description"] == "팀 작업 화면"
' "$preset_file"

"$repo_root/bin/aiops" project dashboard preset list --target "$project" > "$tmpdir/list-local.out"
grep -q '^team-work  \[project\]  팀 작업 화면$' "$tmpdir/list-local.out" || {
  printf '%s\n' "project dashboard preset list entry missing" >&2
  exit 1
}
"$repo_root/bin/aiops" project dashboard preset show team-work --target "$project" > "$tmpdir/show-local.out"
grep -q '^source: project$' "$tmpdir/show-local.out" || {
  printf '%s\n' "project dashboard preset source missing" >&2
  exit 1
}

before_run_hash="$(shasum -a 256 "$preset_file" | awk '{print $1}')"
"$repo_root/bin/aiops" project dashboard --target "$project" --preset team-work --json > "$tmpdir/preset-team-work.json"
"$repo_root/bin/aiops" project dashboard --target "$project" --view work --level detail --format terminal --json > "$tmpdir/explicit-team-work.json"
after_run_hash="$(shasum -a 256 "$preset_file" | awk '{print $1}')"
[ "$before_run_hash" = "$after_run_hash" ] || {
  printf '%s\n' "dashboard preset execution modified preset source" >&2
  exit 1
}
ruby -rjson -e '
  preset = JSON.parse(File.read(ARGV[0]))
  explicit = JSON.parse(File.read(ARGV[1]))
  preset.delete("generated_at")
  explicit.delete("generated_at")
  abort("local preset projection differs") unless preset == explicit
' "$tmpdir/preset-team-work.json" "$tmpdir/explicit-team-work.json"

"$repo_root/bin/aiops" project dashboard --target "$project" --preset team-work --level compact --json > "$tmpdir/preset-override.json"
ruby -rjson -e '
  data = JSON.parse(File.read(ARGV[0]))
  abort("explicit preset override missing") unless data["view"] == "work" && data["level"] == "compact"
' "$tmpdir/preset-override.json"

if "$repo_root/bin/aiops" project dashboard preset add team-work --target "$project" --view main > "$tmpdir/duplicate.out" 2>&1; then
  printf '%s\n' "duplicate dashboard preset should fail without force" >&2
  exit 1
fi
grep -q 'dashboard preset already exists: team-work; use --force' "$tmpdir/duplicate.out" || {
  printf '%s\n' "duplicate dashboard preset guidance missing" >&2
  exit 1
}
"$repo_root/bin/aiops" project dashboard preset add team-work --target "$project" --view main --level compact --force > "$tmpdir/force.out"
ruby -rjson -e '
  data = JSON.parse(File.read(ARGV[0]))
  preset = data.dig("presets", "team-work")
  abort("forced dashboard preset update missing") unless preset == {"view" => "main", "level" => "compact"}
' "$preset_file"

if "$repo_root/bin/aiops" project dashboard preset add overview --target "$project" --view main > "$tmpdir/reserved.out" 2>&1; then
  printf '%s\n' "reserved dashboard preset name should fail" >&2
  exit 1
fi
grep -q 'dashboard preset name is reserved: overview' "$tmpdir/reserved.out" || {
  printf '%s\n' "reserved dashboard preset guidance missing" >&2
  exit 1
}

cp "$preset_file" "$tmpdir/valid-presets.json"
printf '{ invalid json\n' > "$preset_file"
if "$repo_root/bin/aiops" project dashboard preset list --target "$project" > "$tmpdir/malformed.out" 2>&1; then
  printf '%s\n' "malformed dashboard preset file should fail" >&2
  exit 1
fi
grep -q 'invalid dashboard preset file' "$tmpdir/malformed.out" || {
  printf '%s\n' "malformed dashboard preset error missing" >&2
  exit 1
}

cat > "$preset_file" <<'EOF'
{
  "schema": "aiops.dashboard_presets.v1",
  "presets": {
    "bad-port": {
      "port": 9000
    }
  }
}
EOF
if "$repo_root/bin/aiops" project dashboard preset list --target "$project" > "$tmpdir/semantic-invalid.out" 2>&1; then
  printf '%s\n' "semantically invalid dashboard preset should fail" >&2
  exit 1
fi
grep -q 'port, refresh, and open require serve' "$tmpdir/semantic-invalid.out" || {
  printf '%s\n' "semantic dashboard preset error missing" >&2
  exit 1
}
if "$repo_root/bin/aiops" validate dashboard-presets "$preset_file" > "$tmpdir/semantic-validate.out" 2>&1; then
  printf '%s\n' "semantic dashboard preset validation should fail" >&2
  exit 1
fi
grep -q 'port, refresh, and open require serve' "$tmpdir/semantic-validate.out" || {
  printf '%s\n' "semantic dashboard preset validation error missing" >&2
  exit 1
}

injection_marker="$tmpdir/should-not-run"
cat > "$preset_file" <<EOF
{
  "schema": "aiops.dashboard_presets.v1",
  "presets": {
    "bad-key": {
      "view": "main",
      "command": "touch $injection_marker"
    }
  }
}
EOF
if "$repo_root/bin/aiops" project dashboard preset list --target "$project" > "$tmpdir/unknown-key.out" 2>&1; then
  printf '%s\n' "unknown dashboard preset option should fail" >&2
  exit 1
fi
grep -q 'unknown options command' "$tmpdir/unknown-key.out" || {
  printf '%s\n' "unknown dashboard preset option error missing" >&2
  exit 1
}
[ ! -e "$injection_marker" ] || {
  printf '%s\n' "dashboard preset executed untrusted option content" >&2
  exit 1
}

cp "$tmpdir/valid-presets.json" "$preset_file"
"$repo_root/bin/aiops" validate dashboard-presets "$preset_file" >/dev/null

printf '%s\n' "ok: dashboard presets"

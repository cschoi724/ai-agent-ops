#!/usr/bin/env sh
set -eu

repo_root="$(CDPATH= cd "$(dirname "$0")/.." && pwd)"
tmpdir="$(mktemp -d /tmp/aiops-e2e-dashboard-locale.XXXXXX)"
project="$tmpdir/project"
trap 'rm -rf "$tmpdir"' EXIT INT TERM

mkdir -p "$project/.ai_project/tasks/active" "$project/.ai_project/tasks/backlog" "$project/.ai_project/tasks/archive"
ln -s "$repo_root" "$project/.ai"
printf '# Agent Instructions\n' > "$project/AGENTS.md"
cat > "$project/.ai_project/tasks/active/T-20260812-001_locale-fixture.md" <<'EOF'
---
schema: aiops.task.v1
id: T-20260812-001
title: Locale fixture task
status: approved
workflow: feature
target_role: Execution Role
target_agent: Locale Agent
required_capabilities:
  - implementation
allowed_paths:
  - docs/
source_of_truth:
  - .ai_project/source_of_truth.md
---

# Locale fixture task
EOF
cat > "$project/.ai_project/tasks/backlog/T-20260812-002_locale-fallback.md" <<'EOF'
---
schema: aiops.task.v1
id: T-20260812-002
title: Locale fallback fixture
status: custom_status
workflow: custom_workflow
target_role: custom_execution_role
target_agent: Custom Agent
required_capabilities:
  - custom_capability
allowed_paths:
  - docs/
source_of_truth:
  - .ai_project/source_of_truth.md
---

# Locale fallback fixture
EOF

cat > "$project/.ai_project/dashboard_labels.ko.json" <<'EOF'
{
  "schema": "aiops.dashboard_locale.v1",
  "locale": "ko",
  "labels": {
    "ui": {
      "dashboard_title": "프로젝트 운영 관제판",
      "project_status": "%{project} 운영 상태"
    },
    "status": {
      "blocked": "설정 중단"
    }
  }
}
EOF

"$repo_root/bin/aiops" validate dashboard-locale "$project/.ai_project/dashboard_labels.ko.json" > "$tmpdir/locale-validate.out"
grep -q '^ok: dashboard locale$' "$tmpdir/locale-validate.out" || {
  printf '%s\n' "dashboard locale validation result missing" >&2
  exit 1
}

"$repo_root/bin/aiops" status --target "$project" --color never > "$tmpdir/status-default.out"
"$repo_root/bin/aiops" status --target "$project" --locale ko --color never > "$tmpdir/status-ko.out"
cmp "$tmpdir/status-default.out" "$tmpdir/status-ko.out" || {
  printf '%s\n' "default dashboard locale is not Korean" >&2
  exit 1
}
grep -q '상태' "$tmpdir/status-default.out" || {
  printf '%s\n' "default Korean user CLI label missing" >&2
  exit 1
}

"$repo_root/bin/aiops" status --target "$project" --locale en --color never > "$tmpdir/status-en.out"
grep -q ' status$' "$tmpdir/status-en.out" || {
  printf '%s\n' "English user CLI title missing" >&2
  exit 1
}
grep -q '^Overall status' "$tmpdir/status-en.out" || {
  printf '%s\n' "English user CLI status label missing" >&2
  exit 1
}
if grep -q '^운영 상태$' "$tmpdir/status-en.out"; then
  printf '%s\n' "English user CLI leaked Korean section heading" >&2
  exit 1
fi

AIOPS_LOCALE=en "$repo_root/bin/aiops" status --target "$project" --color never > "$tmpdir/status-env-en.out"
cmp "$tmpdir/status-en.out" "$tmpdir/status-env-en.out" || {
  printf '%s\n' "AIOPS_LOCALE did not select the dashboard locale" >&2
  exit 1
}

"$repo_root/bin/aiops" project dashboard --target "$project" --format html --locale en --output "$tmpdir/dashboard-en.html" >/dev/null
for pattern in '<html lang="en">' 'AI Ops Project Dashboard' 'Task explorer' 'Project settings' 'View Mermaid source'; do
  grep -q "$pattern" "$tmpdir/dashboard-en.html" || {
    printf '%s\n' "English HTML dashboard label missing: $pattern" >&2
    exit 1
  }
done
grep -q 'class="table-scroll"' "$tmpdir/dashboard-en.html" || {
  printf '%s\n' "responsive task table wrapper missing" >&2
  exit 1
}
grep -q '\.table-scroll{width:100%;max-width:100%;overflow-x:auto' "$tmpdir/dashboard-en.html" || {
  printf '%s\n' "responsive task table overflow rule missing" >&2
  exit 1
}
grep -q '>Custom Status<' "$tmpdir/dashboard-en.html" || {
  printf '%s\n' "unknown dashboard label readable fallback missing" >&2
  exit 1
}

"$repo_root/bin/aiops" project dashboard --target "$project" --format html \
  --locale-file .ai_project/dashboard_labels.ko.json \
  --output "$tmpdir/dashboard-override.html" >/dev/null
grep -q '프로젝트 운영 관제판' "$tmpdir/dashboard-override.html" || {
  printf '%s\n' "project dashboard locale override missing" >&2
  exit 1
}
grep -q '<html lang="ko">' "$tmpdir/dashboard-override.html" || {
  printf '%s\n' "locale file did not select its locale" >&2
  exit 1
}
"$repo_root/bin/aiops" status --target "$project" \
  --locale-file .ai_project/dashboard_labels.ko.json --color never > "$tmpdir/status-override.out"
grep -q ' 운영 상태$' "$tmpdir/status-override.out" || {
  printf '%s\n' "user dashboard locale-file override missing" >&2
  exit 1
}

if "$repo_root/bin/aiops" project dashboard --target "$project" --locale en \
  --locale-file .ai_project/dashboard_labels.ko.json >/dev/null 2>"$tmpdir/mismatch.err"; then
  printf '%s\n' "mismatched dashboard locale file unexpectedly succeeded" >&2
  exit 1
fi
grep -q 'does not match --locale-file locale: ko' "$tmpdir/mismatch.err" || {
  printf '%s\n' "dashboard locale mismatch guidance missing" >&2
  exit 1
}

if "$repo_root/bin/aiops" status --target "$project" --locale fr >/dev/null 2>"$tmpdir/unknown.err"; then
  printf '%s\n' "unknown dashboard locale unexpectedly succeeded" >&2
  exit 1
fi
grep -q 'project dashboard --locale supports: ko, en' "$tmpdir/unknown.err" || {
  printf '%s\n' "unknown dashboard locale guidance missing" >&2
  exit 1
}

cat > "$tmpdir/invalid-locale.json" <<'EOF'
{
  "schema": "aiops.dashboard_locale.v1",
  "locale": "ko",
  "labels": {
    "command": {
      "run": "unsafe"
    }
  }
}
EOF
if "$repo_root/bin/aiops" validate dashboard-locale "$tmpdir/invalid-locale.json" > "$tmpdir/invalid.out" 2>&1; then
  printf '%s\n' "unknown dashboard locale category unexpectedly validated" >&2
  exit 1
fi
grep -q 'unknown properties command' "$tmpdir/invalid.out" || {
  printf '%s\n' "invalid dashboard locale category guidance missing" >&2
  exit 1
}

"$repo_root/bin/aiops" project dashboard --target "$project" --json > "$tmpdir/dashboard-ko.json"
"$repo_root/bin/aiops" project dashboard --target "$project" --locale en --json > "$tmpdir/dashboard-en.json"
ruby -rjson -e '
  left = JSON.parse(File.read(ARGV[0]))
  right = JSON.parse(File.read(ARGV[1]))
  left.delete("generated_at")
  right.delete("generated_at")
  abort("dashboard locale changed machine projection") unless left == right
' "$tmpdir/dashboard-ko.json" "$tmpdir/dashboard-en.json"

"$repo_root/bin/aiops" project dashboard --target "$project" --view work --format mermaid --map dependencies --locale ko > "$tmpdir/map-ko.mmd"
"$repo_root/bin/aiops" project dashboard --target "$project" --view work --format mermaid --map dependencies --locale en > "$tmpdir/map-en.mmd"
ruby -e '
  def ids(path)
    File.readlines(path).filter_map { |line| line[/^\s*(T_[A-Za-z0-9_]+)/, 1] }.uniq.sort
  end
  abort("Mermaid internal IDs changed by locale") unless ids(ARGV[0]) == ids(ARGV[1])
' "$tmpdir/map-ko.mmd" "$tmpdir/map-en.mmd"

"$repo_root/bin/aiops" project dashboard preset add english-overview \
  --target "$project" --view main --format html --locale en >/dev/null
"$repo_root/bin/aiops" project dashboard --target "$project" --preset english-overview \
  --output "$tmpdir/preset-en.html" >/dev/null
grep -q 'AI Ops Project Dashboard' "$tmpdir/preset-en.html" || {
  printf '%s\n' "dashboard preset locale was not forwarded" >&2
  exit 1
}

printf '%s\n' "ok: dashboard locale"

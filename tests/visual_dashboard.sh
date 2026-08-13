#!/usr/bin/env sh
set -eu

repo_root="$(CDPATH= cd "$(dirname "$0")/.." && pwd)"
tmpdir="$(mktemp -d /tmp/aiops-visual-dashboard.XXXXXX)"
project="$tmpdir/project"
artifact_dir="${AIOPS_VISUAL_ARTIFACT_DIR:-/tmp/aiops-dashboard-visual-artifacts}"

cleanup() {
  if [ "${AIOPS_VISUAL_KEEP_TMP:-0}" = "1" ]; then
    printf '%s\n' "visual test files kept at: $tmpdir" >&2
    return
  fi
  rm -rf "$tmpdir"
}
trap cleanup EXIT INT TERM

find_chrome() {
  if [ -n "${AIOPS_CHROME:-}" ] && [ -x "$AIOPS_CHROME" ]; then
    printf '%s\n' "$AIOPS_CHROME"
    return
  fi
  for candidate in \
    "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" \
    "/Applications/Chromium.app/Contents/MacOS/Chromium"; do
    if [ -x "$candidate" ]; then
      printf '%s\n' "$candidate"
      return
    fi
  done
  command -v google-chrome 2>/dev/null || command -v chromium 2>/dev/null || return 1
}

chrome="$(find_chrome)" || {
  printf '%s\n' "dashboard visual test requires Google Chrome or Chromium; set AIOPS_CHROME" >&2
  exit 1
}

mkdir -p "$project/.ai_project/tasks/active" "$project/.ai_project/tasks/backlog" "$project/.ai_project/tasks/archive" "$artifact_dir"
ln -s "$repo_root" "$project/.ai"
printf '# Agent Instructions\n' > "$project/AGENTS.md"
printf '# AI Ops local runtime cache\n.ai_project/.runtime/\n' > "$project/.gitignore"

for file in current_context.md source_of_truth.md task_board.md ops_decisions.md ops_issues.md branch_pr_strategy.md; do
  printf '# %s\n' "$file" > "$project/.ai_project/$file"
done

cat > "$project/.ai_project/operating_model.md" <<EOF
---
schema: aiops.operating_model.v1
project: VisualDashboardProject
bootstrap_mode: fast_track
core_version: $(cat "$repo_root/VERSION")
core_source: symlink
core_update_policy: manual_review
start_context: assigned_or_existing_project
readiness_level: implementation_ready
operating_mode: team_pr
team_pattern: single_team
workflow_policy: standard_vnext
ownership_model: path_plus_domain
coordination: parallel_with_locks
board_model: project_board_only
branch_pr: branch_per_task
canonical_status_ref: main
knowledge_mode: minimal
release_role: inactive
active_roles:
  - Lead Role
  - Execution Role
  - Verification Role
deferred_roles: []
---

# Visual Dashboard Operating Model
EOF

cat > "$project/.ai_project/agent_registry.md" <<'EOF'
---
schema: aiops.agent_registry.v1
project: VisualDashboardProject
agents:
  - agent: Product Lead Agent
    status: enabled
    team: Product Team
    roles:
      - Lead Role
    capabilities:
      - scope_definition
  - agent: iOS Agent
    status: enabled
    team: Core Development Team
    roles:
      - Execution Role
    capabilities:
      - ios_implementation
  - agent: Product QA Agent
    status: enabled
    team: Quality Team
    roles:
      - Verification Role
    capabilities:
      - independent_validation
---

# Visual Dashboard Agent Registry
EOF

cat > "$project/.ai_project/tasks/active/T-20260813-001_visual-foundation.md" <<'EOF'
---
schema: aiops.task.v1
id: T-20260813-001
title: Dashboard visual foundation and responsive layout
status: done
workflow: feature
target_role: Completion Role
target_agent: Product Lead Agent
required_capabilities: [completion_review]
allowed_paths: [docs/]
source_of_truth: [.ai_project/source_of_truth.md]
---
EOF

cat > "$project/.ai_project/tasks/active/T-20260813-002_visual-implementation.md" <<'EOF'
---
schema: aiops.task.v1
id: T-20260813-002
title: Implement localized dashboard with an intentionally long next action label
status: approved
workflow: feature
target_role: Execution Role
target_agent: iOS Agent
depends_on: [T-20260813-001]
blocks: [T-20260813-003]
required_capabilities: [ios_implementation]
allowed_paths: [runtime/]
source_of_truth: [.ai_project/source_of_truth.md]
---
EOF

cat > "$project/.ai_project/tasks/active/T-20260813-003_visual-verification.md" <<'EOF'
---
schema: aiops.task.v1
id: T-20260813-003
title: Verify Mermaid rendering and narrow viewport behavior
status: verification_ready
workflow: qa
target_role: Verification Role
target_agent: Product QA Agent
depends_on: [T-20260813-002]
required_capabilities: [independent_validation]
allowed_paths: [tests/]
source_of_truth: [.ai_project/source_of_truth.md]
---
EOF

cat > "$project/.ai_project/tasks/backlog/T-20260813-004_visual-followup.md" <<'EOF'
---
schema: aiops.task.v1
id: T-20260813-004
title: Prepare the next dashboard visual improvement
status: proposed
workflow: feature
target_role: Lead Role
target_agent: Product Lead Agent
depends_on: [T-20260813-003]
required_capabilities: [scope_definition]
allowed_paths: [design_notes/]
source_of_truth: [.ai_project/source_of_truth.md]
---
EOF

git init -b main "$project" >/dev/null
git -C "$project" config user.email "aiops@example.test"
git -C "$project" config user.name "AI Ops Visual Test"
git -C "$project" add . >/dev/null
git -C "$project" commit -m "seed visual dashboard fixture" >/dev/null

before_hash="$(find "$project" -type f -not -path '*/.git/*' -print | sort | xargs shasum -a 256 | shasum -a 256 | awk '{print $1}')"

inject_probe() {
  input="$1"
  output="$2"
  ruby -e '
    html = File.read(ARGV[0])
    probe = File.read(ARGV[1])
    abort("dashboard closing body missing") unless html.include?("</body>")
    File.write(ARGV[2], html.sub("</body>", "<script>#{probe}</script></body>"))
  ' "$input" "$repo_root/tests/dashboard_visual_probe.js" "$output"
}

render_case() {
  name="$1"
  locale="$2"
  width="$3"
  height="$4"
  html="$artifact_dir/$name.html"
  probe_html="$tmpdir/$name-probe.html"
  result="$artifact_dir/$name.json"
  screenshot="$artifact_dir/$name.png"
  profile="$tmpdir/chrome-$name"

  "$repo_root/bin/aiops" project dashboard \
    --target "$project" \
    --format html \
    --map dependencies \
    --locale "$locale" \
    --output "$html" >/dev/null
  inject_probe "$html" "$probe_html"

  node "$repo_root/tests/dashboard_browser_runner.mjs" \
    --chrome "$chrome" \
    --url "file://$probe_html" \
    --width "$width" \
    --height "$height" \
    --screenshot "$screenshot" \
    --result "$result" \
    --profile "$profile"

  ruby -rjson -e '
    expected_locale, result_path, png_path, requested_width = ARGV
    result = JSON.parse(File.read(result_path))
    abort("visual probe failed: #{result.inspect}") unless result["status"] == "ok"
    abort("locale mismatch: #{result.inspect}") unless result["lang"] == expected_locale
    abort("Mermaid graph count mismatch: #{result.inspect}") unless result["graph_count"] == 7
    abort("Mermaid SVG count mismatch: #{result.inspect}") unless result["svg_count"] == 7
    abort("initial open map count mismatch: #{result.inspect}") unless result["initial_open_count"] == 1
    abort("initial SVG count mismatch: #{result.inspect}") unless result["initial_svg_count"] == 1
    abort("initial map mismatch: #{result.inspect}") unless result["initial_open_maps"] == ["dependencies"] && result["initial_svg_maps"] == ["dependencies"]
    abort("closed maps rendered eagerly: #{result.inspect}") unless result["closed_initially_rendered"].empty?
    abort("closed maps did not render after expansion: #{result.inspect}") unless result["closed_rendered_after_expand"].length == 6
    abort("visual artifact does not include all maps: #{result.inspect}") unless result["artifact_all_maps_open"]
    expected_interactions = {
      "initial" => %w[T-20260813-002 T-20260813-003 T-20260813-004],
      "search" => %w[T-20260813-003],
      "status" => %w[T-20260813-002],
      "agent" => %w[T-20260813-002],
      "role" => %w[T-20260813-003],
      "workflow" => %w[T-20260813-003],
      "focus_depth" => %w[T-20260813-002 T-20260813-003],
      "reset" => %w[T-20260813-002 T-20260813-003 T-20260813-004]
    }
    expected_interactions.each do |name, ids|
      interaction = result.fetch("explorer_interactions").fetch(name)
      abort("#{name} table mismatch: #{result.inspect}") unless interaction["table_task_ids"] == ids
      abort("#{name} dependency map mismatch: #{result.inspect}") unless interaction["dependency_task_ids"] == ids
    end
    abort("page horizontal overflow: #{result.inspect}") unless result["page_scroll_width"] <= result["page_client_width"]
    abort("zoom control failed: #{result.inspect}") unless result["zoom_before"] == "1" && result["zoom_after"] == "1.15" && result["transform_after"] == "scale(1.15)"
    abort("map collapse/expand failed: #{result.inspect}") unless result["open_before"] && result["collapsed"] && result["expanded"]
    abort("major UI escaped viewport: #{result.inspect}") unless result["escaped_elements"].empty?
    abort("major UI text clipped: #{result.inspect}") unless result["clipped_controls"].empty?
    abort("browser errors: #{result.inspect}") unless result["errors"].empty? && result["browser_exceptions"].empty?
    if requested_width.to_i < 620
      abort("narrow task table did not keep internal scroll: #{result.inspect}") unless result["table_scroll_width"] > result["table_client_width"]
      abort("narrow Mermaid map did not keep internal scroll: #{result.inspect}") unless result["map_scroll_width"] > result["map_client_width"]
    end
    png = File.binread(png_path)
    abort("screenshot is not PNG") unless png.start_with?("\x89PNG\r\n\x1a\n".b)
    width, height = png.byteslice(16, 8).unpack("N2")
    abort("screenshot mode mismatch: #{result.inspect}") unless result["screenshot_mode"] == "full_page"
    abort("screenshot width mismatch: #{width}x#{height}") unless width == result["screenshot_expected_width"] && width == requested_width.to_i
    abort("screenshot height mismatch: #{width}x#{height}") unless height == result["screenshot_expected_height"] && height > result["viewport_height"]
    puts "ok: #{expected_locale} #{requested_width}px dashboard visual (screenshot #{width}x#{height}, #{result["svg_count"]} maps)"
  ' "$locale" "$result" "$screenshot" "$width"
}

render_case dashboard-ko-desktop ko 1440 1200
render_case dashboard-en-narrow en 390 844

after_hash="$(find "$project" -type f -not -path '*/.git/*' -print | sort | xargs shasum -a 256 | shasum -a 256 | awk '{print $1}')"
[ "$before_hash" = "$after_hash" ] || {
  printf '%s\n' "dashboard visual test modified target project files" >&2
  exit 1
}

printf '%s\n' "ok: dashboard visual regression"
printf '%s\n' "artifacts: $artifact_dir"

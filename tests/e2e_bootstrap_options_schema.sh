#!/usr/bin/env sh
set -eu

repo_root="$(CDPATH= cd "$(dirname "$0")/.." && pwd)"

ruby -rjson -e '
  schema = JSON.parse(File.read(ARGV[0]))
  data = JSON.parse(File.read(ARGV[1]))

  abort("wrong schema") unless data["schema"] == "aiops.bootstrap_options.v1"
  abort("missing version") unless data["version"].to_s.length > 0
  abort("schema title mismatch") unless schema["title"] == "AI Ops Bootstrap Options"

  categories = data.fetch("categories")
  required = %w[
    bootstrap_mode
    start_context
    readiness_level
    operating_mode
    team_pattern
    workflow_policy
    ownership_model
    coordination
    board_model
    branch_pr
    knowledge_mode
  ]

  missing = required.reject { |key| categories.key?(key) }
  abort("missing categories: #{missing.join(", ")}") unless missing.empty?

  required.each do |category_key|
    category = categories.fetch(category_key)
    abort("missing question for #{category_key}") unless category["question"].to_s.length > 0
    options = category.fetch("options")
    abort("empty options for #{category_key}") if options.empty?
    ids = options.map { |option| option.fetch("id") }
    abort("duplicate option ids for #{category_key}") unless ids.uniq == ids
    if category["default"]
      abort("default not in options for #{category_key}") unless ids.include?(category["default"])
    end
    options.each do |option|
      abort("missing label in #{category_key}") unless option["label"].to_s.length > 0
      abort("missing description in #{category_key}: #{option["id"]}") unless option["description"].to_s.length > 0
    end
  end

  canonical = {
    "bootstrap_mode" => %w[fast_track guided_full manual migrated],
    "start_context" => %w[
      new_project_with_requirement assigned_or_existing_project blank_slate_discovery
      rescue_or_recovery migration_or_modernization ops_setup_only
      scale_up_existing_ops custom_start_context
    ],
    "readiness_level" => %w[
      idea_only idea_structured planning_ready implementation_ready
      existing_project_scan_required discovery_required recovery_required ops_only
    ],
    "operating_mode" => %w[solo_light team_basic team_pr multi_team enterprise],
    "team_pattern" => %w[single_team functional_teams platform_teams cross_functional custom],
    "workflow_policy" => %w[standard_vnext skip_scoped_for_simple_tasks custom],
    "ownership_model" => %w[path_only path_plus_domain document_ownership strict_parallel_control custom],
    "coordination" => %w[single_active_task parallel_with_locks team_board_coordination custom],
    "board_model" => %w[project_board_only project_plus_team_board custom_views],
    "branch_pr" => %w[pending_decision simple_safe branch_per_task pr_required custom],
    "knowledge_mode" => %w[minimal indexed context_packs external_source_of_truth custom]
  }

  canonical.each do |category_key, expected|
    actual = categories.fetch(category_key).fetch("options").map { |option| option.fetch("id") }
    missing_expected = expected - actual
    unknown = actual - expected
    abort("missing canonical options for #{category_key}: #{missing_expected.join(", ")}") unless missing_expected.empty?
    abort("unknown canonical options for #{category_key}: #{unknown.join(", ")}") unless unknown.empty?
  end
  puts "ok: bootstrap options"
' "$repo_root/schemas/bootstrap_options.schema.json" "$repo_root/runtime/bootstrap_options.json"

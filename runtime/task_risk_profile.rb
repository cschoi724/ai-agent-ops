#!/usr/bin/env ruby
# frozen_string_literal: true

require "date"
require "json"
require "open3"
require "optparse"
require "yaml"

class RiskProfileError < StandardError; end

module TaskRiskProfiles
  LEVELS = {"light" => 0, "standard" => 1, "strict" => 2}.freeze
  CODE_EXTENSIONS = %w[
    .c .cc .cpp .cs .go .java .js .jsx .kt .kts .m .mm .php .py .rb .rs .sh
    .swift .ts .tsx
  ].freeze
  STRICT_PATHS = %r{\A(?:schemas/|policies/|Formula/|\.github/workflows/|migrations?/|deploy/|release/)}i
  STRICT_TERMS = /(?<![a-z0-9])(?:security|privacy|payment|billing|entitlement|quota|migration|schema|policy|release|deploy|rollback|credential|auth|authentication|authorization)(?![a-z0-9])/i
  PRODUCT_PATHS = %r{\A(?:apps/|src/|lib/|packages/|services/|backend/|frontend/)}i
  LIGHT_PATHS = %r{\A(?:\.ai_project/|\.ai_knowledge/|docs/|design_notes/|README(?:\.[^\/]+)?\z|CHANGELOG(?:\.[^\/]+)?\z|[^\/]+\.md\z)}i

  module_function

  def evaluate(task:, target:, catalog:, requested_profile: nil, git_cache: nil)
    workflow = resolve_workflow(catalog, task["workflow"])
    workflow_profile = workflow["default_profile"].to_s
    workflow_profile = nil unless LEVELS.key?(workflow_profile)
    task_profile = task["risk_profile"].to_s
    task_profile = nil if task_profile.empty?
    raise RiskProfileError, "invalid Task risk_profile: #{task_profile}" if task_profile && !LEVELS.key?(task_profile)
    if requested_profile && !LEVELS.key?(requested_profile)
      raise RiskProfileError, "--profile supports: light, standard, strict"
    end

    paths, path_source = relevant_paths(task, target, git_cache: git_cache)
    classification = classify_paths(paths)
    signals = risk_signals(task, paths, classification)
    signal_profile = signals.map { |signal| signal["profile"] }.max_by { |profile| LEVELS.fetch(profile) } || "light"
    minimum = highest_profile(signal_profile, workflow_profile || "light")

    selected, source = if requested_profile
                         [requested_profile, "cli_override"]
                       elsif task_profile
                         [task_profile, "task_override"]
                       elsif workflow_profile
                         [workflow_profile, "workflow_default"]
                       else
                         [minimum, "automatic"]
                       end

    blockers = []
    if %w[task_override cli_override].include?(source) && LEVELS.fetch(selected) < LEVELS.fetch(minimum)
      blockers << "#{source} profile #{selected} is below required minimum #{minimum}"
    end
    profile = highest_profile(selected, minimum)
    requirements = requirements_for(profile)
    validation = validation_for(profile, paths, classification, target)

    {
      "schema" => "aiops.task_risk_profile.v1",
      "generated_at" => Time.now.utc.strftime("%Y-%m-%dT%H:%M:%SZ"),
      "target" => target,
      "task_id" => task.fetch("id"),
      "workflow" => task["workflow"],
      "ready" => blockers.empty?,
      "recommended_profile" => minimum,
      "requested_profile" => requested_profile || task_profile || workflow_profile,
      "selected_profile" => profile,
      "selection_source" => source,
      "classification" => classification,
      "path_source" => path_source,
      "paths" => paths,
      "signals" => signals,
      "requirements" => requirements,
      "validation" => validation,
      "blockers" => blockers,
      "metrics" => {
        "estimated_role_sessions" => requirements["independent_verification"] ? (profile == "strict" ? 4 : 3) : 2,
        "validation_step_count" => validation.length,
        "report_mode" => requirements["report_mode"]
      }
    }
  end

  def resolve_workflow(catalog, workflow_id, seen = [])
    workflows = catalog.fetch("workflows", {})
    id = workflows.key?(workflow_id) ? workflow_id : catalog["default_workflow"]
    return {} if id.nil? || seen.include?(id)
    entry = workflows[id] || {}
    return entry unless entry["inherits"]

    resolve_workflow(catalog, entry["inherits"], seen + [id]).merge(entry) do |key, parent, child|
      key == "statuses" ? parent.merge(child || {}) : (child.nil? ? parent : child)
    end
  end

  def relevant_paths(task, target, git_cache: nil)
    planned = (Array(task["allowed_paths"]) + Array(task.dig("ownership", "paths"))).map(&:to_s).reject(&:empty?).uniq.sort
    changes = git_change_set(task, target, cache: git_cache)
    return [planned, "task_scope"] unless changes["repository"]

    changed = changes["paths"]
    unless changed.empty?
      paths = changes["base"] ? changed : (planned + changed).uniq.sort
      return [paths, "git_changes"]
    end

    [planned, "task_scope"]
  end

  def git_change_set(task, target, cache: nil)
    base = task["base_sha"].to_s
    base = task["status_ref_sha"].to_s if base.empty?
    repository = cached(cache, ["repository", target]) do
      _output, _error, status = Open3.capture3("git", "-C", target, "rev-parse", "--is-inside-work-tree")
      status.success?
    end
    return {"repository" => false, "base" => base, "base_resolved" => false, "paths" => []} unless repository

    untracked = cached_git_lines(cache, ["untracked", target], target, "ls-files", "--others", "--exclude-standard")
    if base.empty?
      unstaged = cached_git_lines(cache, ["unstaged", target], target, "diff", "--name-only", "--")
      staged = cached_git_lines(cache, ["staged", target], target, "diff", "--cached", "--name-only", "--")
      return {
        "repository" => true,
        "base" => nil,
        "base_resolved" => false,
        "paths" => (unstaged + staged + untracked).uniq.sort
      }
    end

    resolved = cached(cache, ["base_resolved", target, base]) do
      _output, _error, status = Open3.capture3("git", "-C", target, "cat-file", "-e", "#{base}^{commit}")
      status.success?
    end
    changed = if resolved
                cached_git_lines(cache, ["base_diff", target, base], target, "diff", "--name-only", base, "--")
              else
                []
              end
    {
      "repository" => true,
      "base" => base,
      "base_resolved" => resolved,
      "paths" => (changed + untracked).uniq.sort
    }
  end

  def cached(cache, key)
    return cache[key] if cache&.key?(key)

    value = yield
    cache[key] = value if cache
    value
  end

  def cached_git_lines(cache, key, target, *args)
    cached(cache, key) do
      output, error, status = Open3.capture3("git", "-C", target, *args)
      raise RiskProfileError, "cannot inspect Git changes: #{error.strip}" unless status.success?

      output.lines.map(&:strip).reject(&:empty?).uniq.sort
    end
  end

  def classify_paths(paths)
    return "unknown" if paths.empty?
    return "state_only" if paths.all? { |path| path.start_with?(".ai_project/", ".ai_knowledge/") }
    return "docs_only" if paths.all? { |path| path.match?(LIGHT_PATHS) }
    return "product_code" if paths.all? { |path| product_code_path?(path) }
    "mixed"
  end

  def product_code_path?(path)
    path.match?(PRODUCT_PATHS) || CODE_EXTENSIONS.include?(File.extname(path).downcase)
  end

  def risk_signals(task, paths, classification)
    signals = []
    add = lambda do |id, profile, reason|
      signals << {"id" => id, "profile" => profile, "reason" => reason} unless signals.any? { |item| item["id"] == id }
    end
    workflow = task["workflow"].to_s
    type = task["type"].to_s
    priority = task["priority"].to_s
    text = [task["title"], workflow, type, *Array(task["required_capabilities"]), *paths].join(" ")

    add.call("critical_priority", "strict", "critical priority requires the strict profile") if priority == "critical"
    add.call("strict_workflow", "strict", "#{workflow} workflow changes operational or release boundaries") if %w[ops_migration release].include?(workflow) || %w[ops_migration release].include?(type)
    add.call("sensitive_scope", "strict", "security, migration, schema, policy, or release signal detected") if text.match?(STRICT_TERMS)
    add.call("protected_path", "strict", "shared schema, policy, CI, migration, or distribution path detected") if paths.any? { |path| path.match?(STRICT_PATHS) || path == "runtime/workflows.json" }
    add.call("product_code", "standard", "product code or executable source path detected") if %w[product_code mixed].include?(classification) || %w[feature bugfix refactor test].include?(type)
    add.call("documentation_only", "light", "only documentation paths are in scope") if classification == "docs_only"
    add.call("state_only", "light", "only AI Ops state or knowledge paths are in scope") if classification == "state_only"
    add.call("unknown_scope", "standard", "scope cannot be classified safely") if classification == "unknown"
    signals
  end

  def highest_profile(*profiles)
    profiles.compact.max_by { |profile| LEVELS.fetch(profile) }
  end

  def requirements_for(profile)
    case profile
    when "light"
      {
        "roles" => ["Execution Role", "Completion Role"],
        "independent_verification" => false,
        "validation_scope" => "targeted",
        "report_mode" => "compact_receipt",
        "ci_scope" => "targeted",
        "gates" => ["canonical_status", "self_check"]
      }
    when "standard"
      {
        "roles" => ["Execution Role", "Verification Role", "Completion Role"],
        "independent_verification" => true,
        "validation_scope" => "relevant_full",
        "report_mode" => "compact_receipt_with_validation",
        "ci_scope" => "relevant",
        "gates" => ["canonical_status", "independent_verification", "required_checks"]
      }
    else
      {
        "roles" => ["Lead Role", "Execution Role", "Verification Role", "Completion Role", "Release Role"],
        "independent_verification" => true,
        "validation_scope" => "full_regression",
        "report_mode" => "detailed_evidence",
        "ci_scope" => "full",
        "gates" => ["scope_review", "canonical_status", "independent_verification", "required_checks", "release_gate", "risk_acceptance"]
      }
    end
  end

  def validation_for(profile, paths, classification, target)
    steps = [{"id" => "diff_integrity", "phase" => "task", "command" => ["git", "diff", "--check"], "reason" => "detect malformed patches"}]
    if classification == "state_only"
      steps << {"id" => "project_validation", "phase" => "task", "command" => ["aiops", "validate", "project", "--target", target, "--strict"], "reason" => "validate AI Ops state consistency"}
    end
    paths.select { |path| path.end_with?(".sh") || path == "bin/aiops" }.first(20).each do |path|
      steps << {"id" => "shell_syntax", "phase" => "task", "command" => ["sh", "-n", path], "reason" => "validate changed shell syntax"}
    end
    paths.select { |path| path.end_with?(".rb") }.first(20).each do |path|
      steps << {"id" => "ruby_syntax", "phase" => "task", "command" => ["ruby", "-cw", path], "reason" => "validate changed Ruby syntax"}
    end
    paths.select { |path| path.end_with?(".json") }.first(20).each do |path|
      steps << {"id" => "json_syntax", "phase" => "task", "command" => ["ruby", "-rjson", "-e", "JSON.parse(File.read(ARGV.fetch(0)))", path], "reason" => "validate changed JSON syntax"}
    end
    if profile != "light"
      if File.file?(File.join(target, "scripts", "test.sh"))
        steps << {"id" => "project_test_suite", "phase" => "pre_completion", "command" => ["sh", "scripts/test.sh"], "reason" => "run the repository test suite"}
      else
        steps << {"id" => "project_defined_tests", "phase" => "pre_completion", "command" => [], "reason" => "run tests defined by the target project"}
      end
    end
    if profile == "strict"
      steps << {"id" => "release_gate", "phase" => "pre_release", "command" => ["aiops", "release-check", "--strict", "--allow-pending-release"], "reason" => "enforce full release safety checks"}
    end
    steps.uniq { |step| [step["id"], step["command"]] }
  end
end

class TaskRiskProfileCommand
  def initialize(argv)
    @options = {target: Dir.pwd, json: false}
    parse_options(argv)
  end

  def run
    target = File.expand_path(@options[:target])
    task_path = @options[:task_file] ? File.expand_path(@options[:task_file]) : find_task(target, @options[:task_id])
    task = read_front_matter(task_path)
    raise RiskProfileError, "Task ID mismatch in #{task_path}" unless task["id"] == @options[:task_id]
    catalog_path = File.file?(File.join(target, ".ai", "runtime", "workflows.json")) ? File.join(target, ".ai", "runtime", "workflows.json") : File.join(__dir__, "workflows.json")
    catalog = JSON.parse(File.read(catalog_path))
    result = TaskRiskProfiles.evaluate(task: task, target: target, catalog: catalog, requested_profile: @options[:profile])
    if @options[:json]
      puts JSON.pretty_generate(result)
    else
      render(result)
    end
    exit 1 unless result["ready"]
  rescue RiskProfileError => error
    warn "error: #{error.message}"
    exit 1
  rescue JSON::ParserError, Psych::SyntaxError => error
    warn "error: invalid risk profile input: #{error.message.lines.first.to_s.strip}"
    exit 1
  rescue SystemCallError => error
    warn "error: task risk profile I/O failed: #{error.message}"
    exit 1
  end

  private

  def parse_options(argv)
    parser = OptionParser.new do |opts|
      opts.banner = "Usage: aiops task profile TASK_ID [--target DIR] [--profile light|standard|strict] [--json]"
      opts.on("--target DIR") { |value| @options[:target] = value }
      opts.on("--profile PROFILE") { |value| @options[:profile] = value }
      opts.on("--task-file FILE") { |value| @options[:task_file] = value }
      opts.on("--json") { @options[:json] = true }
      opts.on("-h", "--help") { puts opts; exit 0 }
    end
    remaining = parser.parse(argv)
    raise RiskProfileError, "task profile requires exactly one TASK_ID" unless remaining.length == 1
    @options[:task_id] = remaining.first
    raise RiskProfileError, "invalid Task ID: #{@options[:task_id]}" unless @options[:task_id].match?(/\AT-\d{8}-\d{3,}\z/)
  rescue OptionParser::ParseError => error
    raise RiskProfileError, error.message
  end

  def find_task(target, task_id)
    candidates = Dir.glob(File.join(target, ".ai_project", "tasks", "**", "#{task_id}*.md")).sort
    raise RiskProfileError, "task not found: #{task_id}" if candidates.empty?
    raise RiskProfileError, "multiple Task files found for #{task_id}" if candidates.length > 1
    candidates.first
  end

  def read_front_matter(path)
    text = File.read(path)
    raise RiskProfileError, "YAML front matter required: #{path}" unless text.start_with?("---\n")
    lines = text.lines
    closing = lines[1..]&.find_index { |line| line.strip == "---" }
    raise RiskProfileError, "YAML front matter closing marker missing: #{path}" unless closing
    data = YAML.safe_load(lines[1...(closing + 1)].join, permitted_classes: [Date, Time, Symbol], aliases: true)
    raise RiskProfileError, "Task front matter must be an object" unless data.is_a?(Hash)
    data
  end

  def render(result)
    puts "AI Ops Task 운영 프로필"
    puts "Task: #{result['task_id']}"
    puts "선택 프로필: #{result['selected_profile'].capitalize}"
    puts "권장 최소값: #{result['recommended_profile'].capitalize}"
    puts "선택 기준: #{result['selection_source']}"
    puts "변경 분류: #{result['classification']} (#{result['path_source']})"
    puts "필수 Role: #{result.dig('requirements', 'roles').join(' -> ')}"
    puts "독립 검증: #{result.dig('requirements', 'independent_verification') ? '필수' : '생략 가능'}"
    puts "보고: #{result.dig('requirements', 'report_mode')}"
    puts "CI: #{result.dig('requirements', 'ci_scope')}"
    puts "근거:"
    result["signals"].each { |signal| puts "  - [#{signal['profile']}] #{signal['reason']}" }
    puts "검증 계획:"
    result["validation"].each do |step|
      command = step["command"].empty? ? "프로젝트 정의 검사" : step["command"].join(" ")
      puts "  - #{step['phase']}: #{command}"
    end
    result["blockers"].each { |blocker| puts "차단: #{blocker}" }
  end
end

TaskRiskProfileCommand.new(ARGV).run if $PROGRAM_NAME == __FILE__

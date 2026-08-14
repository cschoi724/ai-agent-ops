#!/usr/bin/env ruby
# frozen_string_literal: true

require "date"
require "json"
require "open3"
require "optparse"
require "pathname"
require "shellwords"
require "time"
require "yaml"
require_relative "task_risk_profile"

class ModelAdvisorError < StandardError; end

class ModelAdvisor
  PROFILES = %w[fast balanced coding deep independent_review vision].freeze
  PROVIDER_ALIASES = {
    "codex" => "codex",
    "claude" => "claude_code",
    "claude-code" => "claude_code",
    "claude_code" => "claude_code"
  }.freeze
  ROLE_ALIASES = {
    "direction" => "Direction Role",
    "lead" => "Lead Role",
    "execution" => "Execution Role",
    "verification" => "Verification Role",
    "completion" => "Completion Role",
    "ops" => "Ops Governance Role",
    "ops_governance" => "Ops Governance Role",
    "release" => "Release Role"
  }.freeze
  EFFORT_ORDER = %w[minimal low medium high xhigh max].freeze
  EFFORTS = (["auto"] + EFFORT_ORDER).freeze
  MODEL_ID_PATTERN = /\A[A-Za-z0-9][A-Za-z0-9._:+\/@\[\]-]*\z/.freeze

  def initialize(argv)
    @argv = argv.dup
    @options = {target: Dir.pwd, locale: "ko", json: false}
  end

  def run
    parse_options(@argv)
    @target = File.expand_path(@options[:target])
    @catalog = read_json(@options[:catalog] || File.join(__dir__, "model_catalog.json"), "model catalog")
    validate_catalog!
    @override_path = override_path
    @overrides = @override_path ? read_json(@override_path, "model overrides") : {"schema" => "aiops.model_overrides.v1"}
    validate_overrides!
    @provider_id, detected_by = resolve_provider
    @provider = merged_provider(@provider_id)
    @local = local_provider_settings(@provider_id)
    validate_local_settings!
    @allowlist, allowlist_source = effective_allowlist(@provider_id)
    role = normalize_role(@options[:role])
    task, risk = load_task_context
    recommendations, warnings, blockers = build_recommendations(role, task, risk)

    result = {
      "schema" => "aiops.model_recommendation.v1",
      "generated_at" => Time.now.utc.iso8601,
      "target" => @target,
      "ready" => blockers.empty?,
      "advisory_only" => true,
      "provider" => {
        "id" => @provider_id,
        "display_name" => @provider.fetch("display_name"),
        "command" => @provider.fetch("command"),
        "detected_by" => detected_by,
        "configured_model" => @local["model"],
        "configured_effort" => @local["effort"],
        "configured_worker_model" => @local["worker_model"],
        "configured_worker_effort" => @local["worker_effort"],
        "allowlist_source" => allowlist_source
      },
      "role" => role,
      "task" => task_projection(task, risk),
      "recommendations" => recommendations,
      "sources" => @catalog.fetch("sources").uniq,
      "warnings" => warnings.uniq,
      "blockers" => blockers.uniq
    }

    if @options[:json]
      puts JSON.pretty_generate(result)
    else
      render(result)
    end
    exit 1 unless result["ready"]
  rescue ModelAdvisorError => error
    warn "error: #{error.message}"
    exit 1
  rescue JSON::ParserError, Psych::SyntaxError, KeyError => error
    warn "error: invalid model advisor input: #{error.message.lines.first.to_s.strip}"
    exit 1
  rescue SystemCallError => error
    warn "error: model advisor I/O failed: #{error.message}"
    exit 1
  end

  private

  def parse_options(argv)
    parser = OptionParser.new do |opts|
      opts.banner = "Usage: aiops model recommend --role ROLE [--task TASK_ID] [options]"
      opts.on("--target DIR") { |value| @options[:target] = value }
      opts.on("--role ROLE") { |value| @options[:role] = value }
      opts.on("--task TASK_ID") { |value| @options[:task_id] = value }
      opts.on("--provider PROVIDER") { |value| @options[:provider] = value }
      opts.on("--model MODEL") { |value| @options[:model] = model_id(value, "--model") }
      opts.on("--effort EFFORT") { |value| @options[:effort] = value }
      opts.on("--locale LOCALE") { |value| @options[:locale] = normalize_locale(value) }
      opts.on("--catalog FILE") { |value| @options[:catalog] = value }
      opts.on("--override-file FILE") { |value| @options[:override_file] = value }
      opts.on("--codex-config FILE") { |value| @options[:codex_config] = value }
      opts.on("--claude-settings FILE") { |value| @options[:claude_settings] = value }
      opts.on("--json") { @options[:json] = true }
      opts.on("-h", "--help") { puts opts; exit 0 }
    end
    remaining = parser.parse(argv)
    raise ModelAdvisorError, "model recommend does not accept positional arguments" unless remaining.empty?
    raise ModelAdvisorError, "model recommend requires --role" if @options[:role].to_s.empty?
    if @options[:task_id] && !@options[:task_id].match?(/\AT-\d{8}-\d{3,}\z/)
      raise ModelAdvisorError, "invalid Task ID: #{@options[:task_id]}"
    end
    if @options[:effort] && !%w[auto minimal low medium high xhigh max].include?(@options[:effort])
      raise ModelAdvisorError, "--effort supports: auto, minimal, low, medium, high, xhigh, max"
    end
  rescue OptionParser::ParseError => error
    raise ModelAdvisorError, error.message
  end

  def printable(value, label)
    unless value.is_a?(String) && !value.empty? && !value.match?(/[\x00-\x1f\x7f]/)
      raise ModelAdvisorError, "#{label} must be a non-empty printable value"
    end
    value
  end

  def model_id(value, label)
    raise ModelAdvisorError, "#{label} must be a string" unless value.is_a?(String)
    printable(value, label)
    unless value.match?(MODEL_ID_PATTERN)
      raise ModelAdvisorError, "#{label} contains unsupported characters"
    end
    value
  end

  def normalize_locale(value)
    case value
    when "ko", /^ko[-_]/ then "ko"
    when "en", /^en[-_]/ then "en"
    else raise ModelAdvisorError, "--locale supports: ko, en"
    end
  end

  def read_json(path, label)
    JSON.parse(File.read(File.expand_path(path, @target || Dir.pwd)))
  rescue Errno::ENOENT
    raise ModelAdvisorError, "#{label} not found: #{path}"
  end

  def validate_catalog!
    raise ModelAdvisorError, "model catalog schema must be aiops.model_catalog.v1" unless @catalog["schema"] == "aiops.model_catalog.v1"
    raise ModelAdvisorError, "model catalog providers missing" unless @catalog["providers"].is_a?(Hash) && !@catalog["providers"].empty?
    raise ModelAdvisorError, "model catalog sources missing" unless @catalog["sources"].is_a?(Array) && !@catalog["sources"].empty?
    @catalog.fetch("providers").each do |provider_id, provider|
      raise ModelAdvisorError, "model catalog provider ID invalid: #{provider_id}" unless provider_id.is_a?(String) && provider_id.match?(/\A[a-z][a-z0-9_]*\z/)
      models = provider["models"]
      profiles = provider["profiles"]
      command = provider["command"]
      raise ModelAdvisorError, "model catalog provider #{provider_id} command invalid" unless command.is_a?(String) && command.match?(/\A[A-Za-z0-9._-]+\z/)
      raise ModelAdvisorError, "model catalog provider #{provider_id} models missing" unless models.is_a?(Hash) && !models.empty?
      raise ModelAdvisorError, "model catalog provider #{provider_id} profiles missing" unless profiles.is_a?(Hash)
      models.each_key { |model| model_id(model, "model catalog model") }
      PROFILES.each do |profile|
        mapping = profiles[profile]
        raise ModelAdvisorError, "model catalog provider #{provider_id} missing profile #{profile}" unless mapping.is_a?(Hash)
        %w[model fallback].each do |key|
          raise ModelAdvisorError, "model catalog provider #{provider_id} profile #{profile} references unknown #{key}" unless models.key?(mapping[key])
        end
      end
    end
  end

  def validate_overrides!
    raise ModelAdvisorError, "model overrides must be an object" unless @overrides.is_a?(Hash)
    raise ModelAdvisorError, "model overrides schema must be aiops.model_overrides.v1" unless @overrides["schema"] == "aiops.model_overrides.v1"
    unknown = @overrides.keys - %w[schema default_provider managed_allowlist providers role_profiles]
    raise ModelAdvisorError, "model overrides unknown keys: #{unknown.join(', ')}" unless unknown.empty?
    providers = @overrides.key?("providers") ? @overrides["providers"] : {}
    managed = @overrides.key?("managed_allowlist") ? @overrides["managed_allowlist"] : {}
    role_profiles = @overrides.key?("role_profiles") ? @overrides["role_profiles"] : {}
    raise ModelAdvisorError, "model override providers must be an object" unless providers.is_a?(Hash)
    raise ModelAdvisorError, "managed model allowlist must be an object" unless managed.is_a?(Hash)
    raise ModelAdvisorError, "model override role_profiles must be an object" unless role_profiles.is_a?(Hash)
    known_provider_ids = @catalog.fetch("providers").keys | providers.keys
    unknown_managed = managed.keys - known_provider_ids
    raise ModelAdvisorError, "managed allowlist references unknown providers: #{unknown_managed.join(', ')}" unless unknown_managed.empty?
    default_provider = @overrides["default_provider"]
    if @overrides.key?("default_provider")
      unless default_provider.is_a?(String) && default_provider.match?(/\A[a-z][a-z0-9_]*\z/)
        raise ModelAdvisorError, "default_provider is invalid"
      end
      raise ModelAdvisorError, "default_provider #{default_provider} is not configured" unless known_provider_ids.include?(default_provider)
    end
    managed.each_value do |models|
      raise ModelAdvisorError, "managed model allowlist must be a non-empty array" unless models.is_a?(Array) && !models.empty?
      raise ModelAdvisorError, "managed model allowlist must contain unique models" unless models.uniq.length == models.length
      models.each { |model| model_id(model, "managed allowlist model") }
    end
    role_profiles.each do |role, profile|
      printable(role, "model override Role")
      raise ModelAdvisorError, "model override Role #{role} uses unknown profile #{profile}" unless PROFILES.include?(profile)
    end
    providers.each do |provider_id, provider|
      raise ModelAdvisorError, "model override provider ID invalid: #{provider_id}" unless provider_id.is_a?(String) && provider_id.match?(/\A[a-z][a-z0-9_]*\z/)
      raise ModelAdvisorError, "model override provider #{provider_id} must be an object" unless provider.is_a?(Hash)
      provider_unknown = provider.keys - %w[display_name command allowlist aliases models profiles]
      raise ModelAdvisorError, "model override provider #{provider_id} unknown keys: #{provider_unknown.join(', ')}" unless provider_unknown.empty?
      if provider.key?("display_name")
        printable(provider["display_name"], "model override provider #{provider_id} display_name")
      end
      if provider.key?("command") && (!provider["command"].is_a?(String) || !provider["command"].match?(/\A[A-Za-z0-9._-]+\z/))
        raise ModelAdvisorError, "model override provider #{provider_id} command invalid"
      end
      %w[allowlist].each do |key|
        next unless provider.key?(key)
        values = provider[key]
        raise ModelAdvisorError, "model override provider #{provider_id} #{key} must be a non-empty array" unless values.is_a?(Array) && !values.empty?
        raise ModelAdvisorError, "model override provider #{provider_id} #{key} must be unique" unless values.uniq.length == values.length
        values.each { |model| model_id(model, "model override #{key} model") }
      end
      models = provider.key?("models") ? provider["models"] : {}
      aliases = provider.key?("aliases") ? provider["aliases"] : {}
      profiles = provider.key?("profiles") ? provider["profiles"] : {}
      raise ModelAdvisorError, "model override provider #{provider_id} models must be an object" unless models.is_a?(Hash)
      raise ModelAdvisorError, "model override provider #{provider_id} aliases must be an object" unless aliases.is_a?(Hash)
      raise ModelAdvisorError, "model override provider #{provider_id} profiles must be an object" unless profiles.is_a?(Hash)
      unknown_profiles = profiles.keys - PROFILES
      raise ModelAdvisorError, "model override provider #{provider_id} unknown profiles: #{unknown_profiles.join(', ')}" unless unknown_profiles.empty?
      models.each do |model, definition|
        model_id(model, "model override model")
        validate_override_model!(provider_id, model, definition)
      end
      aliases.each do |name, model|
        model_id(name, "model override alias")
        model_id(model, "model override alias target")
      end
      profiles.each do |profile, mapping|
        validate_override_profile!(provider_id, profile, mapping)
      end
    end
    providers.each_key { |provider_id| merged_provider(provider_id) }
  end

  def validate_override_model!(provider_id, model, definition)
    raise ModelAdvisorError, "model override model #{model} must be an object" unless definition.is_a?(Hash)
    expected = %w[alias efforts vision]
    missing = expected - definition.keys
    unknown = definition.keys - expected
    raise ModelAdvisorError, "model override #{provider_id}/#{model} missing fields: #{missing.join(', ')}" unless missing.empty?
    raise ModelAdvisorError, "model override #{provider_id}/#{model} unknown fields: #{unknown.join(', ')}" unless unknown.empty?
    unless [true, false].include?(definition["alias"])
      raise ModelAdvisorError, "model override #{provider_id}/#{model} alias must be boolean"
    end
    efforts = definition["efforts"]
    unless efforts.is_a?(Array) && !efforts.empty? && efforts.uniq.length == efforts.length && efforts.all? { |effort| EFFORTS.include?(effort) }
      raise ModelAdvisorError, "model override #{provider_id}/#{model} efforts invalid"
    end
    unless [true, false].include?(definition["vision"])
      raise ModelAdvisorError, "model override #{provider_id}/#{model} vision must be boolean"
    end
  end

  def validate_override_profile!(provider_id, profile, mapping)
    raise ModelAdvisorError, "model override provider #{provider_id} profile #{profile} must be an object" unless mapping.is_a?(Hash)
    expected = %w[model effort fallback]
    missing = expected - mapping.keys
    unknown = mapping.keys - expected
    raise ModelAdvisorError, "model override provider #{provider_id} profile #{profile} missing fields: #{missing.join(', ')}" unless missing.empty?
    raise ModelAdvisorError, "model override provider #{provider_id} profile #{profile} unknown fields: #{unknown.join(', ')}" unless unknown.empty?
    model_id(mapping["model"], "model override profile model")
    model_id(mapping["fallback"], "model override profile fallback")
    unless EFFORTS.include?(mapping["effort"])
      raise ModelAdvisorError, "model override provider #{provider_id} profile #{profile} effort invalid"
    end
  end

  def override_path
    return File.expand_path(@options[:override_file], @target) if @options[:override_file]
    candidate = File.join(@target, ".ai_project", "model_overrides.json")
    File.file?(candidate) ? candidate : nil
  end

  def resolve_provider
    if @options[:provider]
      return [normalize_provider(@options[:provider]), "explicit"]
    end
    env_provider = ENV["AIOPS_MODEL_PROVIDER"] || ENV["AIOPS_AGENT_TOOL"]
    return [normalize_provider(env_provider), "environment"] if env_provider && !env_provider.empty?
    return ["codex", "environment"] if ENV["CODEX_HOME"] && !ENV["CODEX_HOME"].empty?
    if (ENV["CLAUDE_CONFIG_DIR"] && !ENV["CLAUDE_CONFIG_DIR"].empty?) || ENV["CLAUDE_CODE_ENTRYPOINT"]
      return ["claude_code", "environment"]
    end
    configured = @overrides["default_provider"]
    return [normalize_provider(configured), "project_override"] if configured

    installed = []
    installed << "codex" if command_available?("codex")
    installed << "claude_code" if command_available?("claude")
    raise ModelAdvisorError, "cannot detect model provider; use --provider codex|claude-code|PROVIDER" if installed.empty?
    raise ModelAdvisorError, "multiple model providers detected (#{installed.join(', ')}); use --provider" if installed.length > 1
    [installed.first, "installed_cli"]
  end

  def normalize_provider(value)
    key = value.to_s.strip
    normalized = PROVIDER_ALIASES.fetch(key, key.tr("-", "_"))
    unless normalized.match?(/\A[a-z][a-z0-9_]*\z/)
      raise ModelAdvisorError, "invalid model provider: #{value}"
    end
    normalized
  end

  def merged_provider(provider_id)
    base = deep_copy(@catalog.dig("providers", provider_id) || {})
    override = deep_copy(@overrides.dig("providers", provider_id) || {})
    %w[display_name command].each { |key| base[key] = override[key] if override[key] }
    base["models"] = (base["models"] || {}).merge(override["models"] || {})
    base["profiles"] = (base["profiles"] || {}).merge(override["profiles"] || {})
    base["aliases"] = override["aliases"] || {}
    base["allowlist"] = override["allowlist"]
    required = %w[display_name command models profiles]
    missing = required.reject { |key| base[key].is_a?(Hash) ? !base[key].empty? : !base[key].to_s.empty? }
    raise ModelAdvisorError, "provider #{provider_id} is not fully configured: missing #{missing.join(', ')}" unless missing.empty?
    missing_profiles = PROFILES - base["profiles"].keys
    raise ModelAdvisorError, "provider #{provider_id} missing profiles: #{missing_profiles.join(', ')}" unless missing_profiles.empty?
    base["profiles"].each do |profile, mapping|
      raise ModelAdvisorError, "provider #{provider_id} profile #{profile} must be an object" unless mapping.is_a?(Hash)
      %w[model effort fallback].each do |key|
        raise ModelAdvisorError, "provider #{provider_id} profile #{profile} missing #{key}" if mapping[key].to_s.empty?
      end
      %w[model fallback].each do |key|
        raise ModelAdvisorError, "provider #{provider_id} profile #{profile} references unknown #{key} #{mapping[key]}" unless base["models"].key?(mapping[key])
      end
      efforts = base["models"].fetch(mapping["model"]).fetch("efforts")
      raise ModelAdvisorError, "provider #{provider_id} profile #{profile} uses unsupported effort #{mapping['effort']}" unless efforts.include?(mapping["effort"])
    end
    base
  end

  def deep_copy(value)
    JSON.parse(JSON.generate(value))
  end

  def normalize_role(value)
    role = ROLE_ALIASES.fetch(value.to_s.downcase.tr(" -", "__"), value.to_s)
    known = (@catalog["role_profiles"] || {}).keys | (@overrides["role_profiles"] || {}).keys
    raise ModelAdvisorError, "unknown Role: #{value}" unless known.include?(role)
    role
  end

  def load_task_context
    return [nil, nil] unless @options[:task_id]
    candidates = Dir.glob(File.join(@target, ".ai_project", "tasks", "**", "#{@options[:task_id]}*.md")).sort
    raise ModelAdvisorError, "task not found: #{@options[:task_id]}" if candidates.empty?
    raise ModelAdvisorError, "multiple Task files found for #{@options[:task_id]}" if candidates.length > 1
    task = read_front_matter(candidates.first)
    raise ModelAdvisorError, "Task ID mismatch in #{candidates.first}" unless task["id"] == @options[:task_id]
    workflow_path = File.file?(File.join(@target, ".ai", "runtime", "workflows.json")) ? File.join(@target, ".ai", "runtime", "workflows.json") : File.join(__dir__, "workflows.json")
    workflow_catalog = read_json(workflow_path, "workflow catalog")
    risk = TaskRiskProfiles.evaluate(task: task, target: @target, catalog: workflow_catalog)
    raise ModelAdvisorError, "Task risk profile is not ready: #{risk['blockers'].join('; ')}" unless risk["ready"]
    [task, risk]
  end

  def read_front_matter(path)
    text = File.read(path)
    raise ModelAdvisorError, "YAML front matter required: #{path}" unless text.start_with?("---\n")
    lines = text.lines
    closing = lines[1..]&.find_index { |line| line.strip == "---" }
    raise ModelAdvisorError, "YAML front matter closing marker missing: #{path}" unless closing
    data = YAML.safe_load(lines[1...(closing + 1)].join, permitted_classes: [Date, Time, Symbol], aliases: true)
    raise ModelAdvisorError, "Task front matter must be an object" unless data.is_a?(Hash)
    data
  end

  def local_provider_settings(provider_id)
    case provider_id
    when "codex" then codex_settings
    when "claude_code" then claude_settings
    else empty_local_settings
    end
  end

  def empty_local_settings
    {
      "model" => nil,
      "effort" => nil,
      "worker_model" => nil,
      "worker_effort" => nil,
      "allowlist" => nil,
      "aliases" => {}
    }
  end

  def codex_settings
    result = empty_local_settings
    paths = if @options[:codex_config]
              [File.expand_path(@options[:codex_config], @target)]
            else
              home = ENV["CODEX_HOME"] && !ENV["CODEX_HOME"].empty? ? ENV["CODEX_HOME"] : File.expand_path("~/.codex")
              [File.join(home, "config.toml"), File.join(@target, ".codex", "config.toml")]
            end
    if @options[:codex_config] && !File.file?(paths.first)
      raise ModelAdvisorError, "Codex config not found: #{@options[:codex_config]}"
    end
    paths.select { |path| File.file?(path) }.each do |path|
      values = parse_codex_config(path)
      result.merge!(values.compact)
    end
    available = ENV["AIOPS_CODEX_AVAILABLE_MODELS"].to_s.split(",").map(&:strip).reject(&:empty?)
    result["allowlist"] = available unless available.empty?
    result
  end

  def parse_codex_config(path)
    section = ""
    values = {}
    File.foreach(path) do |raw|
      line = raw.strip
      next if line.empty? || line.start_with?("#")
      if (match = line.match(/\A\[([^\]]+)\]\z/))
        section = match[1]
        next
      end
      match = line.match(/\A([A-Za-z0-9_.-]+)\s*=\s*(.*)\z/)
      watched = if section.empty?
                  {"model" => "model", "model_reasoning_effort" => "effort"}
                elsif section == "agents"
                  {"default_subagent_model" => "worker_model", "default_subagent_reasoning_effort" => "worker_effort"}
                else
                  {}
                end
      if match && watched.key?(match[1])
        values[watched.fetch(match[1])] = parse_toml_string(match[2], path, match[1])
      elsif watched.keys.any? { |key| line.match?(/\A#{Regexp.escape(key)}\b/) }
        raise ModelAdvisorError, "invalid Codex config #{path}: malformed #{line.split.first} assignment"
      end
    end
    values
  end

  def parse_toml_string(raw, path, key)
    value = raw.strip
    if (match = value.match(/\A"((?:\\.|[^"\\])*)"\s*(?:#.*)?\z/))
      return JSON.parse(%("#{match[1]}"))
    end
    if (match = value.match(/\A'([^']*)'\s*(?:#.*)?\z/))
      return match[1]
    end
    raise ModelAdvisorError, "invalid Codex config #{path}: #{key} must be a quoted string"
  rescue JSON::ParserError
    raise ModelAdvisorError, "invalid Codex config #{path}: malformed #{key} string"
  end

  def claude_settings
    result = empty_local_settings
    paths = if @options[:claude_settings]
              [File.expand_path(@options[:claude_settings], @target)]
            else
              home = ENV["CLAUDE_CONFIG_DIR"] && !ENV["CLAUDE_CONFIG_DIR"].empty? ? ENV["CLAUDE_CONFIG_DIR"] : File.expand_path("~/.claude")
              [File.join(home, "settings.json"), File.join(@target, ".claude", "settings.json")]
            end
    if @options[:claude_settings] && !File.file?(paths.first)
      raise ModelAdvisorError, "Claude Code settings not found: #{@options[:claude_settings]}"
    end
    allowlists = []
    paths.select { |path| File.file?(path) }.each do |path|
      data = read_json(path, "Claude Code settings")
      raise ModelAdvisorError, "Claude Code settings must be an object: #{path}" unless data.is_a?(Hash)
      if data.key?("model")
        raise ModelAdvisorError, "Claude Code settings model must be a non-empty string" unless data["model"].is_a?(String) && !data["model"].empty?
        result["model"] = data["model"]
      end
      if data.key?("effortLevel")
        raise ModelAdvisorError, "Claude Code settings effortLevel must be a non-empty string" unless data["effortLevel"].is_a?(String) && !data["effortLevel"].empty?
        result["effort"] = data["effortLevel"]
      end
      if data.key?("availableModels")
        models = data["availableModels"]
        raise ModelAdvisorError, "Claude Code settings availableModels must be an array of model IDs" unless models.is_a?(Array) && models.all? { |model| model.is_a?(String) && !model.empty? }
        allowlists << models
      end
      if data.key?("env") && !data["env"].is_a?(Hash)
        raise ModelAdvisorError, "Claude Code settings env must be an object"
      end
      env = data["env"] || {}
      alias_map = {
        "opus" => env["ANTHROPIC_DEFAULT_OPUS_MODEL"],
        "sonnet" => env["ANTHROPIC_DEFAULT_SONNET_MODEL"],
        "haiku" => env["ANTHROPIC_DEFAULT_HAIKU_MODEL"]
      }.compact
      result["aliases"].merge!(alias_map)
      result["worker_model"] = env["CLAUDE_CODE_SUBAGENT_MODEL"] if env["CLAUDE_CODE_SUBAGENT_MODEL"].is_a?(String) && !env["CLAUDE_CODE_SUBAGENT_MODEL"].empty?
    end
    result["allowlist"] = allowlists.flatten.uniq unless allowlists.empty?
    result["model"] = ENV["ANTHROPIC_MODEL"] if ENV["ANTHROPIC_MODEL"] && !ENV["ANTHROPIC_MODEL"].empty?
    result["effort"] = ENV["CLAUDE_CODE_EFFORT_LEVEL"] if ENV["CLAUDE_CODE_EFFORT_LEVEL"] && !ENV["CLAUDE_CODE_EFFORT_LEVEL"].empty?
    result["worker_model"] = ENV["CLAUDE_CODE_SUBAGENT_MODEL"] if ENV["CLAUDE_CODE_SUBAGENT_MODEL"] && !ENV["CLAUDE_CODE_SUBAGENT_MODEL"].empty?
    result
  end

  def effective_allowlist(provider_id)
    lists = []
    sources = []
    managed = @overrides.dig("managed_allowlist", provider_id)
    if managed
      lists << managed
      sources << "project_managed_allowlist"
    end
    if @provider["allowlist"]
      lists << @provider["allowlist"]
      sources << "project_provider_allowlist"
    end
    if @local["allowlist"]
      lists << @local["allowlist"]
      sources << "local_provider_allowlist"
    end
    return [nil, nil] if lists.empty?
    [lists.reduce { |left, right| left & right }, sources.join("+")]
  end

  def validate_local_settings!
    %w[model worker_model].each do |key|
      model_id(@local[key], "configured #{key}") if @local[key]
    end
    %w[effort worker_effort].each do |key|
      value = @local[key]
      next unless value
      raise ModelAdvisorError, "configured #{key} is unsupported: #{value}" unless %w[auto minimal low medium high xhigh max].include?(value)
    end
    unless @local["allowlist"].nil? || @local["allowlist"].is_a?(Array)
      raise ModelAdvisorError, "local model allowlist must be an array"
    end
    Array(@local["allowlist"]).each { |model| model_id(model, "local allowlist model") }
    @local.fetch("aliases", {}).each do |name, target|
      model_id(name, "local alias")
      model_id(target, "local alias target")
    end
  end

  def build_recommendations(role, task, risk)
    warnings = []
    blockers = []
    role_profiles = (@catalog["role_profiles"] || {}).merge(@overrides["role_profiles"] || {})
    session_profile = role_profiles.fetch(role)
    task_profile = task_profile_for(role, task, risk)
    verification_required = risk ? risk.dig("requirements", "independent_verification") : role == "Verification Role"
    profiles = {
      "session" => session_profile,
      "task" => task_profile,
      "verification" => "independent_review",
      "delegated_worker" => risk && risk["selected_profile"] == "strict" ? "balanced" : "fast"
    }
    required = {"session" => true, "task" => true, "verification" => !!verification_required, "delegated_worker" => false}
    recommendations = {}
    profiles.each do |purpose, profile|
      explicit_model = purpose == "task" ? @options[:model] : nil
      explicit_effort = purpose == "task" ? @options[:effort] : nil
      source_override = (explicit_model || explicit_effort) ? "cli_override" : nil
      if purpose == "delegated_worker" && @local["worker_model"]
        explicit_model = @local["worker_model"]
        explicit_effort = @local["worker_effort"]
        source_override = "configured_worker"
      end
      resolution = resolve_profile(purpose, profile, required[purpose], explicit_model, explicit_effort, source_override)
      recommendations[purpose == "verification" ? "verification" : purpose] = resolution
      warnings << "#{purpose} recommendation uses unavailable model #{resolution['requested_model']}" unless resolution["available"]
      warnings << "#{purpose} recommendation selected its allowed fallback #{resolution['requested_model']}" if resolution["source"] == "fallback"
      if floating_alias?(resolution["requested_model"]) && resolution["resolved_model"].nil?
        warnings << "#{purpose} recommendation uses provider-resolved floating alias #{resolution['requested_model']}; exact model capabilities may vary"
      end
      blockers << "no allowed model is available for required purpose #{purpose}" if required[purpose] && !resolution["available"]
    end
    [recommendations, warnings, blockers]
  end

  def task_profile_for(role, task, risk)
    return (@overrides["role_profiles"] || {}).fetch(role, (@catalog["role_profiles"] || {}).fetch(role)) unless task
    return "vision" if Array(task["required_capabilities"]).any? { |value| value.to_s.match?(/visual|vision|figma|ui_qa/) }
    return "deep" if risk["selected_profile"] == "strict"
    return "fast" if risk["selected_profile"] == "light" && %w[state_only docs_only].include?(risk["classification"])
    return "independent_review" if role == "Verification Role"
    return "coding" if role == "Execution Role"
    "balanced"
  end

  def resolve_profile(purpose, profile, required, explicit_model, explicit_effort, source_override)
    config = @provider.fetch("profiles").fetch(profile)
    source = (@overrides.dig("providers", @provider_id, "profiles") || {}).key?(profile) ? "project_override" : "built_in_catalog"
    requested = explicit_model || config.fetch("model")
    effort = explicit_effort || config.fetch("effort")
    source = source_override if source_override
    if purpose == "session" && @local["model"] && model_known?(@local["model"]) && allowed?(@local["model"])
      requested = @local["model"]
      effort = @local["effort"] || effort
      source = "configured_session"
    end
    effort = supported_effort(requested, effort)
    fallback_model = config["fallback"]
    fallback_effort = supported_effort(fallback_model, effort)
    fallback = fallback_model ? {
      "model" => fallback_model,
      "resolved_model" => resolved_model(fallback_model),
      "effort" => fallback_effort,
      "available" => model_available?(fallback_model)
    } : nil
    available = model_available?(requested)
    if !available && fallback && fallback["available"]
      requested = fallback_model
      effort = fallback_effort
      source = "fallback"
      available = true
    end
    configured_model = @local["model"]
    if !available && configured_model && model_available?(configured_model)
      requested = configured_model
      effort = supported_effort(configured_model, explicit_effort || @local["effort"] || effort)
      source = "configured_session"
      available = true
    end
    {
      "purpose" => purpose == "verification" ? "independent_verification" : purpose,
      "required" => required,
      "profile" => profile,
      "requested_model" => requested,
      "resolved_model" => resolved_model(requested),
      "effort" => effort,
      "source" => source,
      "reason" => reason_for(purpose, profile),
      "available" => available,
      "requires_new_session" => purpose != "session",
      "launch_command" => available ? launch_command(requested, effort) : [],
      "fallback" => fallback
    }
  end

  def model_known?(model)
    @provider.fetch("models").key?(model) || @provider.fetch("aliases", {}).key?(model) || local_model_candidates.include?(model)
  end

  def model_available?(model)
    model_known?(model) && allowed?(model)
  end

  def allowed?(model)
    return true unless @allowlist
    resolved = resolved_model(model)
    !!(@allowlist.include?(model) || (resolved && @allowlist.include?(resolved)))
  end

  def resolved_model(model)
    override = @provider.fetch("aliases", {})[model]
    local = @local.fetch("aliases", {})[model]
    definition = @provider.fetch("models", {})[model]
    return override || local if definition && definition["alias"]
    override || local || model
  end

  def supported_effort(model, requested)
    allowed = exact_claude_efforts(model)
    definition = @provider.fetch("models", {})[model]
    allowed ||= definition && definition["efforts"]
    allowed ||= @provider.fetch("efforts")
    requested = "auto" if requested.to_s.empty?
    return requested if allowed.include?(requested)
    return allowed.first if requested == "auto"
    rank = EFFORT_ORDER.index(requested) || EFFORT_ORDER.length
    candidates = allowed.reject { |value| value == "auto" }.select { |value| (EFFORT_ORDER.index(value) || -1) <= rank }
    candidates.max_by { |value| EFFORT_ORDER.index(value) || -1 } || allowed.first
  end

  def local_model_candidates
    [@local["model"], @local["worker_model"], *@local.fetch("allowlist", []), *@local.fetch("aliases", {}).values].compact.uniq
  end

  def floating_alias?(model)
    definition = @provider.fetch("models", {})[model]
    definition && definition["alias"] && resolved_model(model).nil?
  end

  def exact_claude_efforts(model)
    return nil unless @provider_id == "claude_code"
    exact = resolved_model(model)
    return nil unless exact
    exact = exact.sub(/\[1m\]\z/, "")
    return %w[auto low medium high xhigh max] if exact.match?(/(?:^|[.:\/-])claude-opus-4-7(?:$|[.:\/-])/)
    return %w[auto low medium high max] if exact.match?(/(?:^|[.:\/-])claude-(?:opus|sonnet)-4-6(?:$|[.:\/-])/)
    nil
  end

  def launch_command(model, effort)
    command = [@provider.fetch("command"), "--model", model]
    return command if effort == "auto"
    if @provider_id == "codex"
      command + ["--config", "model_reasoning_effort=#{effort}"]
    elsif @provider_id == "claude_code"
      command + ["--effort", effort]
    else
      command + ["--effort", effort]
    end
  end

  def reason_for(purpose, profile)
    "#{purpose} purpose maps to #{profile} profile from Role and Task risk"
  end

  def task_projection(task, risk)
    return nil unless task
    {
      "id" => task.fetch("id"),
      "workflow" => task["workflow"],
      "risk_profile" => risk.fetch("selected_profile"),
      "classification" => risk.fetch("classification"),
      "capabilities" => Array(task["required_capabilities"]).map(&:to_s).reject(&:empty?).uniq.sort
    }
  end

  def command_available?(name)
    ENV.fetch("PATH", "").split(File::PATH_SEPARATOR).any? { |dir| File.executable?(File.join(dir, name)) }
  end

  def render(result)
    if @options[:locale] == "en"
      render_en(result)
    else
      render_ko(result)
    end
  end

  def render_ko(result)
    puts "AI Ops 모델 추천"
    puts "실행 환경: #{result.dig('provider', 'display_name')}"
    puts "Role: #{result['role']}"
    puts "Task: #{result.dig('task', 'id') || '없음'}"
    puts "운영 프로필: #{result.dig('task', 'risk_profile') || 'Role 기본값'}"
    print_recommendations(result, {"session" => "세션 유지", "task" => "이번 작업", "verification" => "독립 검증", "delegated_worker" => "보조 worker"})
    puts "안내: 추천만 제공하며 현재 세션의 모델을 자동 변경하지 않습니다."
    result["warnings"].each { |item| puts "경고: #{item}" }
    result["blockers"].each { |item| puts "차단: #{item}" }
  end

  def render_en(result)
    puts "AI Ops model recommendation"
    puts "Provider: #{result.dig('provider', 'display_name')}"
    puts "Role: #{result['role']}"
    puts "Task: #{result.dig('task', 'id') || 'none'}"
    puts "Risk profile: #{result.dig('task', 'risk_profile') || 'Role default'}"
    print_recommendations(result, {"session" => "Session", "task" => "Task", "verification" => "Independent verification", "delegated_worker" => "Delegated worker"})
    puts "Note: advisory only; the current session model is never changed automatically."
    result["warnings"].each { |item| puts "Warning: #{item}" }
    result["blockers"].each { |item| puts "Blocked: #{item}" }
  end

  def print_recommendations(result, labels)
    result.fetch("recommendations").each do |key, item|
      resolved = item["resolved_model"] && item["resolved_model"] != item["requested_model"] ? " -> #{item['resolved_model']}" : ""
      required = item["required"] ? "required" : "optional"
      puts "#{labels.fetch(key)}: #{item['requested_model']}#{resolved} / #{item['effort']} (#{required})"
      puts "  실행: #{item['launch_command'].shelljoin}" unless item["launch_command"].empty?
    end
  end
end

ModelAdvisor.new(ARGV).run if $PROGRAM_NAME == __FILE__

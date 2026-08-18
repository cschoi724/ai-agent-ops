#!/usr/bin/env ruby
# frozen_string_literal: true

require "date"
require "json"
require "optparse"
require "yaml"

class AgentIdentityError < StandardError; end

module AgentIdentity
  ID_PATTERN = /\A[a-z][a-z0-9]*(?:-[a-z0-9]+)*\z/.freeze
  Resolution = Struct.new(:state, :agent, :matches, :matched_by, :migration_required, keyword_init: true)

  class Registry
    attr_reader :agents

    def initialize(agents)
      @agents = Array(agents).select { |entry| entry.is_a?(Hash) }
    end

    def name(agent)
      agent["agent"].to_s
    end

    def id(agent)
      agent["id"].to_s
    end

    def aliases(agent)
      value = agent["aliases"]
      return [] if value.nil?
      return [] unless value.is_a?(Array)

      value.map(&:to_s).reject(&:empty?)
    end

    def duplicate_names
      counts = agents.map { |agent| name(agent) }.reject(&:empty?).each_with_object(Hash.new(0)) do |name, out|
        out[name] += 1
      end
      counts.select { |_name, count| count > 1 }.keys.sort
    end

    def unnamed_agents
      agents.select { |agent| name(agent).empty? }
    end

    def invalid_ids
      agents.map { |agent| id(agent) unless id(agent).empty? || id(agent).match?(ID_PATTERN) }.compact.uniq.sort
    end

    def duplicate_ids
      duplicate_values(agents.map { |agent| id(agent) }.reject(&:empty?))
    end

    def invalid_alias_entries
      agents.select { |agent| agent.key?("aliases") && !agent["aliases"].is_a?(Array) }
    end

    def invalid_alias_values
      agents.select do |agent|
        values = agent["aliases"]
        next false unless values.is_a?(Array)

        values.any? { |value| !value.is_a?(String) || value.empty? || value.match?(/[[:cntrl:]]/) } ||
          values.uniq.length != values.length
      end
    end

    def identity_collisions
      tokens = Hash.new { |hash, key| hash[key] = [] }
      agents.each do |agent|
        values = [["id", id(agent)], ["name", name(agent)]]
        values.concat(aliases(agent).map { |value| ["alias", value] })
        values.each do |kind, value|
          next if value.empty?
          tokens[value] << { "kind" => kind, "agent" => agent }
        end
      end
      tokens.each_with_object({}) do |(value, entries), out|
        identities = entries.map { |entry| entry["agent"].object_id }.uniq
        out[value] = entries if identities.length > 1
      end
    end

    def valid?
      unnamed_agents.empty? && duplicate_names.empty? && duplicate_ids.empty? && invalid_ids.empty? &&
        invalid_alias_entries.empty? && invalid_alias_values.empty? && identity_collisions.empty?
    end

    def resolve(name_reference = nil, id_reference = nil)
      reference_name = name_reference.to_s
      reference_id = id_reference.to_s
      return Resolution.new(state: "unassigned", matches: [], migration_required: false) if reference_name.empty? && reference_id.empty?

      unless reference_id.empty?
        matches = agents.select { |agent| id(agent) == reference_id }
        return Resolution.new(state: "unresolved", matches: [], matched_by: "id", migration_required: false) if matches.empty?
        return Resolution.new(state: "ambiguous", matches: matches, matched_by: "id", migration_required: false) if matches.length > 1

        agent = matches.first
        return Resolution.new(state: "resolved", agent: agent, matches: matches, matched_by: "id", migration_required: false) if reference_name.empty? || name(agent) == reference_name
        if aliases(agent).include?(reference_name)
          return Resolution.new(state: "alias", agent: agent, matches: matches, matched_by: "id", migration_required: true)
        end
        return Resolution.new(state: "mismatch", matches: matches, matched_by: "id", migration_required: false)
      end

      current_matches = agents.select { |agent| name(agent) == reference_name }
      if current_matches.length == 1
        return Resolution.new(state: "legacy", agent: current_matches.first, matches: current_matches, matched_by: "name", migration_required: true)
      end
      return Resolution.new(state: "ambiguous", matches: current_matches, matched_by: "name", migration_required: false) if current_matches.length > 1

      alias_matches = agents.select { |agent| aliases(agent).include?(reference_name) }
      if alias_matches.length == 1
        return Resolution.new(state: "alias", agent: alias_matches.first, matches: alias_matches, matched_by: "alias", migration_required: true)
      end
      return Resolution.new(state: "ambiguous", matches: alias_matches, matched_by: "alias", migration_required: false) if alias_matches.length > 1

      Resolution.new(state: "unresolved", matches: [], migration_required: false)
    end

    def resolve_any(value)
      reference = value.to_s
      return Resolution.new(state: "unassigned", matches: [], migration_required: false) if reference.empty?

      matches = agents.select do |agent|
        id(agent) == reference || name(agent) == reference || aliases(agent).include?(reference)
      end
      case matches.length
      when 0 then Resolution.new(state: "unresolved", matches: [], migration_required: false)
      when 1 then Resolution.new(state: "resolved", agent: matches.first, matches: matches, matched_by: "any", migration_required: false)
      else Resolution.new(state: "ambiguous", matches: matches, matched_by: "any", migration_required: false)
      end
    end

    private

    def duplicate_values(values)
      counts = values.each_with_object(Hash.new(0)) { |value, out| out[value] += 1 }
      counts.select { |_value, count| count > 1 }.keys.sort
    end
  end

  class ProjectAudit
    CURRENT_SCOPES = %w[active backlog].freeze
    SCOPES = [*CURRENT_SCOPES, "archive"].freeze

    def initialize(target)
      @target = File.expand_path(target)
      @project_dir = File.join(@target, ".ai_project")
    end

    def run
      registry_path = File.join(@project_dir, "agent_registry.md")
      registry_data = File.file?(registry_path) ? front_matter(registry_path) : {}
      registry_present = File.file?(registry_path)
      issues = []

      unless registry_present
        issues << issue("error", "agent_registry_missing", ".ai_project/agent_registry.md is missing", path: relative(registry_path))
      end

      agents_value = registry_data["agents"]
      if registry_present && !agents_value.is_a?(Array)
        issues << issue("error", "agent_registry_agents_invalid", "agent_registry agents must be an array", path: relative(registry_path))
      end
      registry = Registry.new(agents_value)
      if registry_present && registry.agents.empty?
        issues << issue("error", "agent_registry_empty", "agent_registry has no Agent entries", path: relative(registry_path))
      end
      registry.unnamed_agents.each do
        issues << issue("error", "agent_name_missing", "agent_registry contains an Agent without a name", path: relative(registry_path))
      end

      registry.duplicate_names.each do |name|
        issues << issue("error", "duplicate_agent_name", "agent_registry contains duplicate Agent name: #{name}", agent: name, path: relative(registry_path))
      end
      registry.duplicate_ids.each do |agent_id|
        issues << issue("error", "duplicate_agent_id", "agent_registry contains duplicate Agent ID: #{agent_id}", agent_id: agent_id, path: relative(registry_path))
      end
      registry.invalid_ids.each do |agent_id|
        issues << issue("error", "invalid_agent_id", "agent_registry contains invalid Agent ID: #{agent_id}", agent_id: agent_id, path: relative(registry_path))
      end
      registry.invalid_alias_entries.each do |agent|
        issues << issue("error", "agent_aliases_invalid", "agent_registry aliases must be an array: #{registry.name(agent)}", agent: registry.name(agent), agent_id: nullable(registry.id(agent)), path: relative(registry_path))
      end
      registry.invalid_alias_values.each do |agent|
        issues << issue("error", "agent_aliases_invalid", "agent_registry aliases must be unique non-empty strings without control characters: #{registry.name(agent)}", agent: registry.name(agent), agent_id: nullable(registry.id(agent)), path: relative(registry_path))
      end
      registry.identity_collisions.each do |value, entries|
        identities = entries.map { |entry| registry.name(entry["agent"]) }.uniq.sort
        issues << issue("error", "agent_identity_collision", "agent_registry identity token is not unique: #{value} (#{identities.join(', ')})", agent: value, path: relative(registry_path))
      end

      references = task_references(registry, issues)
      errors = issues.count { |entry| entry["level"] == "error" }
      warnings = issues.count { |entry| entry["level"] == "warning" }
      current_references = references.count { |entry| CURRENT_SCOPES.include?(entry["scope"]) && (entry["target_agent"] || entry["target_agent_id"]) }
      historical_references = references.count { |entry| entry["scope"] == "archive" && (entry["target_agent"] || entry["target_agent_id"]) }
      migration_required = references.count { |entry| CURRENT_SCOPES.include?(entry["scope"]) && entry["migration_required"] }
      projected_agents = registry.agents.reject { |agent| registry.name(agent).empty? }

      {
        "schema" => "aiops.agent_identity_audit.v1",
        "generated_at" => Time.now.utc.strftime("%Y-%m-%dT%H:%M:%SZ"),
        "target" => @target,
        "ready" => errors.zero?,
        "summary" => {
          "agents" => projected_agents.length,
          "current_references" => current_references,
          "historical_references" => historical_references,
          "migration_required" => migration_required,
          "agents_without_id" => projected_agents.count { |agent| registry.id(agent).empty? },
          "errors" => errors,
          "warnings" => warnings
        },
        "agents" => projected_agents.map do |agent|
          name = registry.name(agent)
          {
            "id" => nullable(registry.id(agent)),
            "name" => name,
            "aliases" => registry.aliases(agent),
            "status" => agent["status"].to_s,
            "roles" => Array(agent["roles"]).map(&:to_s).reject(&:empty?),
            "current_reference_count" => references.count do |reference|
              CURRENT_SCOPES.include?(reference["scope"]) && reference["resolved_agent"] == name
            end
          }
        end,
        "references" => references,
        "issues" => issues,
        "next" => next_actions(errors, warnings, migration_required)
      }
    end

    private

    def task_references(registry, issues)
      SCOPES.flat_map do |scope|
        root = File.join(@project_dir, "tasks", scope)
        next [] unless Dir.exist?(root)

        Dir.glob(File.join(root, "**", "*.md")).sort.map do |path|
          task = front_matter(path)
          task_id = (task["id"] || File.basename(path, ".md")).to_s
          target_agent = task["target_agent"].to_s
          target_agent_id = task["target_agent_id"].to_s
          resolution = registry.resolve(target_agent, target_agent_id)
          current = CURRENT_SCOPES.include?(scope)

          case resolution.state
          when "unresolved"
            level = current ? "error" : "warning"
            code = current ? "target_agent_not_registered" : "historical_target_agent_not_registered"
            message = if current
                        "#{relative(path)} target_agent not registered: #{target_agent}"
                      else
                        "#{relative(path)} archived target_agent is historical: #{target_agent}"
                      end
            issues << issue(level, code, message, path: relative(path), task_id: task_id, agent: target_agent)
          when "ambiguous"
            level = current ? "error" : "warning"
            code = current ? "target_agent_ambiguous" : "historical_target_agent_ambiguous"
            message = "#{relative(path)} target_agent is ambiguous: #{target_agent}"
            issues << issue(level, code, message, path: relative(path), task_id: task_id, agent: target_agent)
          when "mismatch"
            level = current ? "error" : "warning"
            code = current ? "target_agent_identity_mismatch" : "historical_target_agent_identity_mismatch"
            message = "#{relative(path)} target_agent_id #{target_agent_id} does not match target_agent #{target_agent}"
            issues << issue(level, code, message, path: relative(path), task_id: task_id, agent: target_agent, agent_id: target_agent_id)
          when "legacy"
            if current
              message = "#{relative(path)} target_agent uses a legacy name reference; add target_agent_id"
              issues << issue("warning", "target_agent_id_missing", message, path: relative(path), task_id: task_id, agent: target_agent, agent_id: nullable(registry.id(resolution.agent)))
            end
          when "alias"
            if current
              message = "#{relative(path)} target_agent uses legacy alias #{target_agent}; synchronize the current name and Agent ID"
              issues << issue("warning", "target_agent_alias_migration_required", message, path: relative(path), task_id: task_id, agent: target_agent, agent_id: nullable(registry.id(resolution.agent)))
            end
          end

          {
            "task_id" => task_id,
            "path" => relative(path),
            "scope" => scope,
            "target_agent_id" => target_agent_id.empty? ? nil : target_agent_id,
            "target_agent" => target_agent.empty? ? nil : target_agent,
            "state" => resolution.state,
            "matched_by" => resolution.matched_by,
            "migration_required" => current && resolution.migration_required,
            "resolved_agent_id" => resolution.agent ? nullable(registry.id(resolution.agent)) : nil,
            "resolved_agent" => resolution.agent ? registry.name(resolution.agent) : nil
          }
        end
      end
    end

    def front_matter(path)
      text = File.read(path)
      raise AgentIdentityError, "YAML front matter required: #{relative(path)}" unless text.start_with?("---\n")

      lines = text.lines
      closing = lines[1..]&.find_index { |line| line.strip == "---" }
      raise AgentIdentityError, "YAML front matter closing marker missing: #{relative(path)}" unless closing

      data = YAML.safe_load(lines[1...(closing + 1)].join, permitted_classes: [Date, Time, Symbol], aliases: true)
      raise AgentIdentityError, "front matter must be an object: #{relative(path)}" unless data.is_a?(Hash)

      data
    end

    def issue(level, code, message, path: nil, task_id: nil, agent: nil, agent_id: nil)
      {
        "level" => level,
        "code" => code,
        "message" => message,
        "path" => path,
        "task_id" => task_id,
        "agent" => agent,
        "agent_id" => agent_id
      }
    end

    def next_actions(errors, warnings, migration_required)
      return ["fix current Agent references and run aiops agent inspect again"] if errors.positive?
      return ["add stable Agent IDs and target_agent_id values before renaming Agents"] if migration_required.positive?
      return ["historical Agent references are preserved; no routing change is required"] if warnings.positive?

      ["Agent references are ready"]
    end

    def relative(path)
      path.delete_prefix("#{@target}/")
    end

    def nullable(value)
      value.to_s.empty? ? nil : value
    end
  end

  class CLI
    def initialize(argv)
      @options = {target: Dir.pwd, json: false, validation: false, strict: false, locale: ENV.fetch("AIOPS_LOCALE", "ko")}
      parse!(argv)
    end

    def run
      audit = ProjectAudit.new(@options[:target]).run
      if @options[:json]
        puts JSON.pretty_generate(audit)
      elsif @options[:validation]
        render_validation(audit)
      else
        render_user(audit)
      end
      exit 1 if audit["summary"]["errors"].positive? && (@options[:strict] || !@options[:validation])
    rescue AgentIdentityError, Psych::SyntaxError => error
      warn "error: agent identity audit failed: #{error.message.lines.first.to_s.strip}"
      exit 1
    rescue SystemCallError => error
      warn "error: agent identity audit I/O failed: #{error.message}"
      exit 1
    end

    private

    def parse!(argv)
      parser = OptionParser.new do |options|
        options.banner = "Usage: aiops agent inspect [--target DIR] [--json] [--locale ko|en]"
        options.on("--target DIR") { |value| @options[:target] = value }
        options.on("--json") { @options[:json] = true }
        options.on("--locale LOCALE") { |value| @options[:locale] = value }
        options.on("--validation") { @options[:validation] = true }
        options.on("--strict") { @options[:strict] = true }
        options.on("-h", "--help") do
          puts options
          exit 0
        end
      end
      remaining = parser.parse(argv)
      raise AgentIdentityError, "agent inspect does not accept positional arguments" unless remaining.empty?
      raise AgentIdentityError, "--strict is only available to project validation" if @options[:strict] && !@options[:validation]
      raise AgentIdentityError, "--validation cannot be combined with --json" if @options[:validation] && @options[:json]
      @options[:locale] = normalize_locale(@options[:locale])
    rescue OptionParser::ParseError => error
      raise AgentIdentityError, error.message
    end

    def render_validation(audit)
      audit["issues"].each do |issue|
        prefix = issue["level"] == "error" ? "warn" : "note"
        puts "#{prefix}: #{issue['message']}"
      end
      puts "ok: agent identity references" if audit["issues"].empty?
      puts "agent_identity_errors: #{audit['summary']['errors']}"
      puts "agent_identity_warnings: #{audit['summary']['warnings']}"
    end

    def render_user(audit)
      if @options[:locale] == "en"
        puts "AI Ops Agent reference inspection"
        puts "target: #{audit['target']}"
        puts "status: #{audit['ready'] ? 'ready' : 'action required'}"
        puts "agents: #{audit['summary']['agents']}"
        puts "current Task references: #{audit['summary']['current_references']}"
        puts "historical references: #{audit['summary']['historical_references']}"
        puts "identity migration required: #{audit['summary']['migration_required']}"
        puts "Agents without ID: #{audit['summary']['agents_without_id']}"
        puts "errors: #{audit['summary']['errors']}"
        puts "warnings: #{audit['summary']['warnings']}"
      else
        puts "AI Ops Agent 참조 점검"
        puts "대상: #{audit['target']}"
        puts "상태: #{audit['ready'] ? '준비됨' : '수정 필요'}"
        puts "등록 Agent: #{audit['summary']['agents']}"
        puts "현재 Task 참조: #{audit['summary']['current_references']}"
        puts "역사 참조: #{audit['summary']['historical_references']}"
        puts "Identity 마이그레이션 필요: #{audit['summary']['migration_required']}"
        puts "ID 없는 Agent: #{audit['summary']['agents_without_id']}"
        puts "오류: #{audit['summary']['errors']}"
        puts "경고: #{audit['summary']['warnings']}"
      end
      audit["issues"].each { |issue| puts "- [#{issue['level']}] #{issue['message']}" }
    end

    def normalize_locale(locale)
      case locale.to_s
      when /\Ako(?:[-_].*)?\z/i then "ko"
      when /\Aen(?:[-_].*)?\z/i then "en"
      else raise AgentIdentityError, "--locale supports: ko, en"
      end
    end
  end
end

if $PROGRAM_NAME == __FILE__
  begin
    AgentIdentity::CLI.new(ARGV).run
  rescue AgentIdentityError => error
    warn "error: agent identity audit failed: #{error.message}"
    exit 1
  end
end

#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"
require "optparse"
require "tempfile"

class DashboardPresets
  SCHEMA = "aiops.dashboard_presets.v1"
  FILE_NAME = "dashboard_presets.json"
  NAME_PATTERN = /\A[a-z0-9][a-z0-9._-]{0,63}\z/
  REPOSITORY_PATTERN = /\A[A-Za-z0-9_.-]+\/[A-Za-z0-9_.-]+\z/
  CONTROL_PATTERN = /[\x00-\x1f\x7f]/

  ENUMS = {
    "view" => %w[main work risk agents release],
    "level" => %w[compact standard detail],
    "format" => %w[terminal tree mermaid html],
    "map" => %w[summary dependencies swimlane critical-path workflow agents blockers],
    "group_by" => %w[area agent role status workflow],
    "color" => %w[auto always never],
    "locale" => %w[ko en]
  }.freeze
  STRINGS = %w[focus filter_agent filter_role filter_workflow repo locale_file].freeze
  INTEGERS = {"depth" => (0..1_000_000), "port" => (0..65_535), "refresh" => (0..86_400)}.freeze
  BOOLEANS = %w[serve open github].freeze
  OPTION_KEYS = (ENUMS.keys + STRINGS + INTEGERS.keys + BOOLEANS + %w[filter_status]).freeze

  BUILT_INS = {
    "overview" => {
      "description" => "프로젝트 전체 현황",
      "options" => {"view" => "main", "level" => "standard", "format" => "terminal"}
    },
    "work-current" => {
      "description" => "현재 일감과 다음 작업",
      "options" => {"view" => "work", "level" => "standard", "format" => "terminal"}
    },
    "risk-review" => {
      "description" => "주의·위험 항목 검토",
      "options" => {"view" => "risk", "level" => "detail", "format" => "terminal"}
    },
    "agent-load" => {
      "description" => "Agent별 담당 현황",
      "options" => {"view" => "agents", "level" => "standard", "format" => "terminal"}
    },
    "release-readiness" => {
      "description" => "출시 준비 상태",
      "options" => {"view" => "release", "level" => "detail", "format" => "terminal"}
    }
  }.freeze

  class PresetError < StandardError; end

  def initialize(target, file: nil)
    @target = File.expand_path(target)
    @file = file ? File.expand_path(file) : File.join(@target, ".ai_project", FILE_NAME)
  end

  attr_reader :file, :target

  def entries
    built_ins = BUILT_INS.transform_values { |entry| entry.merge("source" => "built-in") }
    locals = local_document.fetch("presets").transform_values do |entry|
      {"description" => entry["description"].to_s, "options" => entry.reject { |key, _| key == "description" }, "source" => "project"}
    end
    built_ins.merge(locals)
  end

  def resolve(name)
    entry = entries[name]
    return entry.merge("name" => name) if entry

    raise PresetError, "unknown dashboard preset: #{name}; available: #{entries.keys.sort.join(', ')}"
  end

  def add(name, description, options, force)
    validate_name!(name)
    raise PresetError, "dashboard preset name is reserved: #{name}" if BUILT_INS.key?(name)
    raise PresetError, "dashboard preset requires at least one dashboard option" if options.empty?
    raise PresetError, ".ai_project missing: #{@target}" unless File.directory?(File.join(@target, ".ai_project"))

    document = local_document
    if document.fetch("presets").key?(name) && !force
      raise PresetError, "dashboard preset already exists: #{name}; use --force to replace it"
    end

    entry = options.dup
    entry["description"] = description unless description.to_s.empty?
    validate_entry!(name, entry)
    validate_effective!(name, options)
    document.fetch("presets")[name] = entry
    write_document(document)
  end

  def local_document
    return {"schema" => SCHEMA, "presets" => {}} unless File.exist?(@file)

    document = JSON.parse(File.read(@file))
    validate_document!(document)
    document
  rescue JSON::ParserError => error
    raise PresetError, "invalid dashboard preset file #{@file}: #{error.message}"
  rescue SystemCallError => error
    raise PresetError, "cannot read dashboard preset file #{@file}: #{error.message}"
  end

  def validate_document!(document)
    raise PresetError, "invalid dashboard preset file #{@file}: root must be an object" unless document.is_a?(Hash)
    unknown = document.keys - %w[schema presets]
    raise PresetError, "invalid dashboard preset file #{@file}: unknown keys #{unknown.join(', ')}" unless unknown.empty?
    raise PresetError, "invalid dashboard preset file #{@file}: schema must be #{SCHEMA}" unless document["schema"] == SCHEMA
    raise PresetError, "invalid dashboard preset file #{@file}: presets must be an object" unless document["presets"].is_a?(Hash)

    document.fetch("presets").each do |name, entry|
      validate_name!(name)
      raise PresetError, "invalid dashboard preset file #{@file}: built-in name is reserved: #{name}" if BUILT_INS.key?(name)
      validate_entry!(name, entry)
      validate_effective!(name, entry.reject { |key, _| key == "description" })
    end
  end

  def validate_name!(name)
    return if name.is_a?(String) && name.match?(NAME_PATTERN)

    raise PresetError, "invalid dashboard preset name: #{name.inspect}; use lowercase letters, numbers, dot, dash, or underscore"
  end

  def validate_entry!(name, entry)
    raise PresetError, "invalid dashboard preset #{name}: value must be an object" unless entry.is_a?(Hash)
    unknown = entry.keys - OPTION_KEYS - %w[description]
    raise PresetError, "invalid dashboard preset #{name}: unknown options #{unknown.join(', ')}" unless unknown.empty?
    raise PresetError, "invalid dashboard preset #{name}: at least one dashboard option is required" if (entry.keys & OPTION_KEYS).empty?

    description = entry["description"]
    validate_text!(name, "description", description) if description

    ENUMS.each do |key, allowed|
      next unless entry.key?(key)
      raise PresetError, "invalid dashboard preset #{name}: #{key} must be one of #{allowed.join(', ')}" unless allowed.include?(entry[key])
    end
    STRINGS.each do |key|
      validate_text!(name, key, entry[key]) if entry.key?(key)
    end
    if entry.key?("repo") && !entry["repo"].match?(REPOSITORY_PATTERN)
      raise PresetError, "invalid dashboard preset #{name}: repo must use owner/name format"
    end
    INTEGERS.each do |key, allowed|
      next unless entry.key?(key)
      value = entry[key]
      raise PresetError, "invalid dashboard preset #{name}: #{key} is out of range" unless value.is_a?(Integer) && allowed.cover?(value)
    end
    BOOLEANS.each do |key|
      next unless entry.key?(key)
      value = entry[key]
      raise PresetError, "invalid dashboard preset #{name}: #{key} must be boolean" unless value == true || value == false
    end
    if entry.key?("filter_status")
      statuses = entry["filter_status"]
      unless statuses.is_a?(Array) && !statuses.empty? && statuses.uniq.length == statuses.length
        raise PresetError, "invalid dashboard preset #{name}: filter_status must be a non-empty unique string array"
      end
      statuses.each { |status| validate_text!(name, "filter_status", status) }
    end
  end

  def validate_text!(name, key, value)
    unless value.is_a?(String) && !value.empty? && !value.match?(CONTROL_PATTERN)
      raise PresetError, "invalid dashboard preset #{name}: #{key} must be a non-empty single-line string"
    end
  end

  def validate_effective!(name, options)
    effective = {
      "view" => "main", "level" => "standard", "format" => "terminal", "map" => "dependencies",
      "group_by" => "area", "depth" => 2, "serve" => false, "port" => 8765, "refresh" => 0, "open" => false
    }.merge(options)
    if effective["serve"] && options.key?("format") && options["format"] != "html"
      raise PresetError, "invalid dashboard preset #{name}: serve requires format html"
    end
    effective["format"] = "html" if effective["serve"]
    effective["map"] = "summary" if effective["serve"] && !options.key?("map")

    if %w[port refresh open].any? { |key| options.key?(key) } && !effective["serve"]
      raise PresetError, "invalid dashboard preset #{name}: port, refresh, and open require serve"
    end
    if options.keys.any? { |key| key.start_with?("filter_") } && effective["format"] != "html"
      raise PresetError, "invalid dashboard preset #{name}: filter options require format html or serve"
    end
    if effective["format"] == "mermaid" && effective["view"] != "work"
      raise PresetError, "invalid dashboard preset #{name}: Mermaid format requires view work"
    end
    if !%w[mermaid html].include?(effective["format"]) && effective["map"] != "dependencies"
      raise PresetError, "invalid dashboard preset #{name}: map requires Mermaid or HTML format"
    end
    if options.key?("repo") && !effective["github"]
      raise PresetError, "invalid dashboard preset #{name}: repo requires github"
    end
    if effective["github"] && effective["view"] != "release"
      raise PresetError, "invalid dashboard preset #{name}: github requires view release"
    end
  end

  def write_document(document)
    temp = Tempfile.new([".dashboard-presets-", ".json"], File.dirname(@file))
    begin
      temp.chmod(0o644)
      handle = temp
      handle.write(JSON.pretty_generate(document))
      handle.write("\n")
      handle.flush
      handle.fsync
      handle.close
      File.rename(handle.path, @file)
    ensure
      temp.close!
    end
  rescue SystemCallError => error
    raise PresetError, "cannot write dashboard preset file #{@file}: #{error.message}"
  end

  def self.cli_args(options)
    flags = {
      "view" => "--view", "level" => "--level", "format" => "--format", "map" => "--map",
      "focus" => "--focus", "depth" => "--depth", "group_by" => "--group-by",
      "filter_status" => "--filter-status", "filter_agent" => "--filter-agent",
      "filter_role" => "--filter-role", "filter_workflow" => "--filter-workflow",
      "port" => "--port", "refresh" => "--refresh", "color" => "--color", "repo" => "--repo",
      "locale" => "--locale", "locale_file" => "--locale-file"
    }
    args = []
    flags.each do |key, flag|
      next unless options.key?(key)
      value = options[key]
      value = value.join(",") if key == "filter_status"
      args.concat([flag, value.to_s])
    end
    args << "--serve" if options["serve"]
    args << "--open" if options["open"]
    args << "--github" if options["github"]
    args
  end
end

def preset_usage
  <<~USAGE
    AI Ops dashboard preset

    Usage:
      aiops project dashboard preset list [--target DIR]
      aiops project dashboard preset show NAME [--target DIR]
      aiops project dashboard preset add NAME [dashboard options] [--target DIR]
      aiops project dashboard --preset NAME [dashboard options]

    Project presets are stored in .ai_project/dashboard_presets.json.
    Explicit dashboard options override values from the selected preset.
  USAGE
end

def preset_add_usage
  <<~USAGE
    AI Ops dashboard preset add

    Usage:
      aiops project dashboard preset add NAME [options]

    Preset file options:
      --target DIR                 Project directory
      --description TEXT           User-facing preset description
      --force                      Replace an existing project preset

    Dashboard options:
      --view VALUE                 main|work|risk|agents|release
      --level VALUE                compact|standard|detail
      --format VALUE               terminal|tree|mermaid|html
      --map VALUE                  summary|dependencies|swimlane|critical-path|workflow|agents|blockers
      --focus TASK_ID              Focus task for graph output
      --depth N                    Graph traversal depth, 0..1000000
      --group-by VALUE             area|agent|role|status|workflow
      --filter-status LIST         Comma-separated status values
      --filter-agent VALUE         Agent filter
      --filter-role VALUE          Role filter
      --filter-workflow VALUE      Workflow filter
      --github                     Include GitHub PR, CI, and release status; requires release view
      --repo OWNER/NAME            Override GitHub repository; requires --github
      --locale VALUE               ko|en; defaults to ko
      --locale-file FILE           Project-relative or absolute label override file
      --serve                      Start the localhost HTML server
      --port N                     Server port, 0..65535; requires --serve
      --refresh N                  Refresh interval, 0..86400; requires --serve
      --open                       Open a browser; requires --serve
      --color VALUE                auto|always|never

    Constraints:
      --serve requires --format html when format is specified.
      Filter options require HTML output or --serve.
      Explicit dashboard options override values from the selected preset.
  USAGE
end

def preset_options_parser(target:, description: nil, force: false, options: {})
  state = {target: target, description: description, force: force, options: options}
  parser = OptionParser.new
  parser.on("-h", "--help") { puts preset_add_usage; exit 0 }
  parser.on("--target DIR") { |value| state[:target] = value }
  parser.on("--description TEXT") { |value| state[:description] = value }
  parser.on("--force") { state[:force] = true }
  DashboardPresets::ENUMS.each_key do |key|
    parser.on("--#{key.tr('_', '-')} VALUE") { |value| state[:options][key] = value }
  end
  DashboardPresets::STRINGS.each do |key|
    parser.on("--#{key.tr('_', '-')} VALUE") { |value| state[:options][key] = value }
  end
  DashboardPresets::INTEGERS.each_key do |key|
    parser.on("--#{key.tr('_', '-')} N", Integer) { |value| state[:options][key] = value }
  end
  parser.on("--filter-status LIST") do |value|
    state[:options]["filter_status"] = value.split(",").map(&:strip).reject(&:empty?)
  end
  parser.on("--serve") { state[:options]["serve"] = true }
  parser.on("--open") { state[:options]["open"] = true }
  parser.on("--github") { state[:options]["github"] = true }
  [parser, state]
end

def parse_target!(arguments)
  target = Dir.pwd
  parser = OptionParser.new
  parser.on("-h", "--help") { puts preset_usage; exit 0 }
  parser.on("--target DIR") { |value| target = value }
  parser.parse!(arguments)
  target
end

begin
  action = ARGV.shift.to_s

  case action
  when "help", "-h", "--help"
    puts preset_usage
  when "run"
    aiops = nil
    parser = OptionParser.new
    parser.on("--aiops PATH") { |value| aiops = value }
    parser.order!(ARGV)
    raise DashboardPresets::PresetError, "dashboard preset runner requires --aiops" unless aiops

    dashboard_args = ARGV.dup
    target = Dir.pwd
    preset_name = nil
    expanded_args = []
    index = 0
    while index < dashboard_args.length
      argument = dashboard_args[index]
      if argument == "--preset"
        raise DashboardPresets::PresetError, "--preset requires a value" if index + 1 >= dashboard_args.length
        raise DashboardPresets::PresetError, "only one --preset may be used" if preset_name
        preset_name = dashboard_args[index + 1]
        index += 2
        next
      end
      if argument == "--target"
        raise DashboardPresets::PresetError, "--target requires a value" if index + 1 >= dashboard_args.length
        target = dashboard_args[index + 1]
      end
      expanded_args << argument
      index += 1
    end
    raise DashboardPresets::PresetError, "--preset requires a value" if preset_name.to_s.empty?

    entry = DashboardPresets.new(target).resolve(preset_name)
    exec(File.expand_path(aiops), "project", "dashboard", *DashboardPresets.cli_args(entry.fetch("options")), *expanded_args)
  when "list"
    target = parse_target!(ARGV)
    store = DashboardPresets.new(target)
    puts "AI Ops dashboard presets"
    puts "target: #{store.target}"
    puts ""
    store.entries.each do |name, entry|
      puts "#{name}  [#{entry.fetch('source')}]  #{entry.fetch('description')}"
    end
  when "show"
    if %w[-h --help].include?(ARGV.first)
      puts preset_usage
      exit 0
    end
    name = ARGV.shift.to_s
    raise DashboardPresets::PresetError, "dashboard preset show requires NAME" if name.empty?
    target = parse_target!(ARGV)
    store = DashboardPresets.new(target)
    entry = store.resolve(name)
    puts "AI Ops dashboard preset"
    puts "target: #{store.target}"
    puts "name: #{name}"
    puts "source: #{entry.fetch('source')}"
    puts "description: #{entry.fetch('description')}"
    puts "command: aiops project dashboard --preset #{name}"
    puts "options:"
    entry.fetch("options").each { |key, value| puts "  #{key}: #{value.is_a?(Array) ? value.join(',') : value}" }
  when "add"
    if %w[-h --help].include?(ARGV.first)
      puts preset_add_usage
      exit 0
    end
    name = ARGV.shift.to_s
    raise DashboardPresets::PresetError, "dashboard preset add requires NAME" if name.empty?
    parser, state = preset_options_parser(target: Dir.pwd)
    parser.parse!(ARGV)
    store = DashboardPresets.new(state.fetch(:target))
    store.add(name, state.fetch(:description), state.fetch(:options), state.fetch(:force))
    puts "AI Ops dashboard preset add"
    puts "target: #{store.target}"
    puts "preset: #{name}"
    puts "file: #{store.file}"
  when "validate"
    file = ARGV.shift.to_s
    raise DashboardPresets::PresetError, "dashboard preset validate requires FILE" if file.empty?
    raise DashboardPresets::PresetError, "dashboard preset file not found: #{file}" unless File.file?(file)
    target = File.dirname(File.dirname(File.expand_path(file)))
    DashboardPresets.new(target, file: file).local_document
    puts "ok: dashboard preset semantics"
  else
    raise DashboardPresets::PresetError, "unknown dashboard preset action: #{action}; use list, show, add, or validate"
  end
rescue DashboardPresets::PresetError, OptionParser::ParseError => error
  warn "dashboard preset error: #{error.message}"
  exit 1
rescue SystemCallError => error
  warn "dashboard preset error: file operation failed: #{error.message}"
  exit 1
end

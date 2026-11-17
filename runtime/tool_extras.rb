#!/usr/bin/env ruby
# frozen_string_literal: true

# Installs and inspects the tool-specific project files (Role subagents,
# skills, and .ai/ protection hooks) for Claude Code and Codex.
#
#   tool_extras.rb install --core DIR --target DIR --adapter codex|claude|both [--force]
#   tool_extras.rb status  --core DIR --target DIR [--adapter codex|claude|both|auto] [--json]
#
# Templates live in templates/tool_adapters/<tool>/project_files/ with "dot_"
# standing for a leading ".". Plain files are created when missing and never
# overwritten without --force. Hook settings files are merged: only the AI Ops
# guard entry is added or refreshed, every other user setting is preserved.

require "fileutils"
require "json"
require "optparse"

class ToolExtras
  TOOLS = {
    "claude" => { "label" => "Claude Code", "settings" => ".claude/settings.json" },
    "codex" => { "label" => "Codex", "settings" => ".codex/hooks.json" }
  }.freeze
  GUARD_MARKER = "guard pre-tool-use"

  class Error < StandardError; end

  def initialize(argv)
    @argv = argv.dup
    @action = @argv.shift
    @options = { core: nil, target: Dir.pwd, adapter: "auto", force: false, json: false }
  end

  def run
    parse!
    case @action
    when "install" then install
    when "status" then status
    else raise Error, "usage: tool_extras.rb install|status --core DIR --target DIR [--adapter codex|claude|both]"
    end
  rescue Error, OptionParser::ParseError => e
    warn "aiops tool extras: #{e.message}"
    1
  end

  private

  def parse!
    OptionParser.new do |opts|
      opts.on("--core DIR") { |value| @options[:core] = value }
      opts.on("--target DIR") { |value| @options[:target] = value }
      opts.on("--adapter NAME") { |value| @options[:adapter] = value }
      opts.on("--force") { @options[:force] = true }
      opts.on("--json") { @options[:json] = true }
    end.parse!(@argv)
    raise Error, "--core is required" unless @options[:core]

    @core = File.expand_path(@options[:core])
    @target = File.expand_path(@options[:target])
    raise Error, "target directory not found: #{@target}" unless Dir.exist?(@target)
  end

  def tools
    case @options[:adapter]
    when "codex" then ["codex"]
    when "claude" then ["claude"]
    when "both" then %w[codex claude]
    when "auto"
      found = []
      found << "codex" if File.file?(File.join(@target, "AGENTS.md"))
      found << "claude" if File.file?(File.join(@target, "CLAUDE.md"))
      found
    else raise Error, "unknown adapter: #{@options[:adapter]}"
    end
  end

  def template_root(tool)
    File.join(@core, "templates", "tool_adapters", tool, "project_files")
  end

  # [[template_path, project_relative_path], ...]
  def entries(tool)
    root = template_root(tool)
    raise Error, "tool templates missing: #{root}" unless Dir.exist?(root)

    Dir.glob(File.join(root, "**", "*"), File::FNM_DOTMATCH).select { |path| File.file?(path) }.sort.map do |path|
      relative = path.delete_prefix("#{root}/").split("/").map { |part| part.sub(/\Adot_/, ".") }.join("/")
      [path, relative]
    end
  end

  def settings_file?(tool, relative)
    TOOLS.fetch(tool).fetch("settings") == relative
  end

  def install
    results = []
    tools.each do |tool|
      entries(tool).each do |template, relative|
        results << (settings_file?(tool, relative) ? merge_settings(template, relative) : copy_file(template, relative))
      end
    end
    results.each { |line| puts line }
    if tools.include?("codex")
      puts "note: Codex는 프로젝트 hook을 처음 한 번 승인해야 실행합니다. Codex에서 /hooks 로 AI Ops guard hook을 검토하고 trust 하세요."
    end
    0
  end

  def copy_file(template, relative)
    dest = File.join(@target, relative)
    content = File.binread(template)
    if File.exist?(dest)
      return "ok: #{relative}" if File.binread(dest) == content
      return "skip: #{relative} differs from AI Ops template (use --force to replace)" unless @options[:force]
    end
    FileUtils.mkdir_p(File.dirname(dest))
    existed = File.exist?(dest)
    File.binwrite(dest, content)
    "#{existed ? 'replaced' : 'created'}: #{relative}"
  end

  def read_json(path)
    data = JSON.parse(File.read(path))
    raise Error, "#{path} must contain a JSON object" unless data.is_a?(Hash)

    data
  rescue JSON::ParserError => e
    raise Error, "cannot merge #{path}: invalid JSON (#{e.message})"
  end

  def guard_group?(group)
    group.is_a?(Hash) && Array(group["hooks"]).any? { |hook| hook.is_a?(Hash) && hook["command"].to_s.include?(GUARD_MARKER) }
  end

  def merged_settings(existing, template)
    merged = JSON.parse(JSON.generate(existing))
    hooks = merged["hooks"].is_a?(Hash) ? merged["hooks"] : {}
    template.fetch("hooks").each do |event, groups|
      current = Array(hooks[event]).reject { |group| guard_group?(group) }
      hooks[event] = current + groups
    end
    merged["hooks"] = hooks
    merged
  end

  def merge_settings(template, relative)
    dest = File.join(@target, relative)
    wanted = read_json(template)
    unless File.exist?(dest)
      FileUtils.mkdir_p(File.dirname(dest))
      File.write(dest, "#{JSON.pretty_generate(wanted)}\n")
      return "created: #{relative}"
    end
    existing = read_json(dest)
    merged = merged_settings(existing, wanted)
    return "ok: #{relative} (AI Ops guard hook present)" if merged == existing

    File.write(dest, "#{JSON.pretty_generate(merged)}\n")
    "updated: #{relative} (AI Ops guard hook merged; other settings kept)"
  end

  def status
    report = { "tools" => {} }
    tools.each do |tool|
      files = entries(tool).map do |template, relative|
        dest = File.join(@target, relative)
        state = if !File.exist?(dest)
                  "missing"
                elsif settings_file?(tool, relative)
                  begin
                    merged_settings(read_json(dest), read_json(template)) == read_json(dest) ? "ok" : "drift"
                  rescue Error
                    "invalid"
                  end
                else
                  File.binread(dest) == File.binread(template) ? "ok" : "differs"
                end
        { "path" => relative, "state" => state }
      end
      report["tools"][tool] = files
    end
    if @options[:json]
      puts JSON.pretty_generate(report)
    else
      report["tools"].each do |tool, files|
        label = TOOLS.fetch(tool).fetch("label")
        files.each do |file|
          level = case file["state"]
                  when "ok" then "ok"
                  when "differs" then "note"
                  else "warn"
                  end
          puts "#{level}: #{label} #{file['path']} #{file['state']}"
        end
      end
    end
    0
  end
end

exit ToolExtras.new(ARGV).run if $PROGRAM_NAME == __FILE__

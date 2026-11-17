#!/usr/bin/env ruby
# frozen_string_literal: true

# Generates every tool-specific adapter file from one shared source so Codex
# and Claude receive the same operating rules, Role subagents, skills, and
# protection hooks.
#
#   ruby scripts/build_adapters.rb          # rewrite generated files
#   ruby scripts/build_adapters.rb --check  # fail when generated files are stale
#
# Shared sources (templates/tool_adapters/_source/):
#   adapter.md.erb         -> codex/AGENTS.md, claude/CLAUDE.md
#   roles/<slug>.md        -> Role subagent definitions for each tool
#   skills/<name>/SKILL.md -> skills for each tool (same Agent Skills format)
#   hooks                  -> built here from GUARD_* constants
#
# Files under <tool>/project_files/ mirror the target project layout, with a
# leading "dot_" standing for "." (dot_claude -> .claude).

require "erb"
require "fileutils"
require "json"
require "yaml"

ROOT = File.expand_path("..", __dir__)
ADAPTERS_DIR = File.join(ROOT, "templates", "tool_adapters")
SOURCE_DIR = File.join(ADAPTERS_DIR, "_source")

ADAPTERS = [
  { "tool" => "Codex", "other_tool" => "Claude", "file" => "AGENTS.md", "dir" => "codex" },
  { "tool" => "Claude", "other_tool" => "Codex", "file" => "CLAUDE.md", "dir" => "claude" }
].freeze

GUARD_STATUS = "AI Ops: .ai/ 보호 경로 점검"

# Project-relative hook commands. Each tool resolves the project root its own way.
CLAUDE_GUARD_COMMAND = '"$CLAUDE_PROJECT_DIR/.ai/bin/aiops" guard pre-tool-use --provider claude-code'
CODEX_GUARD_COMMAND = 'root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"; "$root/.ai/bin/aiops" guard pre-tool-use --provider codex'

def render_erb(template, values)
  context = Object.new
  values.each do |key, value|
    context.define_singleton_method(key) { value }
  end
  ERB.new(template).result(context.instance_eval { binding })
end

def split_front_matter(path)
  text = File.read(path)
  match = text.match(/\A---\n(.*?)\n---\n\n?(.*)\z/m)
  raise "#{path}: missing front matter" unless match

  data = YAML.safe_load(match[1]) || {}
  %w[name description].each do |key|
    raise "#{path}: front matter #{key} is required" if data[key].to_s.strip.empty?
  end
  [data, match[2]]
end

def yaml_scalar(value)
  # Quote every value so Korean punctuation and colons stay plain strings.
  JSON.generate(value.to_s)
end

def claude_agent(data, body)
  <<~MD + body
    ---
    name: #{data.fetch('name')}
    description: #{yaml_scalar(data.fetch('description'))}
    ---

  MD
end

def toml_string(value)
  JSON.generate(value.to_s)
end

def codex_agent(data, body)
  raise "#{data['name']}: body must not contain '''" if body.include?("'''")

  <<~TOML
    # Generated from templates/tool_adapters/_source/roles by scripts/build_adapters.rb.
    name = #{toml_string(data.fetch('name'))}
    description = #{toml_string(data.fetch('description'))}
    developer_instructions = '''
    #{body.chomp}
    '''
  TOML
end

def claude_settings
  {
    "hooks" => {
      "PreToolUse" => [
        {
          "matcher" => "Edit|Write|MultiEdit|NotebookEdit|Bash",
          "hooks" => [{ "type" => "command", "command" => CLAUDE_GUARD_COMMAND }]
        }
      ]
    }
  }
end

def codex_hooks
  {
    "hooks" => {
      "PreToolUse" => [
        {
          "matcher" => "^(Bash|apply_patch|Edit|Write)$",
          "hooks" => [{ "type" => "command", "command" => CODEX_GUARD_COMMAND, "statusMessage" => GUARD_STATUS }]
        }
      ]
    }
  }
end

def pretty_json(data)
  "#{JSON.pretty_generate(data)}\n"
end

def generated_files
  files = {}
  template = File.read(File.join(SOURCE_DIR, "adapter.md.erb"))
  ADAPTERS.each do |adapter|
    files[File.join(adapter.fetch("dir"), adapter.fetch("file"))] = render_erb(template, adapter)
  end

  Dir.glob(File.join(SOURCE_DIR, "roles", "*.md")).sort.each do |path|
    data, body = split_front_matter(path)
    name = data.fetch("name")
    files["claude/project_files/dot_claude/agents/#{name}.md"] = claude_agent(data, body)
    files["codex/project_files/dot_codex/agents/#{name}.toml"] = codex_agent(data, body)
  end

  Dir.glob(File.join(SOURCE_DIR, "skills", "*", "SKILL.md")).sort.each do |path|
    data, = split_front_matter(path)
    skill_dir = File.basename(File.dirname(path))
    raise "#{path}: name must match directory #{skill_dir}" unless data["name"] == skill_dir

    text = File.read(path)
    files["claude/project_files/dot_claude/skills/#{skill_dir}/SKILL.md"] = text
    files["codex/project_files/dot_agents/skills/#{skill_dir}/SKILL.md"] = text
  end

  files["claude/project_files/dot_claude/settings.json"] = pretty_json(claude_settings)
  files["codex/project_files/dot_codex/hooks.json"] = pretty_json(codex_hooks)
  files
end

check = ARGV.include?("--check")
unknown = ARGV - ["--check"]
abort "usage: build_adapters.rb [--check]" unless unknown.empty?

files = generated_files
stale = []
files.each do |relative, content|
  path = File.join(ADAPTERS_DIR, relative)
  next if File.file?(path) && File.read(path) == content

  if check
    stale << relative
  else
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, content)
    puts "generated: templates/tool_adapters/#{relative}"
  end
end

# Generated trees must not keep files whose source was removed.
%w[claude/project_files codex/project_files].each do |tree|
  Dir.glob(File.join(ADAPTERS_DIR, tree, "**", "*"), File::FNM_DOTMATCH).each do |path|
    next unless File.file?(path)

    relative = path.delete_prefix("#{ADAPTERS_DIR}/")
    next if files.key?(relative)

    if check
      stale << "#{relative} (no source)"
    else
      File.delete(path)
      puts "removed: templates/tool_adapters/#{relative}"
    end
  end
end

unless stale.empty?
  warn "stale generated adapter files (run ruby scripts/build_adapters.rb):"
  stale.each { |entry| warn "  #{entry}" }
  exit 1
end
puts "ok: generated adapter files match templates/tool_adapters/_source" if check

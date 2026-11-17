#!/usr/bin/env ruby
# frozen_string_literal: true

# Generates the Codex and Claude adapter files from one shared source so both
# tools receive the same operating rules.
#
#   ruby scripts/build_adapters.rb          # rewrite generated adapter files
#   ruby scripts/build_adapters.rb --check  # fail when generated files are stale

require "erb"

ROOT = File.expand_path("..", __dir__)
SOURCE = File.join(ROOT, "templates", "tool_adapters", "_source", "adapter.md.erb")

ADAPTERS = [
  { "tool" => "Codex", "other_tool" => "Claude", "file" => "AGENTS.md", "dir" => "codex" },
  { "tool" => "Claude", "other_tool" => "Codex", "file" => "CLAUDE.md", "dir" => "claude" }
].freeze

def render(template, values)
  context = Object.new
  values.each { |key, value| context.instance_variable_set("@#{key}", value) }
  values.each_key do |key|
    context.define_singleton_method(key) { instance_variable_get("@#{key}") }
  end
  ERB.new(template).result(context.instance_eval { binding })
end

check = ARGV.include?("--check")
unknown = ARGV - ["--check"]
abort "usage: build_adapters.rb [--check]" unless unknown.empty?

template = File.read(SOURCE)
stale = []
ADAPTERS.each do |adapter|
  output = render(template, adapter)
  path = File.join(ROOT, "templates", "tool_adapters", adapter.fetch("dir"), adapter.fetch("file"))
  current = File.file?(path) ? File.read(path) : nil
  next if current == output

  if check
    stale << path.delete_prefix("#{ROOT}/")
  else
    File.write(path, output)
    puts "generated: #{path.delete_prefix("#{ROOT}/")}"
  end
end

unless stale.empty?
  warn "stale adapter files (run ruby scripts/build_adapters.rb): #{stale.join(', ')}"
  exit 1
end
puts "ok: adapter files match #{SOURCE.delete_prefix("#{ROOT}/")}" if check

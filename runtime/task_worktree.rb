#!/usr/bin/env ruby
# frozen_string_literal: true

# Parallel Tasks in a shared team folder. There is no running-Task limit:
# the Lead splits work into Tasks whose allowed_paths do not overlap, and
# running Tasks that share a team (or a folder) must keep it that way. Each
# Task stages and commits only its own paths (the guard enforces this).
#
#   task_worktree.rb checks [TASK_ID] [--target DIR] [--dir DIR]
#
# Project checks are the Owner's own tests kept outside the product
# repository in .ai_project/checks/ (entry point run.sh), so every folder
# shares one copy and other developers' test suites are not touched.

require "date"
require "optparse"
require "yaml"

module TaskWorktree
  # Statuses of a Task that is being worked on (its paths are in use).
  ACTIVE_STATUSES = %w[in_progress verification_ready verification_in_progress verification_passed completion_review rework_requested].freeze
  TEAM_WORKTREE_PREFIX = %r{\A\.worktrees/[^/]+/}.freeze
  CHECKS_DIR = ".ai_project/checks"

  class Error < StandardError; end

  module_function

  def parse_front_matter(text)
    match = text.match(/\A---\n(.*?)\n---\n/m)
    return {} unless match

    data = YAML.safe_load(match[1], permitted_classes: [Date, Time, Symbol], aliases: true)
    data.is_a?(Hash) ? data : {}
  end

  def read_front_matter(path)
    File.file?(path) ? parse_front_matter(File.read(path)) : {}
  rescue Psych::Exception
    {}
  end

  def team_key(team)
    team.to_s.strip.downcase
  end

  def agents(target)
    data = read_front_matter(File.join(target, ".ai_project", "agent_registry.md"))
    Array(data["agents"]).select { |agent| agent.is_a?(Hash) }
  end

  def task_files(target)
    Dir.glob(File.join(target, ".ai_project", "tasks", "**", "T-*.md")).reject { |path| path.include?("/archive/") }.sort
  end

  def find_task(target, task_id)
    matches = task_files(target).select { |path| File.basename(path, ".md") == task_id || File.basename(path).start_with?("#{task_id}_", "#{task_id}-", "#{task_id}.") }
    raise Error, "task not found: #{task_id}" if matches.empty?
    raise Error, "multiple Task files found for #{task_id}" if matches.length > 1

    matches.first
  end

  # Folder a Task works in: its worktree_path, else the project root.
  def folder(target, task)
    path = task["worktree_path"].to_s.strip
    File.expand_path(path.empty? ? target : path, target)
  end

  # Other running Tasks that share the Task's team or folder.
  def neighbors(target, task)
    key = team_key(task["team"])
    dir = folder(target, task)
    task_files(target).map { |path| read_front_matter(path) }.select do |other|
      next false if other["id"].to_s == task["id"].to_s || !ACTIVE_STATUSES.include?(other["status"].to_s)

      (!key.empty? && team_key(other["team"]) == key) || folder(target, other) == dir
    end
  end

  # Paths two running Tasks must not share: product paths (the
  # `.worktrees/<name>/` prefix is dropped) and the shared project checks.
  # Other AI Ops records are left out.
  def product_paths(task)
    Array(task["allowed_paths"]).map { |path| path.to_s.strip.sub(%r{\A\./}, "").sub(%r{/+\z}, "") }.reject(&:empty?).reject do |path|
      (path.start_with?(".ai_project/", ".ai_knowledge/") || path == ".ai_project") && !(path == CHECKS_DIR || path.start_with?("#{CHECKS_DIR}/"))
    end.map { |path| path.sub(TEAM_WORKTREE_PREFIX, "") }.uniq
  end

  def overlap(left, right)
    left.each do |a|
      right.each do |b|
        return [a, b] if a == "." || b == "." || a == b || a.start_with?("#{b}/") || b.start_with?("#{a}/")
      end
    end
    nil
  end

  # Checked when a Task starts (approved -> in_progress). Returns nil or an error message.
  def start_problem(target, task)
    mine = product_paths(task)
    neighbors(target, task).each do |other|
      hit = overlap(mine, product_paths(other))
      next unless hit

      return "allowed_paths overlap with running Task #{other['id']}: #{hit[0]} / #{hit[1]}; " \
             "split the work so paths do not overlap, or wait for it (depends_on)"
    end
    nil
  end

  # Paths owned by other running Tasks in the same folder; their changes are
  # not this Task's out-of-scope changes.
  def neighbor_paths(target, task)
    dir = folder(target, task)
    neighbors(target, task).select { |other| folder(target, other) == dir }.flat_map { |other| product_paths(other) }.uniq
  end

  def checks_env(target, dir, task_id)
    env = { "AIOPS_PROJECT_ROOT" => target, "AIOPS_CHECKS_DIR" => File.join(target, CHECKS_DIR), "AIOPS_WORKTREE" => dir }
    env["AIOPS_TASK_ID"] = task_id if task_id
    env
  end

  class CLI
    def initialize(argv)
      @argv = argv.dup
      @action = @argv.shift
      @target = Dir.pwd
    end

    def run
      return checks if @action == "checks"

      warn "usage: aiops worktree checks [TASK_ID] [--target DIR] [--dir DIR]"
      1
    rescue Error, OptionParser::ParseError => e
      warn "aiops worktree: #{e.message}"
      1
    end

    private

    # Runs the project checks (.ai_project/checks/run.sh) against a folder:
    # --dir, else the Task's folder, else the current folder.
    def checks
      dir = nil
      remaining = OptionParser.new do |opts|
        opts.on("--target DIR") { |value| @target = value }
        opts.on("--dir DIR") { |value| dir = value }
      end.parse(@argv)
      raise Error, "at most one TASK_ID is allowed" if remaining.length > 1

      target = File.expand_path(@target)
      task_id = remaining.first
      dir ||= TaskWorktree.folder(target, TaskWorktree.read_front_matter(TaskWorktree.find_task(target, task_id))) if task_id
      dir = File.expand_path(dir || Dir.pwd)
      raise Error, "#{dir} is not a directory" unless File.directory?(dir)

      script = File.join(target, CHECKS_DIR, "run.sh")
      raise Error, "#{CHECKS_DIR}/run.sh not found; project checks are not set up" unless File.file?(script)

      puts "checks: #{CHECKS_DIR}/run.sh in #{dir}"
      ok = system(TaskWorktree.checks_env(target, dir, task_id), "sh", script, chdir: dir)
      puts(ok ? "checks passed" : "checks failed")
      ok ? 0 : 1
    end
  end
end

exit TaskWorktree::CLI.new(ARGV).run if $PROGRAM_NAME == __FILE__

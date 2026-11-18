#!/usr/bin/env ruby
# frozen_string_literal: true

# Parallel Tasks: per-team limits, one git worktree per running Task, and
# merging a finished Task branch back into the team base branch.
#
#   task_worktree.rb create TASK_ID [--target DIR] [--repo DIR] [--base BRANCH] [--check]
#   task_worktree.rb merge TASK_ID [--target DIR] [--check]
#
# The Owner sets `parallel_tasks: { TEAM: N }` in .ai_project/operating_model.md
# (the guard keeps agents from changing it). Teams with an Operator default to
# one running Task; other teams are not limited unless configured.

require "date"
require "fileutils"
require "json"
require "open3"
require "optparse"
require "yaml"

module TaskWorktree
  # Statuses that hold a running slot (and the Task's worktree).
  ACTIVE_STATUSES = %w[in_progress verification_ready verification_in_progress verification_passed completion_review rework_requested].freeze
  TEAM_WORKTREE_PREFIX = %r{\A\.worktrees/[^/]+/}.freeze

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

  def team_slug(team)
    slug = team.to_s.strip.downcase.gsub(/[^a-z0-9]+/, "-").gsub(/\A-|-\z/, "")
    slug.empty? ? "task" : slug
  end

  def agents(target)
    data = read_front_matter(File.join(target, ".ai_project", "agent_registry.md"))
    Array(data["agents"]).select { |agent| agent.is_a?(Hash) }
  end

  def operator_team?(target, team)
    key = team_key(team)
    !key.empty? && agents(target).any? do |agent|
      agent["status"] == "enabled" && Array(agent["roles"]).include?("Operator Role") && team_key(agent["team"]) == key
    end
  end

  # Configured limit for the team, 1 for an Operator team, otherwise nil (no limit).
  def parallel_limit(target, team)
    config = read_front_matter(File.join(target, ".ai_project", "operating_model.md"))["parallel_tasks"]
    if config.is_a?(Hash)
      config.each do |name, value|
        return value if team_key(name) == team_key(team) && value.is_a?(Integer) && value >= 1
      end
    end
    operator_team?(target, team) ? 1 : nil
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

  def active_team_tasks(target, team, except_id)
    key = team_key(team)
    task_files(target).map { |path| read_front_matter(path) }.select do |task|
      task["id"].to_s != except_id && team_key(task["team"]) == key && ACTIVE_STATUSES.include?(task["status"].to_s)
    end
  end

  def own_worktree?(task)
    task["worktree_role"].to_s == "active" && !task["worktree_path"].to_s.empty? && File.directory?(task["worktree_path"].to_s)
  end

  # Product paths of a Task relative to its repository: drops AI Ops records
  # and the `.worktrees/<name>/` prefix used to address a team worktree.
  def product_paths(task)
    Array(task["allowed_paths"]).map { |path| path.to_s.strip.sub(%r{\A\./}, "").sub(%r{/+\z}, "") }.reject(&:empty?).reject do |path|
      path.start_with?(".ai_project/", ".ai_knowledge/")
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

  # Checks run when a Task starts (approved -> in_progress). Returns nil or an error message.
  def start_problem(target, task)
    team = task["team"].to_s
    limit = parallel_limit(target, team)
    return nil unless limit

    others = active_team_tasks(target, team, task["id"].to_s)
    if others.length >= limit
      return "team #{team} already runs #{others.length} Task(s) (limit #{limit}): #{others.map { |other| other['id'] }.join(', ')}; " \
             "finish one first or ask the Owner to raise parallel_tasks"
    end
    return nil if limit == 1

    unless own_worktree?(task)
      return "parallel Tasks need their own worktree; run aiops worktree create #{task['id']} first"
    end
    shared = others.find { |other| File.expand_path(other["worktree_path"].to_s) == File.expand_path(task["worktree_path"].to_s) }
    return "#{task['id']} shares its worktree with #{shared['id']}; run aiops worktree create #{task['id']}" if shared

    mine = product_paths(task)
    others.each do |other|
      hit = overlap(mine, product_paths(other))
      return "allowed_paths overlap with running Task #{other['id']}: #{hit[0]} / #{hit[1]}; split the work so paths do not overlap" if hit
    end
    nil
  end

  # Directory and diff range for path checks of a Task that uses its own worktree.
  def change_source(task)
    role = task["worktree_role"].to_s
    path = task["worktree_path"].to_s
    return nil if path.empty? || !File.directory?(path)
    return { "dir" => path, "range" => nil } if role == "active"
    return { "dir" => path, "range" => [task["base_sha"].to_s, task["merged_sha"].to_s] } if role == "merged" && !task["merged_sha"].to_s.empty?

    nil
  end

  # --- Task front matter edits (line based, keeps the rest of the file) ---

  def set_fields(path, fields, branch: nil)
    text = File.read(path)
    match = text.match(/\A---\n(.*?\n)---\n/m)
    raise Error, "YAML front matter required: #{path}" unless match

    front = match[1]
    fields.each do |key, value|
      line = "#{key}: #{value.nil? ? 'null' : JSON.generate(value.to_s)}\n"
      if front.match?(/^#{Regexp.escape(key)}:.*\n/)
        front = front.sub(/^#{Regexp.escape(key)}:.*\n/) { line }
      else
        front += line
      end
    end
    if branch
      block = "branch:\n" + branch.map { |key, value| "  #{key}: #{value.nil? ? 'null' : JSON.generate(value.to_s)}\n" }.join
      if front.match?(/^branch:.*\n(?:[ \t]+.*\n)*/)
        front = front.sub(/^branch:.*\n(?:[ \t]+.*\n)*/) { block }
      else
        front += block
      end
    end
    File.write(path, "---\n#{front}---\n#{match.post_match}")
  end

  # --- git helpers ---

  def git(dir, *args)
    out, err, status = Open3.capture3("git", "-C", dir, *args)
    [out.strip, err.strip, status.success?]
  end

  def git!(dir, *args)
    out, err, ok = git(dir, *args)
    raise Error, "git #{args.join(' ')} failed: #{err.empty? ? out : err}" unless ok

    out
  end

  def toplevel(dir)
    return nil unless dir && File.directory?(dir)

    out, _err, ok = git(dir, "rev-parse", "--show-toplevel")
    ok && !out.empty? ? out : nil
  end

  def worktree_for_branch(dir, branch)
    current = nil
    git!(dir, "worktree", "list", "--porcelain").each_line do |line|
      line = line.chomp
      current = line.delete_prefix("worktree ") if line.start_with?("worktree ")
      return current if line == "branch refs/heads/#{branch}"
    end
    nil
  end

  class CLI
    def initialize(argv)
      @argv = argv.dup
      @action = @argv.shift
      @options = { target: Dir.pwd, repo: nil, base: nil, check: false }
    end

    def run
      case @action
      when "create" then create
      when "merge" then merge
      else
        warn "usage: aiops worktree create|merge TASK_ID [--target DIR]"
        1
      end
    rescue Error, OptionParser::ParseError => e
      warn "aiops worktree: #{e.message}"
      1
    end

    private

    def parse!
      remaining = OptionParser.new do |opts|
        opts.on("--target DIR") { |value| @options[:target] = value }
        opts.on("--repo DIR") { |value| @options[:repo] = value }
        opts.on("--base BRANCH") { |value| @options[:base] = value }
        opts.on("--check") { @options[:check] = true }
      end.parse(@argv)
      raise Error, "exactly one TASK_ID is required" unless remaining.length == 1

      @target = File.expand_path(@options[:target])
      @task_id = remaining.first
      @task_path = TaskWorktree.find_task(@target, @task_id)
      @task = TaskWorktree.read_front_matter(@task_path)
    end

    def branch_info
      @task["branch"].is_a?(Hash) ? @task["branch"] : {}
    end

    def create
      parse!
      team = @task["team"].to_s
      branch = "#{TaskWorktree.team_slug(team)}/#{@task_id}"
      path = File.join(@target, ".worktrees", "#{TaskWorktree.team_slug(team)}-#{@task_id}")
      if TaskWorktree.own_worktree?(@task) && branch_info["name"].to_s == branch
        puts "ok: #{@task_id} already has worktree #{@task['worktree_path']}"
        return 0
      end

      source = @options[:repo] || @task["worktree_path"].to_s
      source = @target if source.empty?
      repo = TaskWorktree.toplevel(File.expand_path(source, @target)) || raise(Error, "no git repository for #{@task_id}; use --repo DIR")
      base = @options[:base] || branch_info["name"].to_s
      base = TaskWorktree.git!(repo, "rev-parse", "--abbrev-ref", "HEAD") if base.empty? || base == branch
      base_sha = TaskWorktree.git!(repo, "rev-parse", "#{base}^{commit}")
      base_worktree = TaskWorktree.worktree_for_branch(repo, base) || repo
      raise Error, "#{path} already exists" if File.exist?(path)

      if @options[:check]
        puts "ready: #{@task_id} worktree #{path} on #{branch} from #{base} (#{base_sha[0, 9]})"
        return 0
      end
      FileUtils.mkdir_p(File.dirname(path))
      TaskWorktree.git!(repo, "worktree", "add", "-b", branch, path, base_sha)
      TaskWorktree.set_fields(@task_path,
                              { "worktree_path" => path, "worktree_role" => "active", "base_ref" => base, "base_sha" => base_sha },
                              branch: { "name" => branch, "base" => base, "base_worktree" => base_worktree })
      puts "created: #{path} (#{branch} from #{base} #{base_sha[0, 9]})"
      puts "Execution과 Verification은 이 폴더에서 작업하고, aiops 명령은 --target #{@target} 로 실행합니다."
      0
    end

    # Rebases the Task branch onto the team base branch, fast-forwards the base,
    # and removes the Task worktree. Conflicts stop without changing the base.
    def merge
      parse!
      raise Error, "#{@task_id} has no active Task worktree" unless TaskWorktree.own_worktree?(@task)

      path = @task["worktree_path"].to_s
      branch = branch_info["name"].to_s
      base = branch_info["base"].to_s
      raise Error, "#{@task_id} branch.name and branch.base are required" if branch.empty? || base.empty?

      dirty = TaskWorktree.git!(path, "status", "--porcelain")
      raise Error, "#{path} has uncommitted changes; commit the Task work first" unless dirty.empty?

      ahead = TaskWorktree.git!(path, "rev-list", "--count", "#{base}..HEAD").to_i
      if @options[:check]
        puts "ready: merge #{ahead} commit(s) of #{branch} into #{base}"
        return 0
      end

      _out, err, ok = TaskWorktree.git(path, "rebase", base)
      unless ok
        TaskWorktree.git(path, "rebase", "--abort")
        raise Error, "rebase onto #{base} hit conflicts; nothing was merged. Resolve in #{path} or ask the Lead: #{err.lines.last.to_s.strip}"
      end
      new_base_sha = TaskWorktree.git!(path, "rev-parse", "#{base}^{commit}")
      merged_sha = TaskWorktree.git!(path, "rev-parse", "HEAD")
      base_worktree = TaskWorktree.worktree_for_branch(path, base)
      if base_worktree
        TaskWorktree.git!(base_worktree, "merge", "--ff-only", branch)
      else
        TaskWorktree.git!(path, "update-ref", "refs/heads/#{base}", merged_sha, new_base_sha)
      end
      record_dir = base_worktree || branch_info["base_worktree"].to_s
      record_dir = TaskWorktree.git!(path, "rev-parse", "--path-format=absolute", "--git-common-dir").sub(%r{/\.git\z}, "") if record_dir.empty?
      TaskWorktree.git!(record_dir, "worktree", "remove", path)
      TaskWorktree.git(record_dir, "branch", "-D", branch)
      TaskWorktree.set_fields(@task_path,
                              { "worktree_path" => record_dir, "worktree_role" => "merged", "base_sha" => new_base_sha, "merged_sha" => merged_sha })
      puts "merged: #{ahead} commit(s) of #{branch} into #{base} (#{merged_sha[0, 9]}); removed #{path}"
      0
    end
  end
end

exit TaskWorktree::CLI.new(ARGV).run if $PROGRAM_NAME == __FILE__

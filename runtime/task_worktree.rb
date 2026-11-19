#!/usr/bin/env ruby
# frozen_string_literal: true

# Parallel Tasks: per-team limits, one git worktree per running Task, and
# merging a finished Task branch back into the team base branch.
#
#   task_worktree.rb create TASK_ID [--target DIR] [--repo DIR] [--base BRANCH] [--check]
#   task_worktree.rb merge TASK_ID [--target DIR] [--check]
#   task_worktree.rb checks [TASK_ID] [--target DIR] [--dir DIR]
#
# Project checks are the Owner's own tests kept outside the product
# repository in .ai_project/checks/ (entry point run.sh), so every worktree
# shares one copy and other developers' test suites are not touched.
#
# The Owner sets `parallel_tasks: { TEAM: N }` in .ai_project/operating_model.md
# (the guard keeps agents from changing it). Teams with an Operator default to
# one running Task; other teams are not limited unless configured.
#
# The Owner can also set `merge_check` (a shell command, or `{ default: CMD,
# TEAM: CMD }`) and `merge_check_timeout_minutes`. `merge` runs it in the
# rebased Task worktree, which holds exactly what the base branch becomes,
# and leaves the base branch untouched when it fails.

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

  DEFAULT_MERGE_CHECK_TIMEOUT_MINUTES = 60

  def operating_model(target)
    read_front_matter(File.join(target, ".ai_project", "operating_model.md"))
  end

  # Build/test command for the team after its Tasks are combined, or nil.
  # A team entry with an empty value turns the default off for that team.
  def merge_check_command(target, team)
    config = operating_model(target)["merge_check"]
    command =
      case config
      when String then config
      when Hash
        hit = config.find { |name, _value| name.to_s != "default" && team_key(name) == team_key(team) }
        hit ? hit[1] : config["default"]
      end
    command = command.to_s.strip
    command.empty? ? nil : command
  end

  def merge_check_timeout_minutes(target)
    value = operating_model(target)["merge_check_timeout_minutes"]
    value.is_a?(Integer) && value >= 1 ? value : DEFAULT_MERGE_CHECK_TIMEOUT_MINUTES
  end

  # Runs COMMAND with sh in DIR, writing output to LOG_PATH.
  # Returns [passed, detail].
  def run_merge_check(dir, command, timeout_minutes, log_path, env = {})
    FileUtils.mkdir_p(File.dirname(log_path))
    File.open(log_path, "w") do |log|
      log.puts "$ #{command}"
      log.puts "# dir: #{dir}"
      log.flush
      pid = Process.spawn(env, "sh", "-c", command, chdir: dir, in: File::NULL, out: log, err: log, pgroup: true)
      deadline = Time.now + (timeout_minutes * 60)
      loop do
        _pid, status = Process.wait2(pid, Process::WNOHANG)
        if status
          log.puts "# exit: #{status.exitstatus.inspect}"
          return [status.success?, status.success? ? "passed" : "exit #{status.exitstatus || status.termsig}"]
        end
        if Time.now >= deadline
          stop_group(pid)
          log.puts "# timeout after #{timeout_minutes} minute(s)"
          return [false, "timed out after #{timeout_minutes} minute(s)"]
        end
        sleep 0.5
      end
    end
  end

  def stop_group(pid)
    Process.kill("TERM", -pid)
    20.times do
      return if Process.wait(pid, Process::WNOHANG)

      sleep 0.25
    end
    Process.kill("KILL", -pid)
    Process.wait(pid)
  rescue Errno::ESRCH, Errno::ECHILD
    nil
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

  CHECKS_DIR = ".ai_project/checks"

  # Paths two running Tasks must not share: product paths relative to the
  # repository (the `.worktrees/<name>/` prefix is dropped) and the shared
  # project checks. Other AI Ops records are left out.
  def product_paths(task)
    Array(task["allowed_paths"]).map { |path| path.to_s.strip.sub(%r{\A\./}, "").sub(%r{/+\z}, "") }.reject(&:empty?).reject do |path|
      (path.start_with?(".ai_project/", ".ai_knowledge/") || path == ".ai_project") && !(path == CHECKS_DIR || path.start_with?("#{CHECKS_DIR}/"))
    end.map { |path| path.sub(TEAM_WORKTREE_PREFIX, "") }.uniq
  end

  def checks_env(target, dir, task_id)
    env = { "AIOPS_PROJECT_ROOT" => target, "AIOPS_CHECKS_DIR" => File.join(target, CHECKS_DIR), "AIOPS_WORKTREE" => dir }
    env["AIOPS_TASK_ID"] = task_id if task_id
    env
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
      when "checks" then checks
      else
        warn "usage: aiops worktree create|merge TASK_ID [--target DIR] | aiops worktree checks [TASK_ID] [--dir DIR]"
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

    # Runs the project checks (.ai_project/checks/run.sh) against a working
    # folder: --dir, else the Task's active worktree, else the current folder.
    def checks
      dir = nil
      remaining = OptionParser.new do |opts|
        opts.on("--target DIR") { |value| @options[:target] = value }
        opts.on("--dir DIR") { |value| dir = value }
      end.parse(@argv)
      raise Error, "at most one TASK_ID is allowed" if remaining.length > 1

      @target = File.expand_path(@options[:target])
      task_id = remaining.first
      if task_id
        task = TaskWorktree.read_front_matter(TaskWorktree.find_task(@target, task_id))
        dir ||= task["worktree_path"].to_s if TaskWorktree.own_worktree?(task)
      end
      dir = File.expand_path(dir || Dir.pwd)
      raise Error, "#{dir} is not a directory" unless File.directory?(dir)

      script = File.join(@target, TaskWorktree::CHECKS_DIR, "run.sh")
      raise Error, "#{TaskWorktree::CHECKS_DIR}/run.sh not found; project checks are not set up" unless File.file?(script)

      env = TaskWorktree.checks_env(@target, dir, task_id)
      puts "checks: #{TaskWorktree::CHECKS_DIR}/run.sh in #{dir}"
      ok = system(env, "sh", script, chdir: dir)
      puts(ok ? "checks passed" : "checks failed")
      ok ? 0 : 1
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
      merge_check = TaskWorktree.merge_check_command(@target, @task["team"].to_s)
      if @options[:check]
        puts "ready: merge #{ahead} commit(s) of #{branch} into #{base}"
        puts(merge_check ? "merge check: #{merge_check}" : "merge check: not configured (operating_model merge_check)")
        return 0
      end

      _out, err, ok = TaskWorktree.git(path, "rebase", base)
      unless ok
        TaskWorktree.git(path, "rebase", "--abort")
        raise Error, "rebase onto #{base} hit conflicts; nothing was merged. Resolve in #{path} or ask the Lead: #{err.lines.last.to_s.strip}"
      end
      new_base_sha = TaskWorktree.git!(path, "rev-parse", "#{base}^{commit}")
      merged_sha = TaskWorktree.git!(path, "rev-parse", "HEAD")
      run_merge_check(merge_check, path, base, merged_sha) if merge_check
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

    # Builds and tests the rebased Task branch (base + this Task) before the
    # base moves. Failure leaves the base branch as it was.
    def run_merge_check(command, path, base, merged_sha)
      timeout = TaskWorktree.merge_check_timeout_minutes(@target)
      log_rel = File.join(".ai_project", "reports", "#{@task_id}_merge-check.log")
      puts "merge check: #{command} (in #{path}, timeout #{timeout}m)"
      env = TaskWorktree.checks_env(@target, path, @task_id).merge("AIOPS_BASE_BRANCH" => base)
      passed, detail = TaskWorktree.run_merge_check(path, command, timeout, File.join(@target, log_rel), env)
      TaskWorktree.set_fields(@task_path, { "merge_check" => passed ? "passed" : "failed", "merge_check_sha" => merged_sha,
                                            "merge_check_log" => log_rel })
      return puts("merge check passed: log #{log_rel}") if passed

      raise Error, "merge check failed (#{detail}); #{base} was not changed. #{path} is now rebased onto #{base}: " \
                   "fix the combined result there, commit, and run aiops worktree merge #{@task_id} again. Log: #{log_rel}"
    end
  end
end

exit TaskWorktree::CLI.new(ARGV).run if $PROGRAM_NAME == __FILE__

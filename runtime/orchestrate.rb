#!/usr/bin/env ruby
# frozen_string_literal: true

# Read-only planner for Operator-driven single-session workflow runs.
#
#   orchestrate.rb plan TASK_ID [--target DIR] [--operator AGENT] [--json]
#   orchestrate.rb next --operator AGENT [--target DIR] [--json]
#   orchestrate.rb approve [TASK_ID|SUFFIX] [--all] [--target DIR]   (Owner only; `aiops approve`)
#
# The plan tells the Operator session which Role Agent (subagent) acts next,
# which aiops command records the transition, and when to stop for the Owner.
# It never writes files; every transition still goes through
# `aiops task accept|advance` and the lifecycle engine's checks.

require "date"
require "json"
require "open3"
require "optparse"
require "yaml"
require_relative "task_worktree"

class OrchestrationError < StandardError; end

class OrchestrationPlan
  SCHEMA = "aiops.orchestration_plan.v1"
  CONSENT_MARKER = "aiops:operated-session-consent"
  DEFAULT_REWORK_LIMIT = 1
  SUBAGENTS = {
    "Direction Role" => "aiops-direction",
    "Lead Role" => "aiops-lead",
    "Execution Role" => "aiops-execution",
    "Verification Role" => "aiops-verification",
    "Completion Role" => "aiops-completion"
  }.freeze
  # status => [command, kind]; kind "gate" can be pre-checked, "work" needs the Role Agent to finish work first.
  STEPS = {
    "proposed" => %w[advance gate],
    "scoped" => %w[advance gate],
    "rework_requested" => %w[advance gate],
    "approved" => %w[accept gate],
    "in_progress" => %w[advance work],
    "verification_ready" => %w[accept gate],
    "verification_in_progress" => %w[advance work],
    "verification_passed" => %w[accept gate],
    "completion_review" => %w[advance gate]
  }.freeze
  WORK = {
    "proposed" => "작업 범위와 의존성을 정리해 scoped로 넘긴다",
    "scoped" => "Owner 승인을 받은 뒤 일감을 승인(approved)한다",
    "rework_requested" => "검증 실패 원인과 재작업 범위를 정리해 다시 넘긴다",
    "approved" => "Execution Agent가 작업을 수락한다",
    "in_progress" => "allowed_paths 안에서 구현하고 자체 확인 후 작업 보고서를 쓴다",
    "verification_ready" => "Verification Agent가 검증을 수락한다",
    "verification_in_progress" => "Task, diff, 작업 보고서만 근거로 독립 검증하고 판정한다",
    "verification_passed" => "Completion Agent가 완료 검토를 수락한다",
    "completion_review" => "완료 조건과 잔여 위험을 확인하고 done으로 닫는다"
  }.freeze

  def initialize(argv)
    @argv = argv.dup
    @action = @argv.shift
    @options = { target: Dir.pwd, operator: nil, json: false }
  end

  def run
    return OwnerApproval.new(@argv).run if @action == "approve"
    return TeamPlan.new(@argv).run if @action == "next"
    raise OrchestrationError, "usage: aiops orchestrate plan TASK_ID [--target DIR] [--operator AGENT] [--json]" unless @action == "plan"

    parse!
    plan = build
    @options[:json] ? puts(JSON.pretty_generate(plan)) : render(plan)
    0
  rescue OrchestrationError, OptionParser::ParseError => e
    warn "aiops orchestrate: #{e.message}"
    1
  end

  # Plan for one Task without printing it (used by OwnerApproval).
  def plan_data
    parse!
    build
  end

  private

  def parse!
    remaining = OptionParser.new do |opts|
      opts.on("--target DIR") { |value| @options[:target] = value }
      opts.on("--operator AGENT") { |value| @options[:operator] = value }
      opts.on("--json") { @options[:json] = true }
    end.parse(@argv)
    raise OrchestrationError, "orchestrate plan requires exactly one TASK_ID" unless remaining.length == 1

    @task_id = remaining.first
    @target = File.expand_path(@options[:target])
  end

  def front_matter(path)
    text = File.read(path)
    match = text.match(/\A---\n(.*?)\n---\n(.*)\z/m)
    raise OrchestrationError, "#{path} has no YAML front matter" unless match

    [YAML.safe_load(match[1], permitted_classes: [Date, Time], aliases: true) || {}, match[2]]
  end

  def load_task
    candidates = Dir.glob(File.join(@target, ".ai_project", "tasks", "**", "#{@task_id}*.md")).sort
    raise OrchestrationError, "task not found: #{@task_id}" if candidates.empty?
    raise OrchestrationError, "multiple Task files found for #{@task_id}" if candidates.length > 1

    @task, @body = front_matter(candidates.first)
  end

  def load_agents
    path = File.join(@target, ".ai_project", "agent_registry.md")
    raise OrchestrationError, ".ai_project/agent_registry.md is required" unless File.file?(path)

    data, = front_matter(path)
    @agents = Array(data["agents"]).select { |agent| agent.is_a?(Hash) }
  end

  def find_agent(name)
    @agents.find { |agent| agent["agent"] == name || agent["id"] == name || Array(agent["aliases"]).include?(name) }
  end

  def operator
    name = @options[:operator]
    return nil if name.to_s.empty?

    agent = find_agent(name)
    raise OrchestrationError, "operator is not registered: #{name}" unless agent
    raise OrchestrationError, "#{name} does not have Operator Role" unless Array(agent["roles"]).include?("Operator Role")
    raise OrchestrationError, "operator is not enabled: #{name}" unless agent["status"] == "enabled"

    agent
  end

  # Same rules as the lifecycle engine: approval and limits come from receipts.
  def task_receipts
    @task_receipts ||= Dir.glob(File.join(@target, ".ai_project", "reports", "#{@task_id}_*-transition-receipt.json")).sort.map do |path|
      data = JSON.parse(File.read(path))
      data.is_a?(Hash) && data["task_id"] == @task_id ? data : nil
    rescue JSON::ParserError, SystemCallError
      nil
    end.compact
  end

  def owner_approved?
    task_receipts.any? { |receipt| receipt["owner_approved"] == true && receipt.dig("transition", "to") == "approved" }
  end

  def rework_count
    logged = @body.scan(/->\s*rework_requested\s*\|/).length
    recorded = task_receipts.count { |receipt| receipt.dig("transition", "from") == "rework_requested" }
    [logged, recorded].max
  end

  def rework_limit
    limits = task_receipts.select { |receipt| receipt["owner_approved"] == true }.map { |receipt| receipt["rework_limit"] }
    ([DEFAULT_REWORK_LIMIT] + limits.select { |value| value.is_a?(Integer) && value >= 0 }).max
  end

  def operator_agents
    @agents.select { |agent| agent["status"] == "enabled" && Array(agent["roles"]).include?("Operator Role") }
  end

  def operator_in_team?(team)
    name = team.to_s.strip.downcase
    !name.empty? && operator_agents.any? { |agent| agent["team"].to_s.strip.downcase == name }
  end

  # Mirrors TaskLifecycle#owner_approval_scope? for the planner.
  def owner_approval_scope?
    return true if @operator_name

    operators = operator_agents
    return false if operators.empty?
    return true if @task["team"].to_s.strip.empty?
    return true if operators.any? { |agent| agent["team"].to_s.strip.empty? }

    operator_in_team?(@task["team"])
  end

  def consent_recorded?
    path = File.join(@target, ".ai_project", "ops_decisions.md")
    File.file?(path) && File.read(path).include?(CONSENT_MARKER)
  end

  def aiops_bin
    File.expand_path("../bin/aiops", __dir__)
  end

  def base_argv(command)
    argv = ["aiops", "task", command, @task_id]
    argv += ["--dispatched-by", @operator_name] if @operator_name
    argv
  end

  def owner_approval_needed?
    # Only the scoped -> approved transition enters approved on the automatic path.
    return false unless @status == "scoped"
    return false unless owner_approval_scope?
    return true unless owner_approved?

    rework_count > rework_limit
  end

  def precheck(argv)
    command = [aiops_bin, *argv[1..-1], "--target", @target, "--check", "--json"]
    out, err, status = Open3.capture3(*command)
    return { "ready" => true } if status.success?

    message = err.strip.empty? ? out.strip : err.strip
    { "ready" => false, "error" => message.lines.last.to_s.strip }
  end

  def build
    load_task
    load_agents
    op = operator
    @operator_name = op && op["agent"]
    @status = @task["status"].to_s
    role = @task["target_role"].to_s
    plan = {
      "schema" => SCHEMA,
      "task_id" => @task_id,
      "title" => @task["title"].to_s,
      "status" => @status,
      "operator" => @operator_name,
      "consent_recorded" => consent_recorded?,
      "rework" => { "count" => rework_count, "limit" => rework_limit },
      "state" => nil,
      "reason" => nil,
      "next" => nil
    }

    case @status
    when "done", "cancelled"
      return plan.merge("state" => "done", "reason" => "Task is #{@status}")
    when "blocked"
      return plan.merge("state" => "stopped", "reason" => "Task is blocked; report the blocker to the Owner and let the Lead Agent resolve it")
    end
    step = STEPS[@status]
    return plan.merge("state" => "stopped", "reason" => "no orchestration step for status #{@status}") unless step

    if @operator_name && !plan["consent_recorded"]
      plan["state"] = "needs_owner"
      plan["reason"] = "first operated session: ask the Owner how to proceed (commit scope, rework limit) and record #{CONSENT_MARKER} in .ai_project/ops_decisions.md"
    end

    command, kind = step
    argv = base_argv(command)
    next_step = {
      "command" => command,
      "kind" => kind,
      "role" => role,
      "agent" => @task["target_agent"].to_s,
      "subagent" => SUBAGENTS[role],
      "work" => WORK[@status],
      "argv" => argv,
      "requires_owner_approval" => owner_approval_needed?
    }
    if next_step["requires_owner_approval"]
      next_step["argv"] = argv + ["--owner-approved"]
      next_step["owner_command"] = ["aiops", "approve", OwnerApproval.short_id(@task_id, task_ids)]
      if plan["state"].nil?
        plan["state"] = "needs_owner"
        plan["reason"] = if owner_approved?
                           "rework limit #{rework_limit} reached (#{rework_count} reworks); the Owner decides whether to continue and runs next.argv"
                         else
                           "Owner approval of the work scope and Task is required before approved; the Owner runs next.argv"
                         end
      end
    end
    if @status == "approved" && (TaskWorktree.parallel_limit(@target, @task["team"]) || 1) > 1 && !TaskWorktree.own_worktree?(@task)
      next_step["prepare"] = ["aiops", "worktree", "create", @task_id]
    elsif @status == "completion_review" && TaskWorktree.own_worktree?(@task)
      next_step["prepare"] = ["aiops", "worktree", "merge", @task_id]
    end
    if @status == "verification_in_progress"
      next_step["on_pass"] = argv + ["--evidence", @task["qa_to"].to_s].reject(&:empty?)
      next_step["on_fail"] = ["aiops", "task", "transition", @task_id, "--to", "rework_requested", "--role", "Verification Role"]
      next_step["on_fail"] += ["--by", @task["target_agent"].to_s] unless @task["target_agent"].to_s.empty?
      next_step["on_fail"] += ["--reason", "<검증 실패 이유>"]
    elsif @status == "in_progress"
      next_step["argv"] = argv + ["--evidence", @task["report_to"].to_s].reject(&:empty?)
    end
    if next_step["prepare"] && plan["state"].nil?
      plan["state"] = "ready"
      plan["reason"] = "run next.prepare first, then next.argv"
    end
    if kind == "gate" && plan["state"].nil?
      next_step["check"] = precheck(next_step["argv"])
      unless next_step["check"]["ready"]
        plan["state"] = "stopped"
        plan["reason"] = next_step["check"]["error"]
      end
    end
    plan["state"] ||= kind == "work" ? "work_required" : "ready"
    plan["reason"] ||= kind == "work" ? "#{next_step['subagent'] || role} must finish the work before the transition" : "next transition is ready"
    plan["next"] = next_step
    plan
  end

  def render(plan)
    puts "AI Ops orchestrate plan"
    puts "Task: #{plan['task_id']} #{plan['title']}"
    puts "상태: #{plan['status']}"
    puts "진행: #{plan['state']} - #{plan['reason']}"
    puts "재작업: #{plan['rework']['count']} / 허용 #{plan['rework']['limit']}"
    step = plan["next"]
    return unless step

    puts "다음 담당: #{step['agent']} / #{step['role']} (subagent: #{step['subagent'] || '없음'})"
    puts "할 일: #{step['work']}"
    puts "준비: #{shell_line(step['prepare'])}" if step["prepare"]
    puts "명령: #{shell_line(step['argv'])}"
    puts "통과 시: #{shell_line(step['on_pass'])}" if step["on_pass"]
    puts "실패 시: #{shell_line(step['on_fail'])}" if step["on_fail"]
    return unless step["requires_owner_approval"]

    short = step["owner_command"].join(" ")
    puts "Owner 승인 필요: Owner(사용자)가 직접 `#{short}` 를 실행합니다 (Claude Code 대화창에서는 `! #{short}`)"
  end

  # Quotes arguments with spaces as "..." so the line can be copied into a shell.
  def shell_line(argv)
    argv.map do |arg|
      arg.match?(%r{\A[\w./:=@%+,-]+\z}) ? arg : "\"#{arg.gsub(/(["\\$`])/) { "\\#{Regexp.last_match(1)}" }}\""
    end.join(" ")
  end

  def task_ids
    Dir.glob(File.join(@target, ".ai_project", "tasks", "**", "T-*.md")).map { |path| File.basename(path, ".md")[/\AT-\d{8}-\d{3,}/] }.compact.uniq
  end
end

# `aiops orchestrate next`: every open Task of the Operator's team with its
# next step, plus the team's running-Task limit, so one session can run
# several Tasks in parallel (each in its own worktree) without exceeding it.
class TeamPlan
  SCHEMA = "aiops.orchestration_batch.v1"

  def initialize(argv)
    @argv = argv.dup
    @options = { target: Dir.pwd, operator: nil, json: false }
  end

  def run
    OptionParser.new do |opts|
      opts.on("--target DIR") { |value| @options[:target] = value }
      opts.on("--operator AGENT") { |value| @options[:operator] = value }
      opts.on("--json") { @options[:json] = true }
    end.parse!(@argv)
    raise OrchestrationError, "orchestrate next requires --operator AGENT" if @options[:operator].to_s.empty?

    batch = build
    @options[:json] ? puts(JSON.pretty_generate(batch)) : render(batch)
    0
  rescue OrchestrationError, OptionParser::ParseError, TaskWorktree::Error => e
    warn "aiops orchestrate: #{e.message}"
    1
  end

  private

  def build
    target = File.expand_path(@options[:target])
    operator = TaskWorktree.agents(target).find do |agent|
      [agent["agent"], agent["id"], *Array(agent["aliases"])].map(&:to_s).include?(@options[:operator])
    end
    raise OrchestrationError, "operator is not registered: #{@options[:operator]}" unless operator

    team = operator["team"].to_s
    tasks = TaskWorktree.task_files(target).map { |path| TaskWorktree.read_front_matter(path) }.select do |task|
      TaskWorktree.team_key(task["team"]) == TaskWorktree.team_key(team) && !%w[done cancelled].include?(task["status"].to_s) &&
        task["id"].to_s.match?(/\AT-\d{8}-\d{3,}\z/)
    end
    limit = TaskWorktree.parallel_limit(target, team)
    running = tasks.count { |task| TaskWorktree::ACTIVE_STATUSES.include?(task["status"].to_s) }
    slots = limit ? [limit - running, 0].max : nil
    plans = tasks.map do |task|
      OrchestrationPlan.new(["plan", task["id"], "--target", target, "--operator", operator["agent"].to_s]).plan_data
    end
    start_now = plans.select { |plan| plan["status"] == "approved" }.map { |plan| plan["task_id"] }
    start_now = start_now.first(slots) if slots
    {
      "schema" => SCHEMA,
      "operator" => operator["agent"].to_s,
      "team" => team,
      "parallel_limit" => limit,
      "running" => running,
      "start_now" => start_now,
      "tasks" => plans
    }
  end

  def render(batch)
    puts "AI Ops orchestrate next"
    puts "Operator: #{batch['operator']} / 팀: #{batch['team']}"
    puts "동시 진행: #{batch['running']} / 한도 #{batch['parallel_limit'] || '없음'}"
    puts "지금 시작할 Task: #{batch['start_now'].empty? ? '없음' : batch['start_now'].join(', ')}"
    batch["tasks"].each do |plan|
      step = plan["next"] || {}
      puts "- #{plan['task_id']} [#{plan['status']}] #{plan['state']}: #{plan['reason']}"
      puts "    다음: #{step['agent']} / #{step['role']} (subagent: #{step['subagent'] || '없음'})" unless step.empty?
    end
  end
end

# `aiops approve`: the Owner's short command for Task approval. It finds the
# Task waiting for Owner approval (by full ID, an ID suffix such as 007, or the
# only waiting Task), fills in --target and the team's Operator, and runs
# `aiops task advance ... --owner-approved`. Agents cannot run it (guard).
class OwnerApproval
  def self.short_id(task_id, all_ids)
    suffix = task_id[/-(\d{3,})\z/, 1]
    return task_id unless suffix

    matches = all_ids.count { |id| id.end_with?("-#{suffix}") }
    matches == 1 ? suffix : task_id
  end

  def initialize(argv)
    @argv = argv.dup
    @target = nil
  end

  def run
    parse!
    tasks = load_tasks
    raise OrchestrationError, "Task가 없습니다: #{relative_tasks_dir}" if tasks.empty?

    return approve_all(tasks) if @all

    chosen = @query ? find(tasks) : only_pending(tasks)
    return 0 unless chosen

    approve(chosen)
  rescue OrchestrationError, OptionParser::ParseError => e
    warn "aiops approve: #{e.message}"
    1
  end

  private

  def parse!
    remaining = OptionParser.new do |opts|
      opts.banner = "usage: aiops approve [TASK_ID|SUFFIX] [--all] [--target DIR]"
      opts.on("--target DIR") { |value| @target = File.expand_path(value) }
      opts.on("--all") { @all = true }
    end.parse(@argv)
    raise OrchestrationError, "Task는 하나만 지정하세요" if remaining.length > 1
    raise OrchestrationError, "--all 과 Task ID는 함께 쓸 수 없습니다" if @all && !remaining.empty?

    @query = remaining.first
    @target ||= find_root(Dir.pwd)
  end

  def find_root(dir)
    current = File.expand_path(dir)
    loop do
      return current if File.directory?(File.join(current, ".ai_project"))

      parent = File.dirname(current)
      raise OrchestrationError, "AI Ops 프로젝트(.ai_project)를 찾을 수 없습니다. 프로젝트 폴더에서 실행하거나 --target 을 주세요." if parent == current

      current = parent
    end
  end

  def relative_tasks_dir
    File.join(@target, ".ai_project", "tasks")
  end

  def registry_agents
    path = File.join(@target, ".ai_project", "agent_registry.md")
    return [] unless File.file?(path)

    match = File.read(path).match(/\A---\n(.*?)\n---\n/m)
    data = match ? YAML.safe_load(match[1], permitted_classes: [Date, Time], aliases: true) : {}
    Array(data && data["agents"]).select { |agent| agent.is_a?(Hash) }
  end

  def load_tasks
    paths = Dir.glob(File.join(relative_tasks_dir, "**", "T-*.md")).reject { |path| path.include?("/archive/") }.sort
    paths.map do |path|
      match = File.read(path).match(/\A---\n(.*?)\n---\n/m)
      next nil unless match

      data = YAML.safe_load(match[1], permitted_classes: [Date, Time], aliases: true) || {}
      data.is_a?(Hash) && data["id"].to_s.match?(/\AT-\d{8}-\d{3,}\z/) ? data : nil
    end.compact
  end

  # The Operator of the Task's team, else the only Operator without a team.
  def operator_for(task)
    team = task["team"].to_s.strip.downcase
    operators = registry_agents.select { |agent| agent["status"] == "enabled" && Array(agent["roles"]).include?("Operator Role") }
    same_team = team.empty? ? [] : operators.select { |agent| agent["team"].to_s.strip.downcase == team }
    candidates = same_team.empty? ? operators.select { |agent| agent["team"].to_s.strip.empty? } : same_team
    candidates.length == 1 ? candidates.first["agent"].to_s : nil
  end

  def plan_for(task)
    argv = ["plan", task["id"], "--target", @target]
    operator = operator_for(task)
    argv += ["--operator", operator] if operator
    OrchestrationPlan.new(argv).plan_data
  end

  def pending(tasks)
    tasks.select { |task| task["status"] == "scoped" }.map do |task|
      plan = plan_for(task)
      plan["next"] && plan["next"]["requires_owner_approval"] ? [task, plan] : nil
    end.compact
  end

  def only_pending(tasks)
    waiting = pending(tasks)
    if waiting.empty?
      puts "Owner 승인을 기다리는 Task가 없습니다."
      return nil
    end
    return waiting.first if waiting.length == 1

    ids = tasks.map { |task| task["id"] }
    puts "Owner 승인을 기다리는 Task가 여러 개입니다. 하나를 골라 실행하세요:"
    waiting.each do |task, _plan|
      puts "  aiops approve #{self.class.short_id(task['id'], ids)}   # #{task['team']} / #{task['title']}"
    end
    puts "  aiops approve --all   # 모두 승인"
    raise OrchestrationError, "승인할 Task를 지정하세요"
  end

  def find(tasks)
    matches = tasks.select { |task| task["id"] == @query || task["id"].end_with?("-#{@query.sub(/\A-/, '')}") }
    raise OrchestrationError, "Task를 찾을 수 없습니다: #{@query}" if matches.empty?
    if matches.length > 1
      raise OrchestrationError, "#{@query} 에 맞는 Task가 여러 개입니다: #{matches.map { |task| task['id'] }.join(', ')}. 전체 ID를 쓰세요."
    end

    task = matches.first
    unless task["status"] == "scoped"
      raise OrchestrationError, "#{task['id']} 는 승인 단계가 아닙니다 (status: #{task['status']})"
    end

    [task, plan_for(task)]
  end

  # Approves every Task waiting for the Owner, one by one; stops at the first failure.
  def approve_all(tasks)
    waiting = pending(tasks)
    if waiting.empty?
      puts "Owner 승인을 기다리는 Task가 없습니다."
      return 0
    end
    puts "Owner 승인 #{waiting.length}건을 차례로 진행합니다."
    waiting.each_with_index do |pair, index|
      puts "" if index.positive?
      status = approve(pair)
      return status unless status.zero?
    end
    0
  end

  def approve(chosen)
    task, plan = chosen
    step = plan["next"] || {}
    argv = Array(step["argv"]).dup
    raise OrchestrationError, "#{task['id']} 의 승인 명령을 만들 수 없습니다: #{plan['reason']}" unless argv[0, 3] == %w[aiops task advance]

    argv << "--owner-approved" unless argv.include?("--owner-approved")
    puts "Owner 승인: #{task['id']} #{task['title']}"
    puts "  팀: #{task['team']}" unless task["team"].to_s.empty?
    puts "  담당: #{task['target_agent']} / #{task['target_role']}"
    paths = Array(task["allowed_paths"])
    puts "  작업 범위: #{paths.join(', ')}" unless paths.empty?
    puts "  Operator: #{plan['operator']}" if plan["operator"]
    puts ""
    aiops = File.expand_path("../bin/aiops", __dir__)
    system(aiops, *argv[1..-1], "--target", @target) ? 0 : 1
  end
end

exit OrchestrationPlan.new(ARGV).run if $PROGRAM_NAME == __FILE__

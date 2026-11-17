#!/usr/bin/env ruby
# frozen_string_literal: true

# Read-only planner for Operator-driven single-session workflow runs.
#
#   orchestrate.rb plan TASK_ID [--target DIR] [--operator AGENT] [--json]
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
    raise OrchestrationError, "usage: aiops orchestrate plan TASK_ID [--target DIR] [--operator AGENT] [--json]" unless @action == "plan"

    parse!
    plan = build
    @options[:json] ? puts(JSON.pretty_generate(plan)) : render(plan)
    0
  rescue OrchestrationError, OptionParser::ParseError => e
    warn "aiops orchestrate: #{e.message}"
    1
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

  def operator_registered?
    @agents.any? { |agent| agent["status"] == "enabled" && Array(agent["roles"]).include?("Operator Role") }
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
    return false unless @operator_name || operator_registered?
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
      if plan["state"].nil?
        plan["state"] = "needs_owner"
        plan["reason"] = if owner_approved?
                           "rework limit #{rework_limit} reached (#{rework_count} reworks); the Owner decides whether to continue and runs next.argv"
                         else
                           "Owner approval of the work scope and Task is required before approved; the Owner runs next.argv"
                         end
      end
    end
    if @status == "verification_in_progress"
      next_step["on_pass"] = argv + ["--evidence", @task["qa_to"].to_s].reject(&:empty?)
      next_step["on_fail"] = ["aiops", "task", "transition", @task_id, "--to", "rework_requested", "--role", "Verification Role"]
      next_step["on_fail"] += ["--by", @task["target_agent"].to_s] unless @task["target_agent"].to_s.empty?
      next_step["on_fail"] += ["--reason", "<검증 실패 이유>"]
    elsif @status == "in_progress"
      next_step["argv"] = argv + ["--evidence", @task["report_to"].to_s].reject(&:empty?)
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
    puts "명령: #{step['argv'].join(' ')}"
    puts "통과 시: #{step['on_pass'].join(' ')}" if step["on_pass"]
    puts "실패 시: #{step['on_fail'].join(' ')}" if step["on_fail"]
    puts "Owner 승인 필요: 위 명령은 Owner(사용자)가 직접 실행합니다" if step["requires_owner_approval"]
  end
end

exit OrchestrationPlan.new(ARGV).run if $PROGRAM_NAME == __FILE__

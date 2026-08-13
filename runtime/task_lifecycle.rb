#!/usr/bin/env ruby
# frozen_string_literal: true

require "date"
require "digest"
require "fileutils"
require "json"
require "open3"
require "optparse"
require "pathname"
require "tempfile"
require "tmpdir"
require "yaml"
require_relative "task_risk_profile"

class LifecycleError < StandardError; end

class TaskLifecycle
  HAPPY_PATH = {
    "proposed" => "scoped",
    "scoped" => "approved",
    "approved" => "in_progress",
    "in_progress" => "verification_ready",
    "verification_ready" => "verification_in_progress",
    "verification_in_progress" => "verification_passed",
    "verification_passed" => "completion_review",
    "completion_review" => "done",
    "rework_requested" => "scoped"
  }.freeze

  ACCEPT_FROM = %w[approved verification_ready verification_passed].freeze
  ROLE_CAPABILITY = {
    "Direction Role" => /direction|priority|approval|scope/,
    "Lead Role" => /planning|scope|dependency|coordination|lead/,
    "Execution Role" => /implementation|development|refactor|documentation|design|research|test/,
    "Verification Role" => /qa|review|test|verification|validation|check/,
    "Completion Role" => /completion|merge|approval|parent_task|child_completion/,
    "Release Role" => /release|deploy|distribution/,
    "Ops Governance Role" => /ops|governance|migration|audit/
  }.freeze

  def initialize(command, argv)
    @command = command
    @options = {
      target: Dir.pwd,
      check: false,
      json: false,
      evidence: [],
      risks: [],
      blockers: []
    }
    parse_options!(argv)
    @target = File.expand_path(@options[:target])
    @task_id = @options[:task_id]
    @checks = []
  end

  def run
    with_task_lock do
      validate_option_text
      load_context
      resolve_transition
      validate_readiness
      build_outputs
      apply_bundle unless @options[:check]
      render
    end
  rescue LifecycleError => e
    warn "error: #{e.message}"
    exit 1
  rescue JSON::ParserError, Psych::SyntaxError => e
    warn "error: invalid lifecycle input: #{e.message.lines.first.to_s.strip}"
    exit 1
  rescue SystemCallError => e
    warn "error: task lifecycle I/O failed: #{e.message}"
    exit 1
  end

  private

  def parse_options!(argv)
    parser = OptionParser.new do |opts|
      opts.banner = "Usage: aiops task #{@command} TASK_ID [options]"
      opts.on("--target DIR") { |value| @options[:target] = value }
      opts.on("--by AGENT") { |value| @options[:actor] = value }
      opts.on("--role ROLE") { |value| @options[:role] = value }
      opts.on("--next-agent AGENT") { |value| @options[:next_agent] = value }
      opts.on("--summary TEXT") { |value| @options[:summary] = value }
      opts.on("--next-action TEXT") { |value| @options[:next_action] = value }
      opts.on("--evidence PATH") { |value| @options[:evidence] << value }
      opts.on("--validation-skip-reason TEXT") { |value| @options[:validation_skip_reason] = value }
      opts.on("--risk TEXT") { |value| @options[:risks] << value }
      opts.on("--blocker TEXT") { |value| @options[:blockers] << value }
      opts.on("--check") { @options[:check] = true }
      opts.on("--json") { @options[:json] = true }
      opts.on("-h", "--help") do
        puts opts
        exit 0
      end
    end
    remaining = parser.parse(argv)
    raise LifecycleError, "task #{@command} requires exactly one TASK_ID" unless remaining.length == 1
    @options[:task_id] = remaining.first
    unless @options[:task_id].match?(/\AT-\d{8}-\d{3,}\z/)
      raise LifecycleError, "invalid Task ID: #{@options[:task_id]}"
    end
  rescue OptionParser::ParseError => e
    raise LifecycleError, e.message
  end

  def with_task_lock
    lock_root = git_common_dir || File.join(Dir.tmpdir, "aiops-task-locks", Digest::SHA256.hexdigest(@target)[0, 16])
    FileUtils.mkdir_p(File.join(lock_root, "aiops-locks"))
    lock_path = File.join(lock_root, "aiops-locks", "#{@task_id}.lock")
    File.open(lock_path, File::RDWR | File::CREAT, 0o600) do |file|
      unless file.flock(File::LOCK_EX | File::LOCK_NB)
        raise LifecycleError, "Task #{@task_id} is being transitioned in another worktree or process"
      end
      sleep ENV.fetch("AIOPS_TEST_LIFECYCLE_HOLD_SECONDS", "0").to_f
      yield
    ensure
      file&.flock(File::LOCK_UN)
    end
  end

  def git_common_dir
    output, _error, status = Open3.capture3("git", "-C", @target, "rev-parse", "--git-common-dir")
    return nil unless status.success?

    path = output.strip
    File.expand_path(path, @target)
  end

  def load_context
    task_candidates = Dir.glob(File.join(@target, ".ai_project", "tasks", "**", "#{@task_id}*.md")).sort
    raise LifecycleError, "task not found: #{@task_id}" if task_candidates.empty?
    raise LifecycleError, "multiple Task files found for #{@task_id}" if task_candidates.length > 1

    @task_path = task_candidates.first
    @task_original = File.binread(@task_path)
    @task, @task_body = read_front_matter(@task_path)
    raise LifecycleError, "Task ID mismatch in #{@task_path}" unless @task["id"] == @task_id

    registry_path = File.join(@target, ".ai_project", "agent_registry.md")
    raise LifecycleError, ".ai_project/agent_registry.md is required for task #{@command}" unless File.file?(registry_path)
    registry, = read_front_matter(registry_path)
    @agents = Array(registry["agents"]).select { |entry| entry.is_a?(Hash) }

    catalog_path = if File.file?(File.join(@target, ".ai", "runtime", "workflows.json"))
                     File.join(@target, ".ai", "runtime", "workflows.json")
                   else
                     File.join(__dir__, "workflows.json")
                   end
    @catalog = JSON.parse(File.read(catalog_path))
    @workflow = resolve_workflow(@task["workflow"])
    raise LifecycleError, "workflow not found: #{@task['workflow']}" if @workflow.empty?
    @risk_profile = TaskRiskProfiles.evaluate(task: @task, target: @target, catalog: @catalog)
    unless @risk_profile["ready"]
      raise LifecycleError, "risk profile is not ready: #{@risk_profile['blockers'].join('; ')}"
    end
  end

  def read_front_matter(path)
    text = File.read(path)
    raise LifecycleError, "YAML front matter required: #{relative(path)}" unless text.start_with?("---\n")
    lines = text.lines
    closing = lines[1..]&.find_index { |line| line.strip == "---" }
    raise LifecycleError, "YAML front matter closing marker missing: #{relative(path)}" unless closing
    closing += 1
    data = YAML.safe_load(lines[1...closing].join, permitted_classes: [Date, Time, Symbol], aliases: true)
    raise LifecycleError, "front matter must be an object: #{relative(path)}" unless data.is_a?(Hash)
    [data, lines[(closing + 1)..]&.join.to_s]
  end

  def resolve_workflow(workflow_id, seen = [])
    return {} if workflow_id.nil? || seen.include?(workflow_id)
    workflows = @catalog.fetch("workflows", {})
    entry = workflows[workflow_id] || workflows[@catalog["default_workflow"]] || {}
    return entry unless entry["inherits"]
    parent = resolve_workflow(entry["inherits"], seen + [workflow_id])
    parent.merge(entry) do |key, parent_value, child_value|
      key == "statuses" ? parent_value.merge(child_value || {}) : (child_value.nil? ? parent_value : child_value)
    end
  end

  def resolve_transition
    @from = @task["status"].to_s
    @to = if @command == "advance" && @from == "in_progress" && @risk_profile["selected_profile"] == "light"
            "completion_review"
          else
            HAPPY_PATH[@from]
          end
    raise LifecycleError, "no automatic #{@command} transition from #{@from}" unless @to

    if @command == "accept" && !ACCEPT_FROM.include?(@from)
      raise LifecycleError, "task accept is only valid from #{ACCEPT_FROM.join(', ')}; use task advance for #{@from}"
    end
    if @command == "advance" && ACCEPT_FROM.include?(@from)
      raise LifecycleError, "task #{@task_id} is waiting for its assigned owner; use task accept"
    end

    transitions = Array(@workflow["transitions"])
    @transition = transitions.find do |entry|
      profiles = Array(entry["profiles"])
      entry["from"] == @from && entry["to"] == @to && (profiles.empty? || profiles.include?(@risk_profile["selected_profile"]))
    end
    raise LifecycleError, "workflow does not allow automatic transition: #{@from} -> #{@to}" unless @transition

    @actor_role = (@options[:role] || @task["target_role"]).to_s
    allowed_roles = Array(@transition["allowed_roles"])
    unless allowed_roles.include?(@actor_role) || allowed_roles.include?("any")
      raise LifecycleError, "#{@actor_role} cannot transition #{@from} -> #{@to}"
    end

    resolve_actor
    @next_role = @transition["next_role"]
    resolve_receiver
  end

  def resolve_actor
    assigned = @task["target_agent"].to_s
    requested = @options[:actor].to_s
    if !assigned.empty? && !requested.empty? && assigned != requested
      raise LifecycleError, "--by #{requested} conflicts with Task target_agent #{assigned}"
    end
    @actor_name = requested.empty? ? assigned : requested
    if @actor_name.empty?
      candidates = eligible_agents(@actor_role)
      if candidates.length != 1
        names = candidates.map { |agent| agent_name(agent) }.join(", ")
        raise LifecycleError, "cannot choose #{@actor_role} actor#{names.empty? ? '' : ": #{names}"}; set Task target_agent or use --by"
      end
      @actor_name = agent_name(candidates.first)
    end
    @actor = find_agent(@actor_name)
    raise LifecycleError, "actor is not registered: #{@actor_name}" unless @actor
    raise LifecycleError, "actor is not enabled: #{@actor_name}" unless @actor["status"] == "enabled"
    unless Array(@actor["roles"]).include?(@actor_role)
      raise LifecycleError, "#{@actor_name} is not assigned #{@actor_role}"
    end
    ensure_capability(@actor, @actor_role, "sender")
  end

  def resolve_receiver
    if @next_role.nil?
      raise LifecycleError, "terminal transition does not accept --next-agent" if @options[:next_agent]
      @next_agent_name = nil
      return
    end

    if @next_role == @actor_role
      if @options[:next_agent] && @options[:next_agent] != @actor_name
        raise LifecycleError, "task accept keeps ownership with #{@actor_name}; --next-agent cannot change it"
      end
      @next_agent = @actor
      @next_agent_name = @actor_name
      return
    end

    if @options[:next_agent]
      @next_agent = find_agent(@options[:next_agent])
      raise LifecycleError, "next Agent is not registered: #{@options[:next_agent]}" unless @next_agent
      @next_agent_name = agent_name(@next_agent)
    else
      candidates = eligible_agents(@next_role)
      candidates = candidates.reject { |agent| agent_name(agent) == @actor_name } if separation_required?
      @next_agent = choose_receiver(candidates)
      unless @next_agent
        names = candidates.map { |agent| agent_name(agent) }.join(", ")
        raise LifecycleError, "cannot choose next #{@next_role} Agent#{names.empty? ? '' : ": #{names}"}; use --next-agent"
      end
      @next_agent_name = agent_name(@next_agent)
    end

    raise LifecycleError, "next Agent is not enabled: #{@next_agent_name}" unless @next_agent["status"] == "enabled"
    unless Array(@next_agent["roles"]).include?(@next_role)
      raise LifecycleError, "#{@next_agent_name} is not assigned #{@next_role}"
    end
    if @actor_name == @next_agent_name && separation_required?
      raise LifecycleError, "#{@actor_role} and #{@next_role} must use different Agents"
    end
    ensure_capability(@next_agent, @next_role, "receiver")
  end

  def eligible_agents(role)
    @agents.select { |agent| agent["status"] == "enabled" && Array(agent["roles"]).include?(role) }
  end

  def choose_receiver(candidates)
    return candidates.first if candidates.length == 1
    return nil if candidates.empty?

    scored = candidates.map { |agent| [receiver_score(agent), agent] }
    maximum = scored.map(&:first).max
    best = scored.select { |score, _agent| score == maximum }.map(&:last)
    maximum.positive? && best.length == 1 ? best.first : nil
  end

  def receiver_score(agent)
    score = 0
    task_team = @task["team"].to_s.downcase
    score += 30 if !task_team.empty? && agent["team"].to_s.downcase == task_team
    signals = [@task["title"], @task["team"], *@task.fetch("allowed_paths", []), *@task.fetch("required_capabilities", [])].join(" ").downcase
    agent_signals = [agent_name(agent), agent["team"], *Array(agent["capabilities"])].join(" ").downcase
    %w[ios android backend design product web data security].each do |token|
      score += 20 if signals.include?(token) && agent_signals.include?(token)
    end
    score
  end

  def ensure_capability(agent, role, side)
    capabilities = Array(agent["capabilities"]).map(&:to_s).reject(&:empty?)
    raise LifecycleError, "#{side} Agent #{agent_name(agent)} has no declared capabilities" if capabilities.empty?
    pattern = ROLE_CAPABILITY[role]
    return unless pattern && capabilities.none? { |capability| capability.match?(pattern) }
    raise LifecycleError, "#{side} Agent #{agent_name(agent)} lacks a capability for #{role}"
  end

  def separation_required?
    [@actor_role, @next_role].sort == ["Execution Role", "Verification Role"].sort
  end

  def validate_readiness
    check("task", true, "Task metadata loaded")
    check("risk_profile", true, "#{@risk_profile['selected_profile']} profile selected from #{@risk_profile['selection_source']}")
    validate_dependencies
    validate_sources
    validate_changed_paths
    validate_lock
    validate_canonical
    collect_evidence
    validate_required_result
    check("sender", true, "#{@actor_name} / #{@actor_role} is ready")
    next_label = @next_role ? "#{@next_agent_name} / #{@next_role}" : "terminal"
    check("receiver", true, "#{next_label} is ready")
  end

  def validate_dependencies
    Array(@task["depends_on"]).each do |dependency_id|
      path = Dir.glob(File.join(@target, ".ai_project", "tasks", "**", "#{dependency_id}*.md")).sort.first
      raise LifecycleError, "dependency Task missing: #{dependency_id}" unless path
      data, = read_front_matter(path)
      unless %w[done cancelled].include?(data["status"])
        raise LifecycleError, "dependency #{dependency_id} is not complete: #{data['status']}"
      end
    end
    check("dependencies", true, "all dependencies are complete")
  end

  def validate_sources
    sources = Array(@task["source_of_truth"]).map(&:to_s).reject(&:empty?)
    raise LifecycleError, "Task source_of_truth is missing" if sources.empty?
    missing = sources.select do |source|
      next false if source.match?(%r{\Ahttps?://})
      path_like = source.start_with?(".") ||
        source.match?(%r{\A[[:alnum:]_.-]+/[^ ]+\z}) ||
        source.match?(/\A[^[:space:]\/]+\.(?:md|markdown|json|ya?ml|toml|txt|csv|xml|html?|pdf)\z/i)
      path_like && !File.exist?(project_path(source, "source_of_truth"))
    end
    raise LifecycleError, "source_of_truth path missing: #{missing.join(', ')}" unless missing.empty?
    check("source_of_truth", true, "source references are available")
  end

  def validate_changed_paths
    changes = TaskRiskProfiles.git_change_set(@task, @target)
    return check("allowed_paths", true, "non-Git project; path check uses compatibility mode") unless changes["repository"]
    if changes["base"] && !changes["base_resolved"]
      raise LifecycleError, "recorded Git base cannot be resolved: #{changes['base']}; refresh Task base metadata"
    end

    changed = changes["paths"]
    allowed = Array(@task["allowed_paths"]).map { |path| path.to_s.sub(%r{/+\z}, "") }.reject(&:empty?)
    outside = changed.reject do |path|
      path.start_with?(".ai_project/") || allowed.any? { |prefix| prefix == "." || path == prefix || path.start_with?("#{prefix}/") }
    end
    raise LifecycleError, "changed paths outside Task allowed_paths: #{outside.join(', ')}" unless outside.empty?
    check("allowed_paths", true, "#{changed.length} changed path(s) are within Task scope")
  end

  def validate_lock
    locked_by = @task["locked_by"].to_s
    if !locked_by.empty? && locked_by != @actor_name
      raise LifecycleError, "Task is locked by #{locked_by}; #{@actor_name} cannot transition it"
    end
    check("lock", true, locked_by.empty? ? "Task is unlocked" : "Task lock belongs to actor")
  end

  def validate_canonical
    model_path = File.join(@target, ".ai_project", "operating_model.md")
    return check("canonical", true, "canonical status ref is not configured") unless File.file?(model_path)
    model, = read_front_matter(model_path)
    ref = model["canonical_status_ref"].to_s
    return check("canonical", true, "canonical status ref is not configured") if ref.empty?

    sha, error, status = Open3.capture3("git", "-C", @target, "rev-parse", "#{ref}^{commit}")
    raise LifecycleError, "canonical status ref cannot be resolved: #{ref}#{error.empty? ? '' : "; run aiops sync-status"}" unless status.success?
    @status_ref = ref
    @status_ref_sha = sha.strip
    task_sha = @task["status_ref_sha"].to_s
    if !task_sha.empty? && task_sha != @status_ref_sha
      raise LifecycleError, "Task status_ref_sha is stale; run aiops sync-status and reload Task state"
    end

    runtime = File.join(@target, ".ai_project", ".runtime", "status_ref")
    if File.file?(runtime)
      recorded = File.readlines(runtime).find { |line| line.start_with?("status_ref_sha:") }.to_s.split(":", 2).last.to_s.strip
      if !recorded.empty? && recorded != @status_ref_sha
        raise LifecycleError, "recorded canonical status is stale; run aiops sync-status"
      end
    end
    validate_canonical_task_state if task_sha.empty?
    check("canonical", true, "#{ref} @ #{@status_ref_sha[0, 12]} is current")
  end

  def validate_canonical_task_state
    output, _error, status = Open3.capture3(
      "git", "-C", @target, "ls-tree", "-r", "--name-only", @status_ref, "--", ".ai_project/tasks"
    )
    return unless status.success?
    paths = output.lines.map(&:strip).select { |path| File.basename(path).start_with?(@task_id) && path.end_with?(".md") }
    return if paths.empty?
    raise LifecycleError, "multiple canonical Task files found for #{@task_id}" if paths.length > 1

    text, _show_error, show_status = Open3.capture3("git", "-C", @target, "show", "#{@status_ref}:#{paths.first}")
    return unless show_status.success?
    canonical = parse_front_matter_text(text, "#{@status_ref}:#{paths.first}")
    canonical_status = canonical["status"].to_s
    if !canonical_status.empty? && canonical_status != @from
      raise LifecycleError, "local Task state #{@from} is stale against canonical state #{canonical_status}; reload Task state"
    end
  end

  def collect_evidence
    @evidence = @options[:evidence].dup
    if @risk_profile["selected_profile"] == "light" && @from == "in_progress" && @evidence.empty? && @options[:validation_skip_reason].to_s.empty?
      raise LifecycleError, "Light transition requires targeted validation evidence or --validation-skip-reason"
    end
    required_path = case @from
                    when "in_progress" then @task["report_to"]
                    when "verification_in_progress" then @task["qa_to"]
                    end
    if required_path && !required_path.to_s.empty? && @risk_profile["selected_profile"] != "light"
      if File.file?(File.join(@target, required_path.to_s))
        @evidence << required_path.to_s
      elsif @evidence.empty? && @options[:validation_skip_reason].to_s.empty?
        raise LifecycleError, "required transition evidence is missing: #{required_path}"
      end
    end
    @evidence << relative(@task_path) if @evidence.empty? && @options[:validation_skip_reason].to_s.empty?
    @evidence.uniq!
    @evidence.each do |path|
      next if path.match?(%r{\Ahttps?://})
      raise LifecycleError, "evidence path missing: #{path}" unless File.exist?(project_path(path, "evidence"))
    end
    check("evidence", true, @evidence.empty? ? "validation skip reason recorded" : "#{@evidence.length} evidence item(s) available")
  end

  def validate_required_result
    if @options[:blockers].any?
      raise LifecycleError, "readiness has blockers: #{@options[:blockers].join('; ')}"
    end
  end

  def check(code, ready, message)
    @checks << { "code" => code, "ready" => ready, "message" => message }
  end

  def build_outputs
    now = Time.now.utc
    @date = now.strftime("%Y-%m-%dT%H:%M:%SZ")
    @date_only = @date[0, 10]
    receipt_stamp = now.strftime("%Y%m%dT%H%M%S%6N")
    @receipt_relative = ".ai_project/reports/#{@task_id}_#{@from}_to_#{@to}_#{receipt_stamp}-transition-receipt.json"
    @receipt_path = File.join(@target, @receipt_relative)
    raise LifecycleError, "transition receipt already exists: #{@receipt_relative}" if File.exist?(@receipt_path)
    @next_action = @options[:next_action] || default_next_action
    @summary = @options[:summary] || "#{@from}에서 #{@to} 상태로 전이 준비 완료"
    @result = @options[:risks].empty? ? "ready" : "pass_with_risk"
    @result = "passed" if %w[verification_passed done].include?(@to) && @options[:risks].empty?

    receipt_next_agent = @next_agent_name || @actor_name
    receipt_next_role = @next_role || @actor_role
    @receipt = {
      "schema" => "aiops.transition_receipt.v1",
      "task_id" => @task_id,
      "profile" => @risk_profile["selected_profile"],
      "transition" => { "from" => @from, "to" => @to },
      "actor" => { "agent" => @actor_name, "role" => @actor_role },
      "next" => { "agent" => receipt_next_agent, "role" => receipt_next_role, "action" => @next_action },
      "result" => @result,
      "summary" => @summary,
      "evidence" => @evidence,
      "risks" => @options[:risks].uniq,
      "blockers" => @options[:blockers].uniq,
      "receipt_path" => @receipt_relative,
      "created_at" => @date
    }
    skip_reason = @options[:validation_skip_reason].to_s
    @receipt["validation_skip_reason"] = skip_reason unless skip_reason.empty?

    @writes = build_write_set
    @projection = {
      "schema" => "aiops.task_transition_plan.v1",
      "command" => @command,
      "check_only" => @options[:check],
      "ready" => true,
      "task_id" => @task_id,
      "profile" => @risk_profile["selected_profile"],
      "transition" => @receipt["transition"],
      "actor" => @receipt["actor"],
      "next" => @receipt["next"],
      "checks" => @checks,
      "writes" => @writes.keys.map { |path| relative(path) },
      "receipt" => @receipt
    }
  end

  def build_write_set
    task = Marshal.load(Marshal.dump(@task))
    task["status"] = @to
    task["target_role"] = @next_role
    task["target_agent"] = @next_agent_name
    task["updated_at"] = @date_only
    task["transition_receipt_path"] = @receipt_relative
    if @command == "accept"
      task["locked_by"] = @actor_name
      task["locked_at"] = @date_only
    else
      task["locked_by"] = nil
      task["locked_at"] = nil
      task["lock_session"] = nil
    end
    if @status_ref
      task["status_ref"] = @status_ref
      task["status_ref_sha"] = @status_ref_sha
      task["base_ref"] = @status_ref
      task["base_sha"] = @status_ref_sha
    end
    body = append_event(@task_body)
    writes = { @task_path => YAML.dump(task) + "---\n" + body, @receipt_path => JSON.pretty_generate(@receipt) + "\n" }

    if @next_role && @next_role != @actor_role
      handoff_path = File.join(@target, ".ai_project", "handoffs", "#{@task_id}_#{role_slug(@actor_role)}_to_#{role_slug(@next_role)}.md")
      writes[handoff_path] = handoff_document
    end
    board_path = File.join(@target, ".ai_project", "task_board.md")
    writes[board_path] = board_projection(board_path) if File.file?(board_path)
    writes
  end

  def append_event(body)
    text = body.dup
    unless text.include?("## AI Ops CLI 기록")
      text << "\n## AI Ops CLI 기록\n\n| 날짜 | Actor | Event | Reason |\n|---|---|---|---|\n"
    end
    text << "| #{@date_only} | #{@actor_name} | #{@command}: #{@from} -> #{@to} | integrated lifecycle transition |\n"
    text
  end

  def handoff_document
    reports = [@task["report_to"], @task["qa_to"]].compact.map(&:to_s).reject(&:empty?).select do |path|
      File.file?(File.join(@target, path))
    end
    data = {
      "schema" => "aiops.handoff.v1",
      "task_id" => @task_id,
      "from_role" => @actor_role,
      "to_role" => @next_role,
      "from_agent" => @actor_name,
      "to_agent" => @next_agent_name,
      "current_status" => @to,
      "next_action" => @next_action,
      "status_ref" => @status_ref,
      "status_ref_sha" => @status_ref_sha,
      "worktree_path" => @target,
      "worktree_role" => nil,
      "source_of_truth" => Array(@task["source_of_truth"]),
      "allowed_paths" => Array(@task["allowed_paths"]),
      "report_paths" => reports,
      "changed_or_affected_paths" => [],
      "validation_result" => @result == "passed" ? "pass" : (@options[:risks].empty? ? "pass" : "pass_with_risk"),
      "transition_receipt_path" => @receipt_relative,
      "risks" => @options[:risks].uniq,
      "blockers" => [],
      "open_questions" => [],
      "created_at" => @date_only,
      "created_by" => @actor_name
    }
    YAML.dump(data) + <<~MD
      ---

      # Handoff: #{@task_id}

      너는 #{@next_agent_name} / #{@next_role}이야. Task #{@task_id}를 이어서 처리해줘.

      - 전이 receipt: #{@receipt_relative}
      - 현재 상태: #{@to}
      - 다음에 해야 할 일: #{@next_action}
      - 기준 문서: #{Array(@task["source_of_truth"]).join(', ')}
      - 허용 경로: #{Array(@task["allowed_paths"]).join(', ')}
    MD
  end

  def board_projection(path)
    text = File.read(path)
    start_marker = "<!-- aiops:lifecycle #{@task_id} -->"
    end_marker = "<!-- /aiops:lifecycle #{@task_id} -->"
    owner = @next_agent_name || "-"
    role = @next_role || "-"
    block = <<~MD.chomp
      #{start_marker}
      | #{@task_id} | #{@to} | #{owner} | #{role} | #{@next_action} |
      #{end_marker}
    MD
    pattern = /#{Regexp.escape(start_marker)}.*?#{Regexp.escape(end_marker)}/m
    return text.sub(pattern, block) if text.match?(pattern)
    if text.include?("## AI Ops Lifecycle Projection")
      text + "\n#{block}\n"
    else
      text + "\n\n## AI Ops Lifecycle Projection\n\n| Task | Status | Agent | Role | Next |\n|---|---|---|---|---|\n#{block}\n"
    end
  end

  def apply_bundle
    original_digest = Digest::SHA256.hexdigest(File.binread(@task_path))
    raise LifecycleError, "Task changed while readiness was evaluated; retry" unless original_digest == Digest::SHA256.hexdigest(@task_original)

    originals = {}
    staged = {}
    tempfiles = []
    applied = []
    begin
      @writes.each do |path, content|
        FileUtils.mkdir_p(File.dirname(path))
        originals[path] = if File.exist?(path)
                            stat = File.stat(path)
                            { content: File.binread(path), mode: stat.mode & 0o777, uid: stat.uid, gid: stat.gid }
                          end
        file = Tempfile.new([".aiops-lifecycle-", ".tmp"], File.dirname(path))
        tempfiles << file
        file.binmode
        file.chmod(originals[path] ? originals[path][:mode] : 0o644)
        if originals[path]
          begin
            file.chown(originals[path][:uid], originals[path][:gid])
          rescue Errno::EPERM
            # Existing ownership is normally the current user; privileged ownership is not required.
          end
        end
        file.write(content)
        file.flush
        file.fsync
        file.close
        staged[path] = file.path
      end
      validate_staged!(staged)
      raise LifecycleError, "injected lifecycle staging failure" if ENV["AIOPS_TEST_LIFECYCLE_FAIL"] == "before_apply"

      staged.each_with_index do |(path, temp_path), index|
        File.rename(temp_path, path)
        applied << path
        if ENV["AIOPS_TEST_LIFECYCLE_FAIL"] == "after_first_write" && index.zero?
          raise LifecycleError, "injected lifecycle write failure"
        end
      end
    rescue StandardError => e
      applied.reverse_each do |path|
        if originals[path].nil?
          File.delete(path) if File.exist?(path)
        else
          restore_atomic(path, originals[path])
        end
      end
      raise e
    ensure
      staged.each_value { |path| File.delete(path) if File.exist?(path) }
      tempfiles.each { |file| file.close! rescue nil }
    end
  end

  def validate_staged!(staged)
    cli = File.expand_path("../bin/aiops", __dir__)
    staged.each do |destination, staged_path|
      command = if destination == @task_path
                  [cli, "validate", "task", staged_path, "--strict"]
                elsif destination == @receipt_path
                  [cli, "validate", "transition-receipt", staged_path]
                elsif destination.include?("/.ai_project/handoffs/")
                  [cli, "validate", "handoff", staged_path, "--strict"]
                end
      next unless command
      environment = destination.include?("/.ai_project/handoffs/") ? { "AIOPS_SCHEMA_ONLY_HANDOFF" => "1" } : {}
      output, error, status = Open3.capture3(environment, *command)
      detail = error.strip.empty? ? output.lines.last.to_s.strip : error.strip
      raise LifecycleError, "staged #{relative(destination)} failed validation: #{detail}" unless status.success?
    end
    validate_staged_handoff_receipt!(staged)
  end

  def validate_staged_handoff_receipt!(staged)
    receipt_staged = staged[@receipt_path]
    return unless receipt_staged
    receipt = JSON.parse(File.read(receipt_staged))
    staged.each do |destination, staged_path|
      next unless destination.include?("/.ai_project/handoffs/")
      handoff, = read_front_matter(staged_path)
      unless handoff["transition_receipt_path"] == @receipt_relative &&
             handoff["task_id"] == receipt["task_id"] &&
             handoff["current_status"] == receipt.dig("transition", "to")
        raise LifecycleError, "staged handoff does not match its transition receipt: #{relative(destination)}"
      end
    end
  end

  def restore_atomic(path, original)
    file = Tempfile.new([".aiops-rollback-", ".tmp"], File.dirname(path))
    file.binmode
    file.chmod(original[:mode])
    file.write(original[:content])
    file.flush
    file.fsync
    file.close
    File.rename(file.path, path)
    begin
      File.chown(original[:uid], original[:gid], path)
    rescue Errno::EPERM
      # The file remains owned by the current process user when ownership restoration is not permitted.
    end
  ensure
    file&.close!
  end

  def render
    if @options[:json]
      puts JSON.pretty_generate(@projection)
      return
    end
    puts "AI Ops task #{@command}#{@options[:check] ? ' check' : ''}"
    puts "Task: #{@task_id}"
    puts "상태: #{@from} -> #{@to}"
    puts "처리: #{@actor_name} / #{@actor_role}"
    puts "다음: #{@next_agent_name || '없음'} / #{@next_role || '없음'}"
    puts "결과: #{@options[:check] ? '전이 준비 완료, 파일 변경 없음' : @summary}"
    puts "근거: #{@evidence.empty? ? @options[:validation_skip_reason] : @evidence.join(', ')}"
    puts "위험: #{@options[:risks].empty? ? '없음' : @options[:risks].join('; ')}"
    puts "다음 작업: #{@next_action}"
    puts "receipt: #{@receipt_relative}" unless @options[:check]
  end

  def default_next_action
    case @to
    when "scoped" then "범위와 의존성을 검토하고 실행 승인"
    when "approved" then "배정된 Execution Agent가 작업 수락"
    when "in_progress" then "Task 범위 구현 및 자체 검증"
    when "verification_ready" then "독립 검증 시작"
    when "verification_in_progress" then "검증 수행 및 결과 기록"
    when "verification_passed" then "Completion 검토 시작"
    when "completion_review" then "완료 조건과 병합 상태 확인"
    when "done" then "후속 branch 정리 확인"
    else "Task 다음 단계 진행"
    end
  end

  def validate_option_text
    values = [
      @options[:actor],
      @options[:role],
      @options[:next_agent],
      @options[:summary],
      @options[:next_action],
      @options[:validation_skip_reason],
      *@options[:evidence],
      *@options[:risks],
      *@options[:blockers]
    ].compact
    raise LifecycleError, "lifecycle option values cannot contain control characters" if values.any? { |value| value.match?(/[[:cntrl:]]/) }
  end

  def project_path(value, label)
    raise LifecycleError, "#{label} path must be project-relative: #{value}" if Pathname.new(value).absolute?
    path = File.expand_path(value, @target)
    unless path == @target || path.start_with?("#{@target}/")
      raise LifecycleError, "#{label} path escapes project: #{value}"
    end
    path
  end

  def parse_front_matter_text(text, label)
    raise LifecycleError, "YAML front matter required: #{label}" unless text.start_with?("---\n")
    lines = text.lines
    closing = lines[1..]&.find_index { |line| line.strip == "---" }
    raise LifecycleError, "YAML front matter closing marker missing: #{label}" unless closing
    data = YAML.safe_load(lines[1...(closing + 1)].join, permitted_classes: [Date, Time, Symbol], aliases: true)
    raise LifecycleError, "front matter must be an object: #{label}" unless data.is_a?(Hash)
    data
  end

  def find_agent(name)
    @agents.find { |agent| agent_name(agent) == name }
  end

  def agent_name(agent)
    (agent["agent"] || agent["id"]).to_s
  end

  def role_slug(role)
    role.downcase.sub(/ role\z/, "").gsub(/[^a-z0-9]+/, "_").gsub(/\A_|_\z/, "")
  end

  def relative(path)
    path.delete_prefix("#{@target}/")
  end
end

command = ARGV.shift
unless %w[advance accept].include?(command)
  warn "error: lifecycle command must be advance or accept"
  exit 1
end

TaskLifecycle.new(command, ARGV).run

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
require "time"
require "tmpdir"
require "yaml"

require_relative "agent_identity"

class AgentIdentityMigrationError < StandardError; end

class AgentIdentityMigration
  ACTIONS = %w[update_registry update_current_tasks validate_identity write_receipt].freeze
  CURRENT_SCOPES = %w[active backlog].freeze
  UNSAFE_NAME = /[;&|`$<>\\\x00-\x1f\x7f]/.freeze

  def initialize(operation, argv)
    @operation = operation
    @options = { target: Dir.pwd, apply: false, json: false, actor: "AI Ops CLI", mappings: {}, locale: ENV.fetch("AIOPS_LOCALE", "ko") }
    @now = Time.now.utc
    parse_options!(argv)
    @target = File.expand_path(@options[:target])
    @project_dir = File.join(@target, ".ai_project")
    @registry_path = File.join(@project_dir, "agent_registry.md")
  end

  def run
    with_lock do
      load_context
      build_changes
      validate_environment
      build_plan
      @options[:apply] ? apply : render(@plan)
    end
  rescue AgentIdentityMigrationError => error
    warn "error: #{error.message}"
    exit 1
  rescue JSON::ParserError, Psych::SyntaxError => error
    warn "error: invalid Agent identity migration input: #{error.message.lines.first.to_s.strip}"
    exit 1
  rescue SystemCallError => error
    warn "error: Agent identity migration I/O failed: #{error.message}"
    exit 1
  end

  private

  def parse_options!(argv)
    parser = OptionParser.new do |opts|
      title = @operation == "rename" ? "agent rename AGENT_ID --to NAME" : "agent migrate-identities"
      opts.banner = "Usage: aiops #{title} [--target DIR] [--check|--apply] [--locale ko|en] [--json]"
      opts.on("--target DIR") { |value| @options[:target] = value }
      opts.on("--to NAME") { |value| @options[:to] = value } if @operation == "rename"
      opts.on("--map NAME=ID") { |value| add_mapping(value) } if @operation == "migrate-identities"
      opts.on("--by ACTOR") { |value| @options[:actor] = value }
      opts.on("--locale LOCALE") { |value| @options[:locale] = value }
      opts.on("--check") { @options[:check] = true }
      opts.on("--apply") { @options[:apply] = true }
      opts.on("--json") { @options[:json] = true }
      opts.on("-h", "--help") do
        puts opts
        puts
        puts "Without --apply, this command only prints a read-only plan."
        puts "Only Agent Registry and active/backlog Task front matter can be updated."
        puts "Archive Tasks, reports, QA, handoffs, and historical receipts are preserved."
        if @operation == "migrate-identities"
          puts "Use --map 'Agent Name=stable-id' to resolve migration ID collisions."
        else
          puts "The previous display name is retained as a legacy alias."
        end
        exit 0
      end
    end
    remaining = parser.parse(argv)
    raise AgentIdentityMigrationError, "--check and --apply cannot be used together" if @options[:check] && @options[:apply]
    validate_printable(@options[:actor], "--by")
    @options[:locale] = normalize_locale(@options[:locale])
    if @operation == "rename"
      raise AgentIdentityMigrationError, "agent rename requires exactly one AGENT_ID" unless remaining.length == 1
      @agent_id = remaining.first
      raise AgentIdentityMigrationError, "invalid Agent ID: #{@agent_id}" unless @agent_id.match?(AgentIdentity::ID_PATTERN)
      validate_agent_name(@options[:to], "--to")
      raise AgentIdentityMigrationError, "--map is only valid with migrate-identities" unless @options[:mappings].empty?
    else
      raise AgentIdentityMigrationError, "agent migrate-identities does not accept positional arguments" unless remaining.empty?
      raise AgentIdentityMigrationError, "--to is only valid with agent rename" if @options[:to]
    end
  rescue OptionParser::ParseError => error
    raise AgentIdentityMigrationError, error.message
  end

  def add_mapping(value)
    name, agent_id = value.to_s.split("=", 2)
    validate_agent_name(name, "--map name")
    raise AgentIdentityMigrationError, "--map requires NAME=ID" if agent_id.to_s.empty?
    raise AgentIdentityMigrationError, "invalid mapped Agent ID: #{agent_id}" unless agent_id.match?(AgentIdentity::ID_PATTERN)
    raise AgentIdentityMigrationError, "duplicate --map name: #{name}" if @options[:mappings].key?(name)
    @options[:mappings][name] = agent_id
  end

  def validate_agent_name(value, label)
    text = value.to_s
    raise AgentIdentityMigrationError, "#{label} requires a non-empty Agent name" if text.empty?
    raise AgentIdentityMigrationError, "#{label} contains unsafe shell or control characters" if text.match?(UNSAFE_NAME)
  end

  def validate_printable(value, label)
    text = value.to_s
    raise AgentIdentityMigrationError, "#{label} must be a non-empty printable value" if text.empty? || text.match?(/[\x00-\x1f\x7f]/)
  end

  def normalize_locale(value)
    case value.to_s
    when /\Ako(?:[-_].*)?\z/i then "ko"
    when /\Aen(?:[-_].*)?\z/i then "en"
    else raise AgentIdentityMigrationError, "--locale supports: ko, en"
    end
  end

  def with_lock
    return yield unless @options[:apply]

    common = capture_git("rev-parse", "--git-common-dir", allow_failure: true)&.strip
    root = common && !common.empty? ? File.expand_path(common, @target) : File.join(Dir.tmpdir, "aiops-agent-identity-locks", Digest::SHA256.hexdigest(@target)[0, 16])
    FileUtils.mkdir_p(File.join(root, "aiops-locks"))
    path = File.join(root, "aiops-locks", "agent-identity-migration.lock")
    File.open(path, File::RDWR | File::CREAT, 0o600) do |file|
      raise AgentIdentityMigrationError, "Agent identity migration is already running" unless file.flock(File::LOCK_EX | File::LOCK_NB)
      sleep ENV.fetch("AIOPS_TEST_AGENT_IDENTITY_HOLD_SECONDS", "0").to_f
      yield
    ensure
      file&.flock(File::LOCK_UN)
    end
  end

  def load_context
    ensure_git_repository
    raise AgentIdentityMigrationError, ".ai_project/agent_registry.md is missing" unless File.file?(@registry_path)
    ensure_owned_path(@registry_path)
    @registry, @registry_body = read_front_matter(@registry_path)
    raise AgentIdentityMigrationError, "agent_registry agents must be an array" unless @registry["agents"].is_a?(Array)
    @identity = AgentIdentity::Registry.new(@registry["agents"])
    raise AgentIdentityMigrationError, registry_error unless @identity.valid?
    @registry["agents"].each do |agent|
      validate_agent_name(agent["agent"], "Agent name")
      Array(agent["aliases"]).each { |value| validate_agent_name(value, "Agent alias") }
    end
    @task_records = CURRENT_SCOPES.flat_map do |scope|
      Dir.glob(File.join(@project_dir, "tasks", scope, "**", "*.md")).sort.map do |path|
        ensure_owned_path(path)
        data, body = read_front_matter(path)
        { scope: scope, path: path, data: data, body: body }
      end
    end
    @historical_references = Dir.glob(File.join(@project_dir, "tasks", "archive", "**", "*.md")).count do |path|
      next false if File.symlink?(path)
      text = File.read(path)
      text.match?(/^target_agent(?:_id)?:[ \t]*\S+/)
    end
  end

  def build_changes
    @changes = []
    if @operation == "rename"
      build_rename
    else
      build_migration
    end
    @updated_identity = AgentIdentity::Registry.new(@registry["agents"])
    raise AgentIdentityMigrationError, "planned Agent Registry is invalid" unless @updated_identity.valid?
    synchronize_tasks
    @writes = {}
    @writes[@registry_path] = serialize_front_matter(@registry, @registry_body) if @registry_changed
    @task_records.each do |record|
      next unless record[:changed]
      @writes[record[:path]] = serialize_front_matter(record[:data], record[:body])
    end
  end

  def build_rename
    matches = @registry["agents"].select { |agent| agent["id"].to_s == @agent_id }
    raise AgentIdentityMigrationError, "Agent ID is not registered: #{@agent_id}" if matches.empty?
    raise AgentIdentityMigrationError, "Agent ID is ambiguous: #{@agent_id}" unless matches.length == 1
    agent = matches.first
    from = agent["agent"].to_s
    to = @options[:to]
    if from == to
      @rename_from = from
      @rename_to = to
      return
    end
    collision = @registry["agents"].any? do |other|
      !other.equal?(agent) && ([other["id"].to_s, other["agent"].to_s] + Array(other["aliases"]).map(&:to_s)).include?(to)
    end
    raise AgentIdentityMigrationError, "new Agent name conflicts with another identity: #{to}" if collision
    aliases = Array(agent["aliases"]).reject { |value| value == to }
    aliases << from unless aliases.include?(from)
    aliases.each { |value| validate_agent_name(value, "Agent alias") }
    agent["aliases"] = aliases
    agent["agent"] = to
    @registry_changed = true
    @rename_from = from
    @rename_to = to
    @changes << { "agent_id" => @agent_id, "from_name" => from, "to_name" => to, "aliases_added" => [from], "task_ids" => [] }
  end

  def build_migration
    names = @registry["agents"].map { |agent| agent["agent"].to_s }
    unknown_maps = @options[:mappings].keys - names
    raise AgentIdentityMigrationError, "--map references unknown Agent names: #{unknown_maps.join(', ')}" unless unknown_maps.empty?
    used = @registry["agents"].map { |agent| agent["id"].to_s }.reject(&:empty?)
    mapped = []
    @registry["agents"].each do |agent|
      name = agent["agent"].to_s
      validate_agent_name(name, "Agent name")
      next unless agent["id"].to_s.empty?
      agent_id = @options[:mappings][name] || slug(name)
      mapped << name if @options[:mappings].key?(name)
      raise AgentIdentityMigrationError, "cannot derive a stable Agent ID for #{name}; use --map NAME=ID" if agent_id.empty?
      if used.include?(agent_id)
        raise AgentIdentityMigrationError, "derived Agent ID collision for #{name}: #{agent_id}; use --map NAME=ID"
      end
      agent["id"] = agent_id
      used << agent_id
      @registry_changed = true
      @changes << { "agent_id" => agent_id, "from_name" => name, "to_name" => name, "aliases_added" => [], "task_ids" => [] }
    end
    unused_maps = @options[:mappings].keys - mapped
    unless unused_maps.empty?
      raise AgentIdentityMigrationError, "--map is only valid for Agents without an ID: #{unused_maps.join(', ')}"
    end
  end

  def slug(name)
    name.downcase.gsub(/[^a-z0-9]+/, "-").gsub(/\A-+|-+\z/, "")
  end

  def synchronize_tasks
    @task_records.each do |record|
      task = record[:data]
      name = task["target_agent"]
      agent_id = task["target_agent_id"]
      resolution = @updated_identity.resolve(name, agent_id)
      next if resolution.state == "unassigned"
      unless %w[resolved legacy alias].include?(resolution.state) && resolution.agent
        raise AgentIdentityMigrationError, "#{relative(record[:path])} has unresolved Agent identity: #{resolution.state}"
      end
      resolved_id = @updated_identity.id(resolution.agent)
      raise AgentIdentityMigrationError, "#{relative(record[:path])} Agent has no stable ID" if resolved_id.empty?
      resolved_name = @updated_identity.name(resolution.agent)
      if task["target_agent_id"] != resolved_id || task["target_agent"] != resolved_name
        task["target_agent_id"] = resolved_id
        task["target_agent"] = resolved_name
        record[:changed] = true
        change = @changes.find { |item| item["agent_id"] == resolved_id }
        change ||= begin
          item = { "agent_id" => resolved_id, "from_name" => resolved_name, "to_name" => resolved_name, "aliases_added" => [], "task_ids" => [] }
          @changes << item
          item
        end
        change["task_ids"] << task["id"].to_s
      end
    end
    @changes.each { |change| change["task_ids"] = change["task_ids"].uniq.sort }
  end

  def validate_environment
    validate_canonical_cache
    validate_runtime_cache
    validate_dirty_paths
    validate_other_worktrees
    @preconditions = @writes.keys.sort.map do |path|
      stat = File.stat(path)
      { "path" => relative(path), "sha256" => Digest::SHA256.file(path).hexdigest, "mode" => format("%04o", stat.mode & 0o777) }
    end
    validate_projected_identity
  end

  def validate_canonical_cache
    model_path = File.join(@project_dir, "operating_model.md")
    return unless File.file?(model_path)
    model, = read_front_matter(model_path)
    ref = model["canonical_status_ref"]
    ref = ref["ref"] if ref.is_a?(Hash)
    ref = ref.to_s.strip
    return if ref.empty?
    sha = capture_git("rev-parse", "#{ref}^{commit}", allow_failure: true).to_s.strip
    raise AgentIdentityMigrationError, "canonical status ref cannot be resolved: #{ref}" if sha.empty?
    runtime = File.join(@project_dir, ".runtime", "status_ref")
    return unless File.file?(runtime)
    recorded = File.readlines(runtime).find { |line| line.start_with?("status_ref_sha:") }.to_s.split(":", 2).last.to_s.strip
    raise AgentIdentityMigrationError, "recorded canonical status is stale; run aiops sync-status" if !recorded.empty? && recorded != sha
  end

  def validate_runtime_cache
    receipt_token = if @options[:apply]
                      @now.strftime("%Y%m%dT%H%M%S%6NZ")
                    else
                      "plan-#{plan_fingerprint}"
                    end
    @receipt_relative = ".ai_project/.runtime/agent_identity/#{@operation}-#{receipt_token}-receipt.json"
    @receipt_path = File.join(@target, @receipt_relative)
    _out, _error, status = Open3.capture3("git", "-C", @target, "check-ignore", "--quiet", "--", @receipt_relative)
    raise AgentIdentityMigrationError, ".ai_project/.runtime must be Git-ignored before Agent identity changes" unless status.success?
  end

  def plan_fingerprint
    inputs = [
      @operation,
      @agent_id,
      @rename_from,
      @rename_to,
      @options[:mappings].sort,
      @writes.keys.sort.map { |path| [relative(path), Digest::SHA256.hexdigest(@writes.fetch(path))] }
    ]
    Digest::SHA256.hexdigest(JSON.generate(inputs))[0, 16]
  end

  def validate_dirty_paths
    return if @writes.empty?
    output = capture_git("status", "--porcelain", "--", *@writes.keys.map { |path| relative(path) })
    raise AgentIdentityMigrationError, "Agent identity target files are dirty; commit or restore them before applying" unless output.empty?
  end

  def validate_other_worktrees
    return if @writes.empty?
    roots = capture_git("worktree", "list", "--porcelain").lines.each_with_object([]) do |line, out|
      out << line.delete_prefix("worktree ").strip if line.start_with?("worktree ")
    end
    current = capture_git("rev-parse", "--show-toplevel").strip
    roots.reject { |root| same_path?(root, current) }.each do |root|
      paths = @writes.keys.map { |path| relative(path) }
      output, error, status = Open3.capture3("git", "-C", root, "status", "--porcelain", "--", *paths)
      unless status.success?
        raise AgentIdentityMigrationError, "cannot inspect linked worktree #{root}: #{error.lines.first.to_s.strip}"
      end
      raise AgentIdentityMigrationError, "Agent identity files are dirty in another worktree: #{root}" unless output.empty?
    end
  end

  def validate_projected_identity
    @task_records.each do |record|
      task = record[:data]
      resolution = @updated_identity.resolve(task["target_agent"], task["target_agent_id"])
      unless %w[unassigned resolved].include?(resolution.state)
        raise AgentIdentityMigrationError, "projected Task identity is not stable: #{relative(record[:path])} (#{resolution.state})"
      end
    end
  end

  def build_plan
    schema = @operation == "rename" ? "aiops.agent_rename_plan.v1" : "aiops.agent_identity_migration_plan.v1"
    @plan = common_document(schema, true).merge(
      "ready" => true,
      "preconditions" => @preconditions,
      "checks" => [
        { "code" => "canonical", "ready" => true, "message" => "canonical status and local cache are consistent" },
        { "code" => "worktrees", "ready" => true, "message" => "target files are clean in all linked worktrees" },
        { "code" => "identity", "ready" => true, "message" => "projected Agent identities resolve by stable ID" }
      ],
      "actions" => ACTIONS.map do |action|
        changed = !@writes.empty?
        status = action == "write_receipt" ? (changed ? "planned" : "skipped") : (changed ? "planned" : "skipped")
        { "action" => action, "status" => status, "detail" => action_detail(action) }
      end,
      "blockers" => []
    )
    if @operation == "rename"
      @plan["agent_id"] = @agent_id
      @plan["from_name"] = @rename_from
      @plan["to_name"] = @rename_to
    end
  end

  def common_document(schema, check_only)
    {
      "schema" => schema,
      "generated_at" => @now.iso8601(6),
      "operation" => @operation,
      "check_only" => check_only,
      "target" => @target,
      "actor" => @options[:actor],
      "changes" => @changes,
      "writes" => @writes.keys.sort.map { |path| relative(path) },
      "historical_references_preserved" => @historical_references,
      "receipt_path" => @receipt_relative
    }
  end

  def action_detail(action)
    case action
    when "update_registry" then @registry_changed ? relative(@registry_path) : "Registry already has stable identity values"
    when "update_current_tasks" then "#{@task_records.count { |record| record[:changed] }} active/backlog Task(s)"
    when "validate_identity" then "validate stable ID and current-name resolution"
    else @receipt_relative
    end
  end

  def apply
    if @writes.empty?
      existing = existing_completed_receipt
      if existing
        render(existing)
        return
      end
      receipt = build_receipt("complete", ACTIONS.map do |action|
        result = action == "write_receipt" ? "complete" : "skipped"
        { "action" => action, "result" => result, "detail" => action_detail(action) }
      end)
      apply_bundle(@receipt_path => JSON.pretty_generate(receipt) + "\n")
      render(receipt)
      return
    end
    verify_preconditions
    receipt = build_receipt("complete", ACTIONS.map { |action| { "action" => action, "result" => "complete", "detail" => action_detail(action) } })
    bundle = @writes.merge(@receipt_path => JSON.pretty_generate(receipt) + "\n")
    apply_bundle(bundle)
    render(receipt)
  end

  def existing_completed_receipt
    pattern = File.join(@project_dir, ".runtime", "agent_identity", "#{@operation}-*-receipt.json")
    Dir.glob(pattern).sort.reverse_each do |path|
      data = JSON.parse(File.read(path))
      next unless data["result"] == "complete" && data["operation"] == @operation
      if @operation == "rename"
        next unless data["agent_id"] == @agent_id && data["to_name"] == @rename_to
      end
      return data
    rescue JSON::ParserError, SystemCallError
      next
    end
    nil
  end

  def build_receipt(result, actions)
    schema = @operation == "rename" ? "aiops.agent_rename_receipt.v1" : "aiops.agent_identity_migration_receipt.v1"
    data = common_document(schema, false).merge(
      "applied_at" => Time.now.utc.iso8601(6),
      "result" => result,
      "actions" => actions,
      "blockers" => []
    )
    if @operation == "rename"
      data["agent_id"] = @agent_id
      data["from_name"] = @rename_from
      data["to_name"] = @rename_to
    end
    data
  end

  def verify_preconditions
    @preconditions.each do |item|
      path = File.join(@target, item["path"])
      current = File.file?(path) ? Digest::SHA256.file(path).hexdigest : nil
      raise AgentIdentityMigrationError, "#{item['path']} changed after planning; retry" unless current == item["sha256"]
    end
  end

  def apply_bundle(writes)
    originals = {}
    staged = {}
    applied = []
    begin
      writes.each do |path, content|
        FileUtils.mkdir_p(File.dirname(path))
        originals[path] = file_state(path)
        file = Tempfile.new([".aiops-agent-identity-", ".tmp"], File.dirname(path))
        file.binmode
        file.chmod(originals[path] ? originals[path][:mode] : 0o600)
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
        staged[path] = file
      end
      validate_staged(staged)
      raise AgentIdentityMigrationError, "injected Agent identity staging failure" if ENV["AIOPS_TEST_AGENT_IDENTITY_FAIL"] == "before_apply"
      staged.each_with_index do |(path, temporary), index|
        ensure_original_unchanged(path, originals[path])
        File.rename(temporary.path, path)
        applied << path
        if ENV["AIOPS_TEST_AGENT_IDENTITY_FAIL"] == "after_first_write" && index.zero?
          raise AgentIdentityMigrationError, "injected Agent identity write failure"
        end
      end
    rescue StandardError => error
      applied.reverse_each do |path|
        originals[path] ? restore_atomic(path, originals[path]) : FileUtils.rm_f(path)
      end
      raise error
    ensure
      staged.each_value { |file| file.close! rescue nil }
    end
  end

  def validate_staged(staged)
    registry_file = staged[@registry_path]
    if registry_file
      data, = read_front_matter(registry_file.path)
      identity = AgentIdentity::Registry.new(data["agents"])
      raise AgentIdentityMigrationError, "staged Agent Registry is invalid" unless data["agents"].is_a?(Array) && identity.valid?
    end
    cli = File.expand_path("../bin/aiops", __dir__)
    staged.each do |destination, temporary|
      if destination == @receipt_path
        subject = @operation == "rename" ? "agent-rename-receipt" : "agent-identity-migration-receipt"
        output, error, status = Open3.capture3(cli, "validate", subject, temporary.path)
        detail = error.empty? ? output.lines.last.to_s.strip : error.lines.first.to_s.strip
        raise AgentIdentityMigrationError, "staged receipt failed validation: #{detail}" unless status.success?
        next
      end
      next unless @task_records.any? { |record| record[:path] == destination }
      output, error, status = Open3.capture3(cli, "validate", "task", temporary.path, "--strict")
      detail = error.empty? ? output.lines.last.to_s.strip : error.lines.first.to_s.strip
      raise AgentIdentityMigrationError, "staged #{relative(destination)} failed validation: #{detail}" unless status.success?
    end
  end

  def file_state(path)
    return nil unless File.exist?(path)
    stat = File.stat(path)
    { content: File.binread(path), mode: stat.mode & 0o777, uid: stat.uid, gid: stat.gid }
  end

  def ensure_original_unchanged(path, original)
    if original.nil?
      raise AgentIdentityMigrationError, "#{relative(path)} appeared during apply; retry" if File.exist?(path)
      return
    end
    current = file_state(path)
    unless current && current[:content] == original[:content] && current[:mode] == original[:mode]
      raise AgentIdentityMigrationError, "#{relative(path)} changed during apply; retry"
    end
  end

  def restore_atomic(path, original)
    file = Tempfile.new([".aiops-agent-identity-rollback-", ".tmp"], File.dirname(path))
    file.binmode
    file.chmod(original[:mode])
    file.write(original[:content])
    file.flush
    file.fsync
    file.close
    File.rename(file.path, path)
    File.chown(original[:uid], original[:gid], path)
  rescue Errno::EPERM
    nil
  ensure
    file&.close! rescue nil
  end

  def render(data)
    if @options[:json]
      puts JSON.pretty_generate(data)
      return
    end
    locale = @options[:locale]
    if locale == "en"
      puts "AI Ops Agent identity #{data['check_only'] ? 'plan' : 'result'}"
      puts "operation: #{data['operation']}"
      puts "changes: #{data['changes'].length}"
      puts "current Task files: #{data['writes'].count { |path| path.include?('/tasks/') }}"
      puts "historical references preserved: #{data['historical_references_preserved']}"
      puts(data["check_only"] ? "ready: yes" : "result: #{data['result']}")
      puts "receipt: #{data['receipt_path']}" unless data["check_only"]
    else
      puts "AI Ops Agent Identity #{data['check_only'] ? '변경 계획' : '적용 결과'}"
      puts "작업: #{data['operation'] == 'rename' ? '이름 변경' : '안정 ID 이관'}"
      puts "변경 Agent: #{data['changes'].length}"
      puts "현재 Task 파일: #{data['writes'].count { |path| path.include?('/tasks/') }}"
      puts "보존한 역사 참조: #{data['historical_references_preserved']}"
      puts(data["check_only"] ? "상태: 적용 가능" : "결과: #{data['result']}")
      puts "receipt: #{data['receipt_path']}" unless data["check_only"]
    end
  end

  def registry_error
    "Agent Registry identity values are invalid; run aiops agent inspect"
  end

  def ensure_git_repository
    _out, _error, status = Open3.capture3("git", "-C", @target, "rev-parse", "--show-toplevel")
    raise AgentIdentityMigrationError, "Agent identity changes require a Git worktree" unless status.success?
  end

  def ensure_owned_path(path)
    raise AgentIdentityMigrationError, "refusing symlinked Agent identity file: #{relative(path)}" if File.symlink?(path)
    real_target = File.realpath(@target)
    real_path = File.realpath(path)
    prefix = real_target.end_with?(File::SEPARATOR) ? real_target : "#{real_target}#{File::SEPARATOR}"
    raise AgentIdentityMigrationError, "refusing project-external symlink: #{relative(path)}" unless real_path.start_with?(prefix)
  end

  def read_front_matter(path)
    text = File.read(path)
    raise AgentIdentityMigrationError, "YAML front matter required: #{relative(path)}" unless text.start_with?("---\n")
    lines = text.lines
    closing = lines[1..]&.find_index { |line| line.strip == "---" }
    raise AgentIdentityMigrationError, "YAML front matter closing marker missing: #{relative(path)}" unless closing
    closing += 1
    data = YAML.safe_load(lines[1...closing].join, permitted_classes: [Date, Time, Symbol], aliases: true)
    raise AgentIdentityMigrationError, "front matter must be an object: #{relative(path)}" unless data.is_a?(Hash)
    [data, lines[(closing + 1)..]&.join.to_s]
  end

  def serialize_front_matter(data, body)
    YAML.dump(data) + "---\n" + body
  end

  def capture_git(*args, allow_failure: false)
    output, error, status = Open3.capture3("git", "-C", @target, *args)
    return output if status.success?
    return nil if allow_failure
    raise AgentIdentityMigrationError, "git #{args.first} failed: #{error.lines.first.to_s.strip}"
  end

  def same_path?(left, right)
    File.realpath(left) == File.realpath(right)
  rescue SystemCallError
    File.expand_path(left) == File.expand_path(right)
  end

  def relative(path)
    Pathname.new(path).relative_path_from(Pathname.new(@target)).to_s
  rescue ArgumentError
    path
  end
end

operation = ARGV.shift
unless %w[rename migrate-identities].include?(operation)
  warn "error: Agent identity migration requires rename or migrate-identities"
  exit 1
end
begin
  AgentIdentityMigration.new(operation, ARGV).run
rescue AgentIdentityMigrationError => error
  warn "error: #{error.message}"
  exit 1
rescue JSON::ParserError, Psych::SyntaxError => error
  warn "error: invalid Agent identity migration input: #{error.message.lines.first.to_s.strip}"
  exit 1
rescue SystemCallError => error
  warn "error: Agent identity migration I/O failed: #{error.message}"
  exit 1
end

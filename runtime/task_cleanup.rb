#!/usr/bin/env ruby
# frozen_string_literal: true

require "date"
require "digest"
require "fileutils"
require "json"
require "open3"
require "optparse"
require "pathname"
require "time"
require "tmpdir"
require "uri"
require "yaml"

class TaskCleanupError < StandardError; end

class TaskCleanup
  PROTECTED_BRANCHES = %w[main master develop].freeze
  SAFE_REF_NAME = %r{\A[A-Za-z0-9][A-Za-z0-9._/-]*\z}.freeze

  def initialize(argv)
    @options = {
      target: Dir.pwd,
      check: false,
      apply: false,
      json: false,
      delete_remote: false,
      actor: "AI Ops CLI"
    }
    parse_options!(argv)
    @target = File.expand_path(@options[:target])
    @task_id = @options[:task_id]
    @checks = []
    @actions = []
  end

  def run
    with_task_lock do
      load_context
      inspect_repository
      validate_cleanup
      build_plan
      if @options[:apply]
        apply_cleanup
      else
        render(@plan)
      end
    end
  rescue TaskCleanupError => error
    warn "error: #{error.message}"
    exit 1
  rescue JSON::ParserError, Psych::SyntaxError => error
    warn "error: invalid task cleanup input: #{error.message.lines.first.to_s.strip}"
    exit 1
  rescue SystemCallError => error
    warn "error: task cleanup I/O failed: #{error.message}"
    exit 1
  end

  private

  def parse_options!(argv)
    parser = OptionParser.new do |opts|
      opts.banner = "Usage: aiops task close TASK_ID [options]"
      opts.on("--target DIR") { |value| @options[:target] = value }
      opts.on("--by ACTOR") { |value| @options[:actor] = value }
      opts.on("--delete-remote") { @options[:delete_remote] = true }
      opts.on("--check") { @options[:check] = true }
      opts.on("--apply") { @options[:apply] = true }
      opts.on("--json") { @options[:json] = true }
      opts.on("-h", "--help") do
        puts opts
        puts
        puts "Without --apply, only prints the cleanup plan."
        puts "Use --apply to remove an eligible linked worktree and local Task branch."
        puts "Remote deletion requires --delete-remote and must not be disabled by project policy."
        exit 0
      end
    end
    remaining = parser.parse(argv)
    raise TaskCleanupError, "task close requires exactly one TASK_ID" unless remaining.length == 1
    @options[:task_id] = remaining.first
    unless @options[:task_id].match?(/\AT-\d{8}-\d{3,}\z/)
      raise TaskCleanupError, "invalid Task ID: #{@options[:task_id]}"
    end
    raise TaskCleanupError, "--check and --apply cannot be used together" if @options[:check] && @options[:apply]
    @options[:check] = true unless @options[:apply]
    if @options[:actor].to_s.empty? || @options[:actor].match?(/[\x00-\x1f\x7f]/)
      raise TaskCleanupError, "--by must be a non-empty printable value"
    end
  rescue OptionParser::ParseError => error
    raise TaskCleanupError, error.message
  end

  def with_task_lock
    common = capture_git("rev-parse", "--git-common-dir", allow_failure: true)&.strip
    lock_root = common && !common.empty? ? File.expand_path(common, @target) : File.join(Dir.tmpdir, "aiops-task-cleanup-locks", Digest::SHA256.hexdigest(@target)[0, 16])
    FileUtils.mkdir_p(File.join(lock_root, "aiops-locks"))
    lock_path = File.join(lock_root, "aiops-locks", "#{@task_id}.cleanup.lock")
    File.open(lock_path, File::RDWR | File::CREAT, 0o600) do |file|
      unless file.flock(File::LOCK_EX | File::LOCK_NB)
        raise TaskCleanupError, "Task #{@task_id} cleanup is already running"
      end
      yield
    ensure
      file&.flock(File::LOCK_UN)
    end
  end

  def load_context
    ensure_git_repository
    candidates = Dir.glob(File.join(@target, ".ai_project", "tasks", "**", "#{@task_id}*.md")).sort
    raise TaskCleanupError, "task not found: #{@task_id}" if candidates.empty?
    raise TaskCleanupError, "multiple Task files found for #{@task_id}" if candidates.length > 1

    @task_path = candidates.first
    @task, = read_front_matter(@task_path)
    raise TaskCleanupError, "Task ID mismatch in #{relative(@task_path)}" unless @task["id"] == @task_id
    raise TaskCleanupError, "task close requires local Task status done; got #{@task['status']}" unless @task["status"] == "done"

    branch = @task["branch"]
    @branch = branch.is_a?(Hash) ? branch["name"].to_s : ""
    raise TaskCleanupError, "Task branch.name is required for task close" if @branch.empty?
    validate_branch_name(@branch)

    @operating_model = read_optional_front_matter(File.join(@target, ".ai_project", "operating_model.md"))
    @strategy_text = read_optional_text(File.join(@target, ".ai_project", "branch_pr_strategy.md"))
    @canonical_ref = canonical_ref
    raise TaskCleanupError, "canonical_status_ref is required for task close" if @canonical_ref.empty?
    validate_canonical_ref_name(@canonical_ref)
    @canonical_sha = capture_git("rev-parse", "#{@canonical_ref}^{commit}").strip
    @canonical_branch = canonical_branch_name(@canonical_ref)
    @remote = canonical_remote_name(@canonical_ref)
    @remote ||= "origin" if remote_exists?("origin")

    @receipt_relative = ".ai_project/.runtime/task_cleanup/#{@task_id}-cleanup-receipt.json"
    @receipt_path = File.join(@target, @receipt_relative)
  end

  def inspect_repository
    @local_ref = "refs/heads/#{@branch}"
    @local_exists = ref_exists?(@local_ref)
    @local_sha = capture_git("rev-parse", "#{@local_ref}^{commit}").strip if @local_exists
    @remote_ref = @remote ? "refs/remotes/#{@remote}/#{@branch}" : nil
    @remote_exists = @remote_ref ? ref_exists?(@remote_ref) : false
    @remote_sha = capture_git("rev-parse", "#{@remote_ref}^{commit}").strip if @remote_exists
    @current_branch = capture_git("symbolic-ref", "--quiet", "--short", "HEAD", allow_failure: true).to_s.strip
    @root = capture_git("rev-parse", "--show-toplevel").strip
    @worktrees = parse_worktrees
    @branch_worktree = @worktrees.find { |entry| entry[:branch] == @local_ref }
    @task_worktree = @task["worktree_path"].to_s
    @task_worktree = nil if @task_worktree.empty?
    @task_worktree = File.expand_path(@task_worktree, @target) if @task_worktree
    @shared_by = shared_task_ids
    @project_delete_policy = delete_branch_policy
    @repository = github_repository
  end

  def validate_cleanup
    validate_canonical_task
    validate_recorded_canonical
    validate_runtime_cache_policy
    check("task_done", true, "Task is done locally and in #{@canonical_ref}")

    raise TaskCleanupError, "cannot close the current branch #{@branch}; switch to the canonical worktree" if @current_branch == @branch
    check("current_branch", true, "current branch #{@current_branch} is separate from #{@branch}")

    protected = protected_branches
    raise TaskCleanupError, "refusing to delete protected branch #{@branch}" if protected.include?(@branch)
    check("protected_branch", true, "#{@branch} is not a configured protected branch")

    unless @shared_by.empty?
      raise TaskCleanupError, "Task branch #{@branch} is shared by #{@shared_by.join(', ')}"
    end
    check("branch_ownership", true, "Task branch is not shared by another Task")

    validate_task_worktree_metadata
    if @branch_worktree
      raise TaskCleanupError, "cannot remove the current worktree #{@branch_worktree[:path]}" if same_path?(@branch_worktree[:path], @root)
      raise TaskCleanupError, "Task worktree is locked: #{@branch_worktree[:path]}" if @branch_worktree[:locked]
      if @branch_worktree[:prunable]
        check("worktree", true, "stale Task worktree metadata is ready to prune")
      else
        dirty = !capture_git_at(@branch_worktree[:path], "status", "--porcelain").empty?
        raise TaskCleanupError, "Task worktree is dirty: #{@branch_worktree[:path]}" if dirty
        check("worktree", true, "registered Task worktree is clean")
      end
    else
      check("worktree", true, "no registered Task worktree uses #{@branch}")
    end
    validate_unpushed_commits
    resolve_merge_evidence
    validate_github_protection if @options[:delete_remote] && @remote_exists
    validate_project_policy
    check("cleanup_ready", true, "Task branch cleanup is ready")
  end

  def validate_canonical_task
    listing = capture_git("ls-tree", "-r", "--name-only", @canonical_ref, "--", ".ai_project/tasks")
    path = listing.lines.map(&:strip).find { |entry| File.basename(entry).start_with?(@task_id) }
    raise TaskCleanupError, "Task #{@task_id} is not present in #{@canonical_ref}" unless path
    text = capture_git("show", "#{@canonical_ref}:#{path}")
    data, = read_front_matter_text(text, "#{@canonical_ref}:#{path}")
    unless data["status"] == "done"
      raise TaskCleanupError, "canonical Task status must be done; got #{data['status']}"
    end
  end

  def validate_recorded_canonical
    runtime = File.join(@target, ".ai_project", ".runtime", "status_ref")
    unless File.file?(runtime)
      check("canonical_cache", true, "no recorded canonical cache; resolved #{@canonical_ref} directly")
      return
    end
    recorded = File.readlines(runtime).find { |line| line.start_with?("status_ref_sha:") }.to_s.split(":", 2).last.to_s.strip
    if !recorded.empty? && recorded != @canonical_sha
      raise TaskCleanupError, "recorded canonical status is stale; run aiops sync-status"
    end
    check("canonical_cache", true, "recorded canonical SHA is current")
  end

  def validate_runtime_cache_policy
    probe = ".ai_project/.runtime/task_cleanup/#{@task_id}-cleanup-receipt.json"
    _output, _error, status = Open3.capture3("git", "-C", @target, "check-ignore", "--quiet", "--", probe)
    unless status.success?
      raise TaskCleanupError, ".ai_project/.runtime must be Git-ignored before task cleanup"
    end
    check("runtime_cache", true, "cleanup receipt path is Git-ignored")
  end

  def validate_task_worktree_metadata
    if @branch_worktree && !@task_worktree
      raise TaskCleanupError, "Task branch has a linked worktree but Task worktree_path is not recorded"
    end
    return unless @task_worktree
    registered = @worktrees.find { |entry| same_path?(entry[:path], @task_worktree) }
    if registered && registered[:branch] != @local_ref
      raise TaskCleanupError, "Task worktree_path belongs to another branch: #{@task_worktree}"
    end
    if @branch_worktree && !same_path?(@branch_worktree[:path], @task_worktree)
      raise TaskCleanupError, "Task worktree_path does not match the registered Task branch worktree"
    end
    if File.exist?(@task_worktree) && !registered
      raise TaskCleanupError, "Task worktree_path exists but is not registered: #{@task_worktree}"
    end
    check("worktree_metadata", true, "Task worktree metadata is consistent")
  end

  def validate_unpushed_commits
    if @local_exists && @remote_exists
      ahead = capture_git("rev-list", "--count", "#{@remote_ref}..#{@local_ref}").strip.to_i
      raise TaskCleanupError, "Task branch has #{ahead} unpushed commit(s)" if ahead.positive?
      unless @local_sha == @remote_sha
        raise TaskCleanupError, "local and remote Task branch tips differ; synchronize or review the branch before cleanup"
      end
    end
    check("unpushed_commits", true, "no unpushed Task branch commits")
  end

  def resolve_merge_evidence
    refs = [(@local_ref if @local_exists), (@remote_ref if @remote_exists)].compact
    if refs.empty?
      @merge_evidence = { "method" => "already_clean", "verified" => true }
      check("merge", true, "Task branch is already absent")
      return
    end

    if refs.all? { |ref| ancestor?(ref, @canonical_ref) }
      @merge_evidence = {
        "method" => "git_ancestor",
        "verified" => true,
        "canonical_ref" => @canonical_ref,
        "canonical_sha" => @canonical_sha
      }
      check("merge", true, "Task branch is included in #{@canonical_ref}")
      return
    end

    target_shas = [@local_sha, @remote_sha].compact.uniq
    raise TaskCleanupError, "local and remote Task branch tips differ; synchronize or review the branch before cleanup" unless target_shas.length == 1
    pr = merged_pull_request(target_shas.first)
    raise TaskCleanupError, "Task branch is not included in #{@canonical_ref} and no matching merged PR was found" unless pr
    merge_commit = pr["merge_commit"].to_s
    unless merge_commit.match?(/\A[0-9a-f]{40}\z/) && commit_exists?(merge_commit) && ancestor?(merge_commit, @canonical_ref)
      raise TaskCleanupError, "merged PR commit is not present in #{@canonical_ref}; refresh canonical status"
    end
    @merge_evidence = {
      "method" => "github_pull_request",
      "verified" => true,
      "canonical_ref" => @canonical_ref,
      "canonical_sha" => @canonical_sha,
      "pull_request" => pr
    }
    check("merge", true, "merged PR ##{pr['number']} verifies squash/rebase integration")
  end

  def validate_github_protection
    unless @repository
      check("github_protection", true, "remote is not GitHub; local protected-branch policy applied")
      return
    end
    raise TaskCleanupError, "cannot verify GitHub branch protection for #{@branch}" unless command_available?("gh")
    encoded = URI.encode_www_form_component(@branch)
    rules_output, rules_error, rules_status = Open3.capture3("gh", "api", "repos/#{@repository}/rules/branches/#{encoded}")
    if rules_status.success?
      rules = JSON.parse(rules_output)
      raise TaskCleanupError, "invalid GitHub branch rules response" unless rules.is_a?(Array)
      if rules.any? { |rule| rule.is_a?(Hash) && rule["type"] == "deletion" }
        raise TaskCleanupError, "refusing to delete GitHub protected branch #{@branch}"
      end
    elsif !not_found_response?(rules_error)
      raise TaskCleanupError, "cannot verify GitHub branch rules for #{@branch}: #{rules_error.lines.first.to_s.strip}"
    end
    _out, error, status = Open3.capture3("gh", "api", "repos/#{@repository}/branches/#{encoded}/protection")
    if status.success?
      raise TaskCleanupError, "refusing to delete GitHub protected branch #{@branch}"
    end
    unless not_found_response?(error)
      raise TaskCleanupError, "cannot verify GitHub branch protection for #{@branch}: #{error.lines.first.to_s.strip}"
    end
    check("github_protection", true, "remote Task branch is not protected")
  end

  def validate_project_policy
    if @project_delete_policy == false
      raise TaskCleanupError, "project policy disables delete_branch_after_merge"
    end
    message = if @project_delete_policy == true
                "project policy permits post-merge cleanup; --apply is still required"
              elsif @options[:apply]
                "cleanup explicitly approved by --apply"
              else
                "cleanup requires explicit --apply"
              end
    check("approval", true, message)
  end

  def build_plan
    worktree_path = @branch_worktree && @branch_worktree[:path]
    remove_status = worktree_path && !@branch_worktree[:prunable] ? "planned" : "skipped"
    remove_detail = if worktree_path && @branch_worktree[:prunable]
                      "stale worktree path will be pruned"
                    else
                      worktree_path || "no registered Task worktree"
                    end
    add_action("remove_worktree", remove_status, remove_detail)
    add_action("delete_local_branch", @local_exists ? "planned" : "skipped", @local_exists ? @branch : "local branch already absent")
    remote_status = if !@options[:delete_remote]
                      "skipped"
                    elsif @remote_exists
                      "planned"
                    else
                      "skipped"
                    end
    remote_detail = if !@options[:delete_remote]
                      "remote deletion not requested"
                    elsif @remote_exists
                      "#{@remote}/#{@branch}"
                    else
                      "remote branch already absent"
                    end
    add_action("delete_remote_branch", remote_status, remote_detail)
    add_action("prune_worktrees", worktree_path ? "planned" : "skipped", worktree_path ? "prune stale worktree metadata" : "no worktree removal planned")
    add_action("write_receipt", "planned", @receipt_relative)

    @plan = {
      "schema" => "aiops.task_cleanup_plan.v1",
      "generated_at" => Time.now.utc.iso8601,
      "task_id" => @task_id,
      "check_only" => @options[:check],
      "ready" => true,
      "actor" => @options[:actor],
      "canonical" => { "ref" => @canonical_ref, "sha" => @canonical_sha, "task_status" => "done" },
      "branch" => {
        "name" => @branch,
        "local_exists" => @local_exists,
        "remote" => @remote,
        "remote_exists" => @remote_exists,
        "shared_by" => @shared_by
      },
      "worktree" => {
        "path" => worktree_path,
        "registered" => !worktree_path.nil?,
        "current" => worktree_path ? same_path?(worktree_path, @root) : false,
        "dirty" => false,
        "locked" => @branch_worktree ? @branch_worktree[:locked] : false,
        "prunable" => @branch_worktree ? @branch_worktree[:prunable] : false
      },
      "merge_evidence" => @merge_evidence,
      "approval" => {
        "source" => if @project_delete_policy == true
                      "project_policy"
                    elsif @options[:apply]
                      "explicit_command"
                    else
                      "manual_apply_required"
                    end,
        "delete_remote_requested" => @options[:delete_remote]
      },
      "checks" => @checks,
      "actions" => @actions,
      "receipt_path" => @receipt_relative
    }
  end

  def apply_cleanup
    prepare_receipt_store
    existing = read_existing_receipt
    no_cleanup_actions = @actions.none? { |action| action["status"] == "planned" && action["action"] != "write_receipt" }
    if existing && existing["result"] == "complete" && no_cleanup_actions
      render(existing)
      return
    end

    results = []
    begin
      pruned_early = false
      if @branch_worktree && @branch_worktree[:prunable]
        run_git("worktree", "prune")
        pruned_early = true
        results << action_result("remove_worktree", "skipped", "stale worktree path pruned")
      elsif @branch_worktree
        run_git("worktree", "remove", "--", @branch_worktree[:path])
        results << action_result("remove_worktree", "complete", @branch_worktree[:path])
      else
        results << action_result("remove_worktree", "skipped", "no registered Task worktree")
      end

      if @local_exists
        current_local_sha = capture_git("rev-parse", "#{@local_ref}^{commit}").strip
        raise TaskCleanupError, "Task branch changed after cleanup check; retry" unless current_local_sha == @local_sha
        flag = @merge_evidence["method"] == "git_ancestor" ? "-d" : "-D"
        run_git("branch", flag, "--", @branch)
        results << action_result("delete_local_branch", "complete", @branch)
      else
        results << action_result("delete_local_branch", "skipped", "local branch already absent")
      end

      if @options[:delete_remote] && @remote_exists
        run_git(
          "push",
          "--force-with-lease=refs/heads/#{@branch}:#{@remote_sha}",
          @remote,
          ":refs/heads/#{@branch}"
        )
        results << action_result("delete_remote_branch", "complete", "#{@remote}/#{@branch}")
      else
        detail = @options[:delete_remote] ? "remote branch already absent" : "remote deletion not requested"
        results << action_result("delete_remote_branch", "skipped", detail)
      end

      if @branch_worktree
        run_git("worktree", "prune") unless pruned_early
        results << action_result("prune_worktrees", "complete", "stale metadata pruned")
      else
        results << action_result("prune_worktrees", "skipped", "no worktree removal required")
      end

      receipt = build_receipt("complete", results, [])
      write_receipt(receipt)
      render(receipt)
    rescue TaskCleanupError => error
      receipt = build_receipt(results.empty? ? "blocked" : "partial", results, [error.message])
      write_receipt(receipt)
      render(receipt) if @options[:json]
      raise
    end
  end

  def build_receipt(result, actions, blockers)
    now = Time.now.utc.iso8601
    existing = read_existing_receipt
    {
      "schema" => "aiops.task_cleanup_receipt.v1",
      "task_id" => @task_id,
      "actor" => @options[:actor],
      "canonical" => { "ref" => @canonical_ref, "sha" => @canonical_sha },
      "branch" => { "name" => @branch, "remote" => @remote },
      "worktree_path" => @branch_worktree && @branch_worktree[:path],
      "merge_evidence" => @merge_evidence,
      "actions" => actions,
      "result" => result,
      "blockers" => blockers,
      "created_at" => existing&.fetch("created_at", nil) || now,
      "updated_at" => now
    }
  end

  def write_receipt(receipt)
    FileUtils.mkdir_p(File.dirname(@receipt_path))
    temporary = "#{@receipt_path}.#{Process.pid}.tmp"
    File.open(temporary, "wb", 0o600) { |file| file.write(JSON.pretty_generate(receipt) + "\n") }
    File.rename(temporary, @receipt_path)
  ensure
    FileUtils.rm_f(temporary) if defined?(temporary) && temporary
  end

  def prepare_receipt_store
    FileUtils.mkdir_p(File.dirname(@receipt_path))
    probe = "#{@receipt_path}.#{Process.pid}.probe"
    File.open(probe, "wb", 0o600) { |file| file.write("ready\n") }
  ensure
    FileUtils.rm_f(probe) if defined?(probe) && probe
  end

  def read_existing_receipt
    return nil unless File.file?(@receipt_path)
    JSON.parse(File.read(@receipt_path))
  rescue JSON::ParserError
    nil
  end

  def render(data)
    if @options[:json]
      puts JSON.pretty_generate(data)
      return
    end
    if data["schema"] == "aiops.task_cleanup_plan.v1"
      puts "AI Ops task close plan"
      puts "task: #{data['task_id']}"
      puts "canonical: #{data.dig('canonical', 'ref')} @ #{data.dig('canonical', 'sha')[0, 12]}"
      puts "branch: #{data.dig('branch', 'name')}"
      puts "merge: #{data.dig('merge_evidence', 'method')}"
      data["actions"].each { |action| puts "#{action['status']}: #{action['action']} - #{action['detail']}" }
      puts "ready: yes"
    else
      puts "AI Ops task close"
      puts "task: #{data['task_id']}"
      puts "result: #{data['result']}"
      data["actions"].each { |action| puts "#{action['result']}: #{action['action']} - #{action['detail']}" }
      puts "receipt: #{@receipt_relative}"
    end
  end

  def read_front_matter(path)
    read_front_matter_text(File.read(path), relative(path))
  end

  def read_front_matter_text(text, label)
    raise TaskCleanupError, "YAML front matter required: #{label}" unless text.start_with?("---\n")
    lines = text.lines
    closing = lines[1..]&.find_index { |line| line.strip == "---" }
    raise TaskCleanupError, "YAML front matter closing marker missing: #{label}" unless closing
    closing += 1
    data = YAML.safe_load(lines[1...closing].join, permitted_classes: [Date, Time, Symbol], aliases: true)
    raise TaskCleanupError, "front matter must be an object: #{label}" unless data.is_a?(Hash)
    [data, lines[(closing + 1)..]&.join.to_s]
  end

  def read_optional_front_matter(path)
    return {} unless File.file?(path)
    read_front_matter(path).first
  end

  def read_optional_text(path)
    File.file?(path) ? File.read(path) : ""
  end

  def canonical_ref
    value = @operating_model["canonical_status_ref"]
    value = value["ref"] if value.is_a?(Hash)
    value = value.to_s.strip
    if value.empty?
      value = @strategy_text[/^\s*canonical_status_ref:\s*([^\s#]+)/, 1].to_s.strip
    end
    value
  end

  def delete_branch_policy
    value = @strategy_text[/^\s*delete_branch_after_merge:\s*(true|false)\s*$/i, 1]
    return nil unless value
    value.downcase == "true"
  end

  def protected_branches
    configured = @strategy_text.scan(/^\s*(?:base_branch|default_branch):\s*([^\s#]+)/).flatten
    (PROTECTED_BRANCHES + configured + [@canonical_branch]).compact.uniq
  end

  def canonical_branch_name(ref)
    value = ref.sub(%r{\Arefs/remotes/}, "").sub(%r{\Arefs/heads/}, "")
    parts = value.split("/", 2)
    if value.start_with?("refs/") || parts.length == 1
      parts.last
    elsif remote_exists?(parts.first)
      parts.last
    else
      value
    end
  end

  def canonical_remote_name(ref)
    value = ref.sub(%r{\Arefs/remotes/}, "")
    candidate = value.split("/", 2).first
    remote_exists?(candidate) ? candidate : nil
  end

  def remote_exists?(name)
    return false if name.to_s.empty?
    capture_git("remote", "get-url", name, allow_failure: true) != nil
  end

  def validate_branch_name(branch)
    raise TaskCleanupError, "invalid Task branch name: #{branch}" unless branch.match?(SAFE_REF_NAME)
    _out, _error, status = Open3.capture3("git", "check-ref-format", "--branch", branch)
    raise TaskCleanupError, "invalid Task branch name: #{branch}" unless status.success?
  end

  def validate_canonical_ref_name(ref)
    raise TaskCleanupError, "invalid canonical_status_ref: #{ref}" unless ref.match?(SAFE_REF_NAME)
  end

  def ensure_git_repository
    _out, _error, status = Open3.capture3("git", "-C", @target, "rev-parse", "--git-dir")
    raise TaskCleanupError, "task close requires a Git worktree" unless status.success?
  end

  def ref_exists?(ref)
    _out, _error, status = Open3.capture3("git", "-C", @target, "show-ref", "--verify", "--quiet", ref)
    status.success?
  end

  def commit_exists?(sha)
    _out, _error, status = Open3.capture3("git", "-C", @target, "cat-file", "-e", "#{sha}^{commit}")
    status.success?
  end

  def ancestor?(left, right)
    _out, _error, status = Open3.capture3("git", "-C", @target, "merge-base", "--is-ancestor", left, right)
    status.success?
  end

  def parse_worktrees
    output = capture_git("worktree", "list", "--porcelain")
    entries = []
    current = nil
    output.each_line do |line|
      line = line.chomp
      if line.start_with?("worktree ")
        entries << current if current
        current = { path: line.delete_prefix("worktree "), branch: nil, locked: false, prunable: false }
      elsif current && line.start_with?("branch ")
        current[:branch] = line.delete_prefix("branch ")
      elsif current && line.start_with?("locked")
        current[:locked] = true
      elsif current && line.start_with?("prunable")
        current[:prunable] = true
      end
    end
    entries << current if current
    entries.compact
  end

  def shared_task_ids
    Dir.glob(File.join(@target, ".ai_project", "tasks", "**", "*.md")).sort.map do |path|
      data, = read_front_matter(path)
      next if data["id"] == @task_id
      task_branch = data["branch"]
      data["id"] if task_branch.is_a?(Hash) && task_branch["name"].to_s == @branch
    end.compact
  end

  def merged_pull_request(expected_head_sha)
    return nil unless @repository && command_available?("gh")
    output, _error, status = Open3.capture3(
      "gh", "pr", "list", "--repo", @repository, "--state", "merged", "--head", @branch,
      "--json", "number,url,headRefName,headRefOid,baseRefName,mergeCommit,mergedAt", "--limit", "20"
    )
    return nil unless status.success?
    items = JSON.parse(output)
    item = items.find do |entry|
      entry["headRefName"] == @branch &&
        entry["headRefOid"] == expected_head_sha &&
        entry["baseRefName"] == @canonical_branch &&
        !entry["mergedAt"].to_s.empty?
    end
    return nil unless item
    {
      "number" => item["number"],
      "url" => item["url"],
      "head" => item["headRefName"],
      "head_sha" => item["headRefOid"],
      "base" => item["baseRefName"],
      "merge_commit" => item.dig("mergeCommit", "oid"),
      "merged_at" => item["mergedAt"]
    }
  rescue JSON::ParserError
    nil
  end

  def github_repository
    return nil unless @remote
    url = capture_git("remote", "get-url", @remote, allow_failure: true).to_s.strip
    case url
    when %r{\Ahttps?://github\.com/([^/]+/[^/]+?)(?:\.git)?\z}
      Regexp.last_match(1)
    when %r{\Agit@github\.com:([^/]+/[^/]+?)(?:\.git)?\z}
      Regexp.last_match(1)
    end
  end

  def command_available?(name)
    ENV.fetch("PATH", "").split(File::PATH_SEPARATOR).any? { |dir| File.executable?(File.join(dir, name)) }
  end

  def not_found_response?(message)
    message.include?("404") || message.match?(/Not Found/i)
  end

  def run_git(*args)
    output, error, status = Open3.capture3("git", "-C", @target, *args)
    return output if status.success?
    detail = error.lines.first.to_s.strip
    raise TaskCleanupError, "git #{args.first} failed#{detail.empty? ? '' : ": #{detail}"}"
  end

  def capture_git(*args, allow_failure: false)
    output, error, status = Open3.capture3("git", "-C", @target, *args)
    return output if status.success?
    return nil if allow_failure
    detail = error.lines.first.to_s.strip
    raise TaskCleanupError, "git #{args.first} failed#{detail.empty? ? '' : ": #{detail}"}"
  end

  def capture_git_at(path, *args)
    output, error, status = Open3.capture3("git", "-C", path, *args)
    return output if status.success?
    raise TaskCleanupError, "cannot inspect Task worktree #{path}: #{error.lines.first.to_s.strip}"
  end

  def check(code, ready, message)
    @checks << { "code" => code, "ready" => ready, "message" => message }
  end

  def add_action(action, status, detail)
    @actions << { "action" => action, "status" => status, "detail" => detail }
  end

  def action_result(action, result, detail)
    { "action" => action, "result" => result, "detail" => detail }
  end

  def same_path?(left, right)
    canonical_path(left) == canonical_path(right)
  end

  def canonical_path(path)
    expanded = File.expand_path(path)
    return File.realpath(expanded) if File.exist?(expanded)

    suffix = []
    parent = expanded
    until File.exist?(parent) || parent == File.dirname(parent)
      suffix.unshift(File.basename(parent))
      parent = File.dirname(parent)
    end
    File.join(File.realpath(parent), *suffix)
  end

  def relative(path)
    Pathname.new(path).relative_path_from(Pathname.new(@target)).to_s
  rescue ArgumentError
    path
  end
end

TaskCleanup.new(ARGV).run

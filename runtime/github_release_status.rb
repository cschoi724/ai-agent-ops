#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"
require "open3"
require "optparse"

class GitHubReleaseStatus
  COMMAND_TIMEOUT = 10
  KILL_GRACE = 1
  REPOSITORY_PATTERN = /\A[A-Za-z0-9_.-]+\/[A-Za-z0-9_.-]+\z/

  def initialize(target:, repository: nil)
    @target = File.expand_path(target)
    @requested_repository = repository
  end

  def collect
    return unavailable("gh_missing", "GitHub CLI is not installed") unless command_available?("gh")

    auth = run_gh("auth", "status")
    return unavailable("auth_required", concise_error(auth, "GitHub CLI is not authenticated")) unless auth[:success]

    repository = resolve_repository
    return unavailable(repository[:code], repository[:reason]) unless repository[:success]

    branch = current_branch
    pull_request = collect_pull_request(repository[:name], branch)
    checks = collect_required_checks(repository[:name], pull_request)
    latest_run = collect_latest_run(repository[:name], branch)
    release = collect_release(repository[:name])
    sections = [pull_request, checks, latest_run, release]
    partial = sections.any? { |section| section.is_a?(Hash) && section["status"] == "unavailable" }

    {
      "status" => partial ? "partial" : "available",
      "reason_code" => partial ? "partial_data" : nil,
      "reason" => partial ? "Some GitHub release data could not be loaded" : nil,
      "repository" => {
        "name_with_owner" => repository[:name],
        "url" => repository[:url]
      },
      "branch" => branch,
      "pull_request" => pull_request,
      "required_checks" => checks,
      "latest_run" => latest_run,
      "release" => release
    }
  rescue StandardError => error
    unavailable("collector_error", "GitHub status could not be loaded: #{error.message}")
  end

  private

  def unavailable(code, reason)
    {
      "status" => "unavailable",
      "reason_code" => code,
      "reason" => reason,
      "repository" => nil,
      "branch" => current_branch,
      "pull_request" => {"status" => "unavailable"},
      "required_checks" => empty_checks("unavailable"),
      "latest_run" => {"status" => "unavailable"},
      "release" => empty_release("unavailable")
    }
  end

  def resolve_repository
    if @requested_repository
      return {success: false, code: "invalid_repository", reason: "Repository must use owner/name format"} unless @requested_repository.match?(REPOSITORY_PATTERN)

      return {success: true, name: @requested_repository, url: "https://github.com/#{@requested_repository}"}
    end

    response = run_gh("repo", "view", "--json", "nameWithOwner,url")
    return {success: false, code: "repository_unavailable", reason: concise_error(response, "GitHub repository could not be detected")} unless response[:success]

    data = parse_json_object(response[:stdout])
    name = data["nameWithOwner"].to_s
    return {success: false, code: "repository_unavailable", reason: "GitHub repository response did not include nameWithOwner"} unless name.match?(REPOSITORY_PATTERN)

    {success: true, name: name, url: data["url"]}
  rescue JSON::ParserError
    {success: false, code: "invalid_response", reason: "GitHub repository response was not valid JSON"}
  end

  def collect_pull_request(repository, branch)
    return {"status" => "not_applicable", "reason" => "Current branch could not be detected"} if branch.to_s.empty?

    response = run_gh(
      "pr", "list", "--repo", repository, "--head", branch, "--state", "open", "--limit", "1",
      "--json", "number,title,url,headRefName,baseRefName,isDraft,mergeable"
    )
    return {"status" => "unavailable", "reason" => concise_error(response, "Pull request status could not be loaded")} unless response[:success]

    item = parse_json_array(response[:stdout]).first
    return {"status" => "not_found"} unless item

    {
      "status" => "available",
      "number" => item["number"],
      "title" => item["title"],
      "url" => item["url"],
      "head_branch" => item["headRefName"],
      "base_branch" => item["baseRefName"],
      "draft" => item["isDraft"],
      "mergeable" => item["mergeable"]
    }
  rescue JSON::ParserError
    {"status" => "unavailable", "reason" => "Pull request response was not valid JSON"}
  end

  def collect_required_checks(repository, pull_request)
    return empty_checks("not_applicable") unless pull_request["status"] == "available"

    response = run_gh(
      "pr", "checks", pull_request.fetch("number").to_s, "--repo", repository, "--required",
      "--json", "name,state,bucket,link,workflow", acceptable: [0, 8]
    )
    return empty_checks("unavailable", concise_error(response, "Required checks could not be loaded")) unless response[:success]

    items = parse_json_array(response[:stdout]).map do |item|
      {
        "name" => item["name"],
        "state" => item["state"],
        "bucket" => item["bucket"],
        "url" => item["link"],
        "workflow" => item["workflow"]
      }
    end
    counts = items.each_with_object(Hash.new(0)) { |item, out| out[item["bucket"].to_s] += 1 }
    status = if items.empty?
               "not_found"
             elsif counts["fail"].positive? || counts["cancel"].positive?
               "failure"
             elsif counts["pending"].positive?
               "pending"
             else
               "success"
             end
    {
      "status" => status,
      "total" => items.length,
      "passing" => counts["pass"],
      "failing" => counts["fail"] + counts["cancel"],
      "pending" => counts["pending"],
      "skipping" => counts["skipping"],
      "items" => items
    }
  rescue JSON::ParserError
    empty_checks("unavailable", "Required checks response was not valid JSON")
  end

  def collect_latest_run(repository, branch)
    args = ["run", "list", "--repo", repository, "--limit", "1"]
    args.concat(["--branch", branch]) unless branch.to_s.empty?
    args.concat(["--json", "databaseId,workflowName,displayTitle,status,conclusion,url,headSha,createdAt,updatedAt,event"])
    response = run_gh(*args)
    return {"status" => "unavailable", "reason" => concise_error(response, "Latest workflow run could not be loaded")} unless response[:success]

    item = parse_json_array(response[:stdout]).first
    return {"status" => "not_found"} unless item

    {
      "status" => item["status"] || "unknown",
      "conclusion" => item["conclusion"],
      "database_id" => item["databaseId"],
      "workflow" => item["workflowName"],
      "title" => item["displayTitle"],
      "url" => item["url"],
      "head_sha" => item["headSha"],
      "created_at" => item["createdAt"],
      "updated_at" => item["updatedAt"],
      "event" => item["event"]
    }
  rescue JSON::ParserError
    {"status" => "unavailable", "reason" => "Latest workflow run response was not valid JSON"}
  end

  def collect_release(repository)
    local_version = read_local_version
    response = run_gh(
      "release", "view", "--repo", repository,
      "--json", "tagName,name,url,publishedAt,isDraft,isPrerelease,targetCommitish"
    )
    unless response[:success]
      message = concise_error(response, "Latest release could not be loaded")
      status = message.match?(/release not found|no releases found/i) ? "not_found" : "unavailable"
      return empty_release(status, status == "unavailable" ? message : nil, local_version: local_version)
    end

    item = parse_json_object(response[:stdout])
    tag = item["tagName"].to_s
    comparison = if local_version.to_s.empty?
                   "local_version_missing"
                 elsif normalize_version(tag) == normalize_version(local_version)
                   "match"
                 else
                   "different"
                 end
    {
      "status" => "available",
      "tag" => tag,
      "name" => item["name"],
      "url" => item["url"],
      "published_at" => item["publishedAt"],
      "draft" => item["isDraft"],
      "prerelease" => item["isPrerelease"],
      "target_commitish" => item["targetCommitish"],
      "local_version" => local_version,
      "version_state" => comparison
    }
  rescue JSON::ParserError
    empty_release("unavailable", "Latest release response was not valid JSON", local_version: local_version)
  end

  def empty_checks(status, reason = nil)
    {"status" => status, "total" => 0, "passing" => 0, "failing" => 0, "pending" => 0, "skipping" => 0, "items" => [], "reason" => reason}
  end

  def empty_release(status, reason = nil, local_version: read_local_version)
    {
      "status" => status,
      "tag" => nil,
      "local_version" => local_version,
      "version_state" => local_version.to_s.empty? ? "local_version_missing" : "release_missing",
      "reason" => reason
    }
  end

  def read_local_version
    path = File.join(@target, "VERSION")
    return nil unless File.file?(path)

    File.read(path).strip
  rescue SystemCallError
    nil
  end

  def normalize_version(value)
    value.to_s.strip.sub(/\Av/i, "")
  end

  def current_branch
    stdout, _stderr, status = Open3.capture3("git", "-C", @target, "branch", "--show-current")
    return nil unless status.success?

    branch = stdout.strip
    branch.empty? ? nil : branch
  rescue SystemCallError
    nil
  end

  def parse_json_object(text)
    value = JSON.parse(text)
    raise JSON::ParserError, "expected object" unless value.is_a?(Hash)

    value
  end

  def parse_json_array(text)
    value = JSON.parse(text)
    raise JSON::ParserError, "expected array" unless value.is_a?(Array)

    value
  end

  def concise_error(response, fallback)
    text = response[:stderr].to_s.strip
    text = response[:stdout].to_s.strip if text.empty?
    text.empty? ? fallback : text.lines.first.to_s.strip
  end

  def run_gh(*args, acceptable: [0])
    result = capture(["gh", *args])
    result[:success] = acceptable.include?(result[:exit_code])
    result
  rescue SystemCallError => error
    {success: false, exit_code: nil, stdout: "", stderr: error.message}
  end

  def capture(command)
    stdout_text = +""
    stderr_text = +""
    exit_code = nil
    timed_out = false

    Open3.popen3(*command, chdir: @target) do |stdin, stdout, stderr, wait_thread|
      stdin.close
      stdout_reader = Thread.new { stdout.read }
      stderr_reader = Thread.new { stderr.read }
      unless wait_thread.join(COMMAND_TIMEOUT)
        timed_out = true
        terminate_process(wait_thread)
      end
      status = wait_thread.value
      stdout_text = stdout_reader.value
      stderr_text = stderr_reader.value
      exit_code = status.exitstatus
    end

    stderr_text = "GitHub CLI request timed out" if timed_out
    {stdout: stdout_text, stderr: stderr_text, exit_code: exit_code, timed_out: timed_out}
  end

  def terminate_process(wait_thread)
    Process.kill("TERM", wait_thread.pid)
  rescue Errno::ESRCH
    return
  ensure
    unless wait_thread.join(KILL_GRACE)
      begin
        Process.kill("KILL", wait_thread.pid)
      rescue Errno::ESRCH
        nil
      end
      wait_thread.join
    end
  end

  def command_available?(name)
    ENV.fetch("PATH", "").split(File::PATH_SEPARATOR).any? do |directory|
      path = File.join(directory, name)
      File.file?(path) && File.executable?(path)
    end
  end
end

options = {target: Dir.pwd, repository: nil}
OptionParser.new do |parser|
  parser.on("--target DIR") { |value| options[:target] = value }
  parser.on("--repo OWNER/NAME") { |value| options[:repository] = value }
end.parse!

puts JSON.pretty_generate(GitHubReleaseStatus.new(**options).collect)

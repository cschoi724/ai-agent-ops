#!/usr/bin/env ruby
# frozen_string_literal: true

# AI Ops core guard: keeps the constitution folder (.ai/) read-only for agents.
#
#   guard.rb pre-tool-use [--provider claude-code|codex] [--target DIR] < hook-payload.json
#   guard.rb check-path PATH... [--target DIR]
#   guard.rb staged [--target DIR]
#   guard.rb install-git-hook [--target DIR] [--check]
#   guard.rb write-core-digest --core DIR
#   guard.rb verify-core [--target DIR] [--json]
#
# Exit codes: 0 allowed/ok, 2 blocked by pre-tool-use (Claude Code and Codex
# both treat exit 2 as a deny with stderr as the reason), 1 other failures.
# Shell-command inspection is best effort; git pre-commit and core integrity
# checks are the backstops.

require "digest"
require "fileutils"
require "find"
require "json"
require "open3"
require "optparse"
require "shellwords"

module AiopsGuard
  GIT_HOOK_MARKER = "# aiops-guard: protects .ai/ (managed by aiops guard install-git-hook)"
  DIGEST_FILE = ".aiops_core_digest"
  ALLOW_CORE_COMMIT_ENV = "AIOPS_ALLOW_CORE_COMMIT"

  WRITE_ANY_ARG = %w[rm rmdir unlink touch mkdir chmod chown chflags chgrp truncate tee shred mv].freeze
  WRITE_LAST_ARG = %w[cp install rsync ln scp].freeze
  INPLACE_EDITORS = %w[sed perl gsed].freeze
  INTERPRETERS = %w[python python3 ruby node perl bash sh zsh osascript].freeze
  GIT_WRITE_SUBCOMMANDS = %w[checkout restore rm mv clean reset apply stash am cherry-pick revert merge rebase pull commit switch].freeze
  WRAPPERS = %w[sudo env command nohup time xargs exec nice].freeze

  class Error < StandardError; end

  # Resolves the project root and the protected core locations for one target.
  class Project
    attr_reader :root

    def initialize(root)
      @root = File.expand_path(root)
    end

    def ai_path
      File.join(@root, ".ai")
    end

    def core_present?
      File.exist?(ai_path) || File.symlink?(ai_path)
    end

    def protected_roots
      roots = [ai_path]
      real = begin
        File.realpath(ai_path)
      rescue SystemCallError
        nil
      end
      roots << real if real && real != ai_path
      roots
    end

    def protected?(path, base = @root)
      return false unless core_present?

      candidate = File.expand_path(path.to_s, base)
      candidates = [candidate, resolve_existing(candidate)].compact.uniq
      protected_roots.any? do |root|
        candidates.any? { |item| item == root || item.start_with?("#{root}/") }
      end
    end

    private

    # Resolve symlinks in the deepest existing ancestor so aliases of .ai/ are caught.
    def resolve_existing(path)
      current = path
      suffix = []
      until File.exist?(current) || File.symlink?(current)
        parent = File.dirname(current)
        return nil if parent == current

        suffix.unshift(File.basename(current))
        current = parent
      end
      real = File.realpath(current)
      suffix.empty? ? real : File.join(real, *suffix)
    rescue SystemCallError
      nil
    end
  end

  # Decides whether one tool call would modify a protected path.
  class ToolCallInspector
    def initialize(project, cwd)
      @project = project
      @cwd = cwd && !cwd.empty? ? cwd : project.root
    end

    def blocked_reason(payload)
      input = payload["tool_input"].is_a?(Hash) ? payload["tool_input"] : {}
      %w[file_path notebook_path path].each do |key|
        value = input[key]
        next unless value.is_a?(String) && !value.empty?
        return "#{value} 는 AI Ops 헌법 폴더(.ai/) 안의 파일입니다." if protected?(value)
      end

      command = input["command"]
      command = command.join(" ") if command.is_a?(Array)
      return nil unless command.is_a?(String) && !command.empty?

      if command.include?("*** Begin Patch") || command.match?(/^\*\*\* (Add|Update|Delete) File: /)
        patch_reason(command)
      else
        shell_reason(command)
      end
    end

    private

    def protected?(path)
      @project.protected?(path, @cwd)
    end

    def patch_reason(text)
      text.each_line do |line|
        match = line.match(/\A\*\*\* (?:Add File|Update File|Delete File|Move to): (.+?)\s*\z/)
        next unless match
        return "patch가 AI Ops 헌법 폴더(.ai/)의 #{match[1]} 를 수정합니다." if protected?(match[1])
      end
      nil
    end

    def shell_reason(command)
      if command.include?(ALLOW_CORE_COMMIT_ENV)
        return "#{ALLOW_CORE_COMMIT_ENV} 는 Owner(사용자)만 사용할 수 있습니다."
      end

      segments(command).each do |segment|
        reason = segment_reason(segment)
        return reason if reason
      end
      nil
    end

    def segments(command)
      command.split(/(?:&&|\|\||[;|\n&])/).map(&:strip).reject(&:empty?)
    end

    def tokenize(segment)
      Shellwords.split(segment)
    rescue ArgumentError
      segment.split(/\s+/)
    end

    def segment_reason(segment)
      tokens = tokenize(segment)
      redirect_reason(tokens) || command_reason(tokens)
    end

    def redirect_reason(tokens)
      tokens.each_with_index do |token, index|
        target = if token.match?(/\A\d*>>?\z/) || token == "&>"
                   tokens[index + 1]
                 elsif (match = token.match(/\A\d*>>?(.+)\z/)) || (match = token.match(/\A&>(.+)\z/))
                   match[1]
                 end
        next unless target && !target.start_with?("&")
        return "출력 리다이렉션이 AI Ops 헌법 폴더(.ai/)의 #{target} 를 덮어씁니다." if protected?(target)
      end
      nil
    end

    def command_reason(tokens)
      tokens = strip_wrappers(tokens)
      return nil if tokens.empty?

      name = File.basename(tokens.first)
      args = tokens[1..-1].reject { |arg| arg.match?(/\A\d*>>?/) || arg.start_with?("&>") }
      operands = args.reject { |arg| arg.start_with?("-") }

      if name == "aiops" || tokens.first.end_with?("/bin/aiops")
        return aiops_reason(args)
      end
      if WRITE_ANY_ARG.include?(name)
        hit = operands.find { |arg| protected?(arg) }
        return "#{name} 명령이 AI Ops 헌법 폴더(.ai/)의 #{hit} 를 변경합니다." if hit
      end
      if WRITE_LAST_ARG.include?(name) && operands.any? && protected?(operands.last)
        return "#{name} 명령이 AI Ops 헌법 폴더(.ai/)에 씁니다."
      end
      if INPLACE_EDITORS.include?(name) && args.any? { |arg| arg.match?(/\A-[a-zA-Z]*i/) }
        hit = operands.find { |arg| protected?(arg) }
        return "#{name} -i 가 AI Ops 헌법 폴더(.ai/)의 #{hit} 를 수정합니다." if hit
      end
      if name == "dd"
        hit = args.map { |arg| arg[/\Aof=(.+)\z/, 1] }.compact.find { |arg| protected?(arg) }
        return "dd 가 AI Ops 헌법 폴더(.ai/)에 씁니다." if hit
      end
      return git_reason(args) if name == "git"
      if INTERPRETERS.include?(name) && args.any? { |arg| references_protected?(arg) }
        return "스크립트 실행이 AI Ops 헌법 폴더(.ai/)를 대상으로 합니다. 읽기는 cat, grep 같은 읽기 명령을 사용하세요."
      end
      nil
    end

    def strip_wrappers(tokens)
      tokens = tokens.dup
      loop do
        tokens.shift while tokens.first&.match?(/\A[A-Za-z_][A-Za-z0-9_]*=/)
        break unless tokens.first && WRAPPERS.include?(File.basename(tokens.first))

        tokens.shift
        tokens.shift while tokens.first&.start_with?("-")
      end
      tokens
    end

    def aiops_reason(args)
      sub = args.reject { |arg| arg.start_with?("-") }.first
      return "aiops update 는 core(.ai/)를 바꾸므로 Owner(사용자)가 직접 실행해야 합니다." if sub == "update" && !args.include?("--check")
      return "aiops seed --force 는 core(.ai/)를 다시 만들므로 Owner(사용자)가 직접 실행해야 합니다." if sub == "seed" && args.include?("--force")

      nil
    end

    def git_reason(args)
      index = 0
      git_dir_protected = false
      while index < args.length && args[index].start_with?("-")
        if %w[-C --git-dir --work-tree].include?(args[index])
          git_dir_protected ||= protected?(args[index + 1].to_s)
          index += 2
        elsif (match = args[index].match(/\A--(?:git-dir|work-tree)=(.+)\z/))
          git_dir_protected ||= protected?(match[1])
          index += 1
        else
          index += 1
        end
      end
      sub = args[index]
      return nil unless GIT_WRITE_SUBCOMMANDS.include?(sub) || (git_dir_protected && %w[push tag branch].include?(sub))
      return "git #{sub} 가 AI Ops core 저장소(.ai/)를 변경합니다." if git_dir_protected

      hit = args[(index + 1)..-1].to_a.reject { |arg| arg.start_with?("-") }.find { |arg| protected?(arg) }
      hit ? "git #{sub} 가 AI Ops 헌법 폴더(.ai/)의 #{hit} 를 변경합니다." : nil
    end

    def references_protected?(text)
      return true if protected?(text)

      text.scan(%r{(?:\A|[\s'"=(:,])((?:\.{1,2}/|/)?[^\s'"=(:,;]*\.ai(?:/[^\s'";,)]*)?)}).flatten.any? do |candidate|
        File.basename(candidate) == ".ai" || candidate.include?(".ai/") ? protected?(candidate) : false
      end
    end
  end

  # Digest of a copied core so later edits are detectable.
  module CoreDigest
    module_function

    def compute(core)
      digest = Digest::SHA256.new
      files = []
      Find.find(core) do |path|
        name = File.basename(path)
        if File.directory?(path) && (name == ".git" || name == ".ai_project")
          Find.prune
        end
        next unless File.file?(path)
        next if name == DIGEST_FILE || name == ".DS_Store"

        files << path.delete_prefix("#{core}/")
      end
      files.sort.each do |relative|
        digest << relative << "\0" << File.binread(File.join(core, relative)) << "\0"
      end
      digest.hexdigest
    end
  end

  def self.core_state(project)
    ai = project.ai_path
    return { "state" => "missing", "mode" => "none", "detail" => ".ai/ not found" } unless project.core_present?

    mode = File.symlink?(ai) ? "link" : "copy"
    core = File.realpath(ai)
    digest_path = File.join(core, DIGEST_FILE)
    if File.file?(digest_path)
      expected = File.read(digest_path).strip
      actual = CoreDigest.compute(core)
      return { "state" => "ok", "mode" => mode, "detail" => "core digest matches" } if expected == actual

      return { "state" => "modified", "mode" => mode, "detail" => "core files differ from the recorded digest; restore .ai/ or reseed from an approved core" }
    end
    if File.directory?(File.join(core, ".git"))
      out, _err, status = Open3.capture3("git", "-C", core, "status", "--porcelain", "--untracked-files=no")
      if status.success? && !out.strip.empty?
        return { "state" => "uncommitted", "mode" => mode, "detail" => "core git checkout has uncommitted changes (expected only while developing ai-agent-ops)" }
      end
      return { "state" => "ok", "mode" => mode, "detail" => "core git checkout is clean" }
    end
    { "state" => "unverified", "mode" => mode, "detail" => "no core digest recorded; reseed or reinstall to enable integrity checks" }
  end

  class CLI
    def initialize(argv)
      @argv = argv.dup
      @action = @argv.shift
      @options = { target: Dir.pwd, provider: nil, check: false, json: false, core: nil }
    end

    def run
      case @action
      when "pre-tool-use" then pre_tool_use
      when "check-path" then check_path
      when "staged" then staged
      when "install-git-hook" then install_git_hook
      when "write-core-digest" then write_core_digest
      when "verify-core" then verify_core
      when nil, "-h", "--help", "help" then usage(0)
      else raise Error, "unknown guard action: #{@action}"
      end
    rescue Error, OptionParser::ParseError => e
      warn "aiops guard: #{e.message}"
      1
    end

    private

    def parse!
      parser = OptionParser.new do |opts|
        opts.on("--target DIR") { |value| @options[:target] = value }
        opts.on("--provider NAME") { |value| @options[:provider] = value }
        opts.on("--core DIR") { |value| @options[:core] = value }
        opts.on("--check") { @options[:check] = true }
        opts.on("--json") { @options[:json] = true }
      end
      parser.parse!(@argv)
    end

    def usage(code)
      puts <<~TEXT
        aiops guard - protect the AI Ops constitution folder (.ai/)

        Usage:
          aiops guard pre-tool-use [--provider claude-code|codex] [--target DIR] < hook-payload.json
          aiops guard check-path PATH... [--target DIR]
          aiops guard staged [--target DIR]
          aiops guard install-git-hook [--target DIR] [--check]
          aiops guard verify-core [--target DIR] [--json]
      TEXT
      code
    end

    def project_for(payload_cwd = nil)
      root = ENV["CLAUDE_PROJECT_DIR"].to_s
      root = git_toplevel(payload_cwd) if root.empty? && payload_cwd
      root = @options[:target] if root.to_s.empty?
      Project.new(root)
    end

    def git_toplevel(dir)
      return nil unless dir && Dir.exist?(dir)

      out, _err, status = Open3.capture3("git", "-C", dir, "rev-parse", "--show-toplevel")
      status.success? ? out.strip : nil
    end

    def pre_tool_use
      parse!
      raw = STDIN.read.to_s
      payload = raw.strip.empty? ? {} : JSON.parse(raw)
      raise Error, "hook payload must be a JSON object" unless payload.is_a?(Hash)

      cwd = payload["cwd"].to_s
      cwd = Dir.pwd if cwd.empty?
      project = @options[:target] != Dir.pwd ? Project.new(@options[:target]) : project_for(cwd)
      reason = ToolCallInspector.new(project, cwd).blocked_reason(payload)
      return 0 unless reason

      warn "AI Ops 차단: #{reason}"
      warn ".ai/ 는 수정할 수 없습니다. core 변경이 필요하면 작업을 멈추고 Owner(사용자)에게 알리세요."
      2
    rescue JSON::ParserError => e
      raise Error, "invalid hook payload: #{e.message}"
    end

    def check_path
      parse!
      raise Error, "check-path requires at least one PATH" if @argv.empty?

      project = Project.new(@options[:target])
      blocked = @argv.select { |path| project.protected?(path, project.root) }
      blocked.each { |path| puts "protected: #{path}" }
      (@argv - blocked).each { |path| puts "allowed: #{path}" }
      blocked.empty? ? 0 : 2
    end

    def staged
      parse!
      root = git_toplevel(@options[:target]) || raise(Error, "not a git repository: #{@options[:target]}")
      out, err, status = Open3.capture3("git", "-C", root, "diff", "--cached", "--name-only", "--no-renames", "-z")
      raise Error, "git diff --cached failed: #{err.strip}" unless status.success?

      hits = out.split("\0").select { |path| path == ".ai" || path.start_with?(".ai/") }
      return 0 if hits.empty?

      if ENV[ALLOW_CORE_COMMIT_ENV] == "1"
        warn "aiops guard: #{ALLOW_CORE_COMMIT_ENV}=1 set; allowing staged .ai/ changes (Owner override)"
        return 0
      end
      warn "AI Ops 차단: 커밋에 AI Ops 헌법 폴더(.ai/) 변경이 포함되어 있습니다."
      hits.first(10).each { |path| warn "  - #{path}" }
      warn "core 변경은 Owner(사용자)만 승인할 수 있습니다. 의도한 core 갱신이면 Owner가 #{ALLOW_CORE_COMMIT_ENV}=1 git commit 으로 커밋하세요."
      1
    end

    def hooks_dir(root)
      out, err, status = Open3.capture3("git", "-C", root, "rev-parse", "--git-path", "hooks")
      raise Error, "cannot resolve git hooks path: #{err.strip}" unless status.success?

      File.expand_path(out.strip, root)
    end

    def git_hook_script
      <<~SH
        #!/bin/sh
        #{GIT_HOOK_MARKER}
        root="$(git rev-parse --show-toplevel)" || exit 1
        if [ -x "$root/.ai/bin/aiops" ]; then
          "$root/.ai/bin/aiops" guard staged --target "$root" || exit 1
        fi
      SH
    end

    def install_git_hook
      parse!
      root = git_toplevel(@options[:target])
      unless root
        puts "note: not a git repository; pre-commit guard skipped"
        return 0
      end
      path = File.join(hooks_dir(root), "pre-commit")
      current = File.file?(path) ? File.read(path) : nil
      if current == git_hook_script
        puts "ok: pre-commit guard installed"
        return 0
      end
      if current && !current.include?(GIT_HOOK_MARKER)
        puts "needs_user_decision: existing pre-commit hook at #{path}; add this line to keep .ai/ protected:"
        puts "  \"$(git rev-parse --show-toplevel)/.ai/bin/aiops\" guard staged || exit 1"
        return 0
      end
      if @options[:check]
        puts current ? "warn: pre-commit guard outdated" : "warn: pre-commit guard missing"
        return 0
      end
      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, git_hook_script)
      File.chmod(0o755, path)
      puts "#{current ? 'updated' : 'created'}: pre-commit guard #{path}"
      0
    end

    def write_core_digest
      parse!
      core = @options[:core] || raise(Error, "write-core-digest requires --core DIR")
      core = File.expand_path(core)
      File.write(File.join(core, DIGEST_FILE), "#{CoreDigest.compute(core)}\n")
      0
    end

    def verify_core
      parse!
      project = Project.new(@options[:target])
      result = AiopsGuard.core_state(project)
      if @options[:json]
        puts JSON.pretty_generate(result)
      else
        puts "core_integrity: #{result['state']}"
        puts "mode: #{result['mode']}"
        puts "detail: #{result['detail']}"
      end
      result["state"] == "modified" ? 1 : 0
    end
  end
end

exit AiopsGuard::CLI.new(ARGV).run if $PROGRAM_NAME == __FILE__

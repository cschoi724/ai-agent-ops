#!/usr/bin/env ruby
# frozen_string_literal: true

# AI Ops core guard: keeps the constitution folder (.ai/), the Owner-only
# project files, transition receipts and git hooks read-only for agents.
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

  OWNER_APPROVED_FLAG = "--owner-approved"

  WRITE_ANY_ARG = %w[rm rmdir unlink touch mkdir chmod chown chflags chgrp truncate tee shred mv].freeze
  WRITE_LAST_ARG = %w[cp install rsync ln scp ditto].freeze
  RECURSIVE_WRITERS = %w[rm chmod chown chflags chgrp].freeze
  INPLACE_EDITORS = %w[sed perl gsed].freeze
  SHELLS = %w[bash sh zsh dash ksh].freeze
  INTERPRETERS = %w[python python3 ruby node perl osascript].freeze
  GIT_WRITE_SUBCOMMANDS = %w[checkout restore rm mv clean reset apply stash am cherry-pick revert merge rebase pull commit switch].freeze
  GIT_HOOKED_SUBCOMMANDS = %w[commit merge am].freeze
  WRAPPERS = %w[sudo env command nohup time xargs exec nice].freeze
  SEARCH_COMMANDS = %w[grep egrep fgrep rg ag ack].freeze
  READ_COMMANDS = (SEARCH_COMMANDS + %w[cat less more head tail]).freeze
  FIND_ACTIONS = %w[-delete -exec -execdir -ok -okdir -fprint -fprint0 -fprintf -fls].freeze
  MAX_SHELL_DEPTH = 6
  MAX_SCRIPT_BYTES = 1_000_000

  # Files under the project root that agents must not change directly.
  # The Owner edits them by hand; aiops commands write receipts.
  STRUCTURE_FILES = %w[.ai_project/agent_registry.md .ai_project/operating_model.md].freeze
  STRUCTURE_UNLOCK_FILE = "structure_edit_until"
  RECEIPT_PATTERN = %r{\A\.ai_project/reports/[^/]+-transition-receipt\.json\z}i.freeze

  LABELS = {
    core: "AI Ops 헌법 폴더(.ai/)",
    structure: "Owner 전용 파일(Agent Registry·운영 모델)",
    receipt: "aiops가 기록하는 transition receipt",
    git: "git hook·설정"
  }.freeze

  class Error < StandardError; end

  # Resolves the project root and the protected locations for one target.
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

    def aiops_project?
      core_present? || File.directory?(File.join(@root, ".ai_project"))
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

    # Returns the protection kind (:core, :structure, :receipt, :git) or nil.
    def protection(path, base = @root)
      return nil unless aiops_project?

      candidates = candidates_for(path, base)
      if core_present? && protected_roots.any? { |root| candidates.any? { |item| item == root || item.start_with?("#{root}/") } }
        return :core
      end

      candidates.each do |item|
        return :git if git_protected?(item)

        relative = relative_to_root(item)
        next unless relative

        lowered = relative.downcase
        # Bootstrap creates these files; changing an existing one needs the Owner's unlock.
        return :structure if STRUCTURE_FILES.include?(lowered) && File.exist?(item) && !structure_edit_allowed?
        return :receipt if lowered.match?(RECEIPT_PATTERN)
      end
      nil
    end

    # Shared git directory (the main repository's .git for linked worktrees).
    def git_common_dir
      return @git_common_dir if defined?(@git_common_dir)

      @git_common_dir = nil
      return nil unless File.exist?(File.join(@root, ".git"))

      out, _err, status = Open3.capture3("git", "-C", @root, "rev-parse", "--git-common-dir")
      @git_common_dir = File.expand_path(out.strip, @root) if status.success? && !out.strip.empty?
    rescue SystemCallError
      @git_common_dir = nil
    end

    def structure_unlock_path
      dir = git_common_dir
      dir ? File.join(dir, "aiops", STRUCTURE_UNLOCK_FILE) : nil
    end

    def structure_edit_allowed?
      path = structure_unlock_path
      return false unless path && File.file?(path)

      Time.now.to_i < Integer(File.read(path).strip)
    rescue ArgumentError, SystemCallError
      false
    end

    def protected?(path, base = @root)
      !protection(path, base).nil?
    end

    # True when a recursive operation on path would reach into a copied (real) .ai/ directory.
    def covers_core?(path, base = @root, follow_links: false)
      return false unless core_present?
      return false if File.symlink?(ai_path) && !follow_links

      candidates_for(path, base).any? { |item| ai_path.start_with?("#{item.chomp('/')}/") }
    end

    private

    def git_dirs
      dirs = [File.join(@root, ".git")]
      dirs << git_common_dir if git_common_dir
      dirs.flat_map do |dir|
        real = begin
          File.realpath(dir)
        rescue SystemCallError
          nil
        end
        [dir, real]
      end.compact.uniq
    end

    def git_protected?(path)
      git_dirs.any? do |dir|
        next false unless path.start_with?("#{dir}/")

        relative = path.delete_prefix("#{dir}/").downcase
        relative == "config" || %w[hooks aiops].any? { |name| relative == name || relative.start_with?("#{name}/") }
      end
    end

    def candidates_for(path, base)
      candidate = File.expand_path(path.to_s, base)
      [candidate, resolve_existing(candidate)].compact.uniq
    end

    def root_forms
      @root_forms ||= begin
        real = begin
          File.realpath(@root)
        rescue SystemCallError
          nil
        end
        [@root, real].compact.uniq
      end
    end

    def relative_to_root(path)
      root_forms.each do |root|
        return path.delete_prefix("#{root}/") if path.start_with?("#{root}/")
      end
      nil
    end

    # Resolve symlinks in the deepest existing ancestor so aliases of protected paths are caught.
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

  # Decides whether one tool call would modify a protected path or bypass an Owner-only step.
  class ToolCallInspector
    def initialize(project, cwd)
      @project = project
      @cwd = cwd && !cwd.empty? ? cwd : project.root
      @depth = 0
    end

    def blocked_reason(payload)
      input = payload["tool_input"].is_a?(Hash) ? payload["tool_input"] : {}
      %w[file_path notebook_path path].each do |key|
        value = input[key]
        next unless value.is_a?(String) && !value.empty?

        kind = protection(value)
        return "#{value} 는 #{LABELS[kind]}에 속합니다." if kind
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

    def protection(path)
      @project.protection(path, @cwd)
    end

    def label(path)
      LABELS[protection(path)]
    end

    def patch_reason(text)
      text.each_line do |line|
        match = line.match(/\A\*\*\* (?:Add File|Update File|Delete File|Move to): (.+?)\s*\z/)
        next unless match
        return "patch가 #{label(match[1])}의 #{match[1]} 를 수정합니다." if protection(match[1])
      end
      nil
    end

    def shell_reason(command)
      if command.include?(ALLOW_CORE_COMMIT_ENV)
        return "#{ALLOW_CORE_COMMIT_ENV} 는 Owner(사용자)만 사용할 수 있습니다."
      end
      return "명령이 너무 깊게 중첩되어 안전하게 검사할 수 없습니다. 명령을 나눠서 실행하세요." if @depth >= MAX_SHELL_DEPTH

      saved = @cwd
      @depth += 1
      begin
        substitutions(command).each do |inner|
          reason = shell_reason(inner)
          return reason if reason
        end
        segments(command).each do |segment|
          reason = segment_reason(segment)
          return reason if reason
        end
        nil
      ensure
        @cwd = saved
        @depth -= 1
      end
    end

    # $(...), `...`, <(...) and >(...) run as their own commands.
    def substitutions(command)
      command.scan(/\$\(([^()]*)\)|`([^`]*)`|[<>]\(([^()]*)\)/).flatten.compact.map(&:strip).reject(&:empty?)
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
      segment = segment.sub(/\A[({!]+\s*/, "").sub(/\s*[)}]+\z/, "")
      tokens = tokenize(segment)
      return nil if tokens.empty?

      name = File.basename(strip_wrappers(tokens).first.to_s)
      owner_flag_reason(segment, name) || hooks_path_reason(segment, tokens, name) || redirect_reason(tokens) || command_reason(tokens)
    end

    def owner_flag_reason(segment, name)
      return nil unless segment.include?(OWNER_APPROVED_FLAG)
      return nil if SEARCH_COMMANDS.include?(name)

      "#{OWNER_APPROVED_FLAG} 는 Owner(사용자) 승인 기록입니다. Agent가 실행할 수 없습니다. " \
        "명령을 Owner에게 보여 주고 Owner가 자기 터미널에서 직접 실행하게 한 뒤 기다리세요."
    end

    def hooks_path_reason(segment, tokens, name)
      return nil unless segment.match?(/core\.hookspath/i)
      return nil if READ_COMMANDS.include?(name)

      stripped = strip_wrappers(tokens)
      if name == "git"
        config_index = stripped.index("config")
        if config_index
          rest = stripped[(config_index + 1)..-1]
          writes = %w[--unset --unset-all --replace-all --add --rename-section --remove-section --edit -e]
          unless rest.any? { |arg| writes.include?(arg) }
            return nil if rest.any? { |arg| %w[--get --get-all --get-regexp --list -l].include?(arg) }
            return nil if rest.reject { |arg| arg.start_with?("-") }.length == 1
          end
        end
      end
      "core.hooksPath 변경은 pre-commit 보호를 끌 수 있어 Owner(사용자)만 할 수 있습니다."
    end

    def redirect_reason(tokens)
      tokens.each_with_index do |token, index|
        target = if token.match?(/\A\d*>>?\z/) || token == "&>"
                   tokens[index + 1]
                 elsif (match = token.match(/\A\d*>>?(.+)\z/)) || (match = token.match(/\A&>(.+)\z/))
                   match[1]
                 end
        next unless target && !target.start_with?("&")
        return "출력 리다이렉션이 #{label(target)}의 #{target} 를 덮어씁니다." if protection(target)
      end
      nil
    end

    def command_reason(tokens)
      tokens = strip_wrappers(tokens)
      return nil if tokens.empty?

      name = File.basename(tokens.first)
      args = tokens[1..-1].reject { |arg| arg.match?(/\A\d*>>?/) || arg.start_with?("&>") }
      operands = args.reject { |arg| arg.start_with?("-") }

      return change_directory(operands) if %w[cd pushd].include?(name)
      return aiops_reason(args) if name == "aiops" || tokens.first.end_with?("/bin/aiops")
      return shell_reason(args.join(" ")) if name == "eval"
      return script_reason(operands.first, shell: true) if %w[source .].include?(name) && operands.first
      return shell_command_reason(args) if SHELLS.include?(name)

      if WRITE_ANY_ARG.include?(name)
        hit = operands.find { |arg| protection(arg) }
        return "#{name} 명령이 #{label(hit)}의 #{hit} 를 변경합니다." if hit
        if RECURSIVE_WRITERS.include?(name) && args.any? { |arg| arg.match?(/\A-[a-zA-Z]*[rR]/) || arg == "--recursive" }
          hit = operands.find { |arg| @project.covers_core?(arg, @cwd, follow_links: name == "rm") }
          return "#{name} -r 이 #{hit} 아래의 AI Ops 헌법 폴더(.ai/)까지 바꿉니다. 대상 경로를 좁히세요." if hit
        end
      end
      if WRITE_LAST_ARG.include?(name) && operands.any? && protection(operands.last)
        return "#{name} 명령이 #{label(operands.last)}에 씁니다."
      end
      if INPLACE_EDITORS.include?(name) && args.any? { |arg| arg.match?(/\A-[a-zA-Z]*i/) }
        hit = operands.find { |arg| protection(arg) }
        return "#{name} -i 가 #{label(hit)}의 #{hit} 를 수정합니다." if hit
      end
      if name == "dd"
        hit = args.map { |arg| arg[/\Aof=(.+)\z/, 1] }.compact.find { |arg| protection(arg) }
        return "dd 가 #{label(hit)}에 씁니다." if hit
      end
      return find_reason(args) if name == "find"
      return tar_reason(args) if %w[tar gtar bsdtar].include?(name)
      return unzip_reason(args) if name == "unzip"
      return git_reason(args) if name == "git"
      if INTERPRETERS.include?(name)
        return "스크립트 실행이 보호 대상(#{args.map { |arg| protected_reference(arg) }.compact.first})을 다룹니다. 읽기는 cat, grep 같은 읽기 명령을 사용하세요." if args.any? { |arg| protected_reference(arg) }

        script = operands.find { |arg| File.file?(File.expand_path(arg, @cwd)) }
        return script_reason(script, shell: false) if script
      end
      if tokens.first.include?("/") && File.file?(File.expand_path(tokens.first, @cwd)) && !tokens.first.end_with?("/bin/aiops")
        return script_reason(tokens.first, shell: true)
      end
      nil
    end

    def change_directory(operands)
      target = operands.first
      return nil if target == "-"

      @cwd = File.expand_path(target || Dir.home, @cwd)
      nil
    end

    def shell_command_reason(args)
      index = args.index { |arg| arg.match?(/\A-[a-zA-Z]*c[a-zA-Z]*\z/) }
      return shell_reason(args[index + 1].to_s) if index

      script = args.reject { |arg| arg.start_with?("-") }.first
      script ? script_reason(script, shell: true) : nil
    end

    # Inspect a script file the command would run.
    def script_reason(path, shell:)
      full = File.expand_path(path, @cwd)
      return nil unless File.file?(full)
      return "#{path} 가 너무 커서 안전하게 검사할 수 없습니다." if File.size(full) > MAX_SCRIPT_BYTES

      text = File.read(full)
      shebang = text.lines.first.to_s
      if shell && (!shebang.start_with?("#!") || shebang.match?(/\b(?:ba|z|da|k)?sh\b/))
        reason = shell_reason(text)
        return "#{path} 스크립트: #{reason}" if reason
        return nil
      end
      if text.include?(OWNER_APPROVED_FLAG) || text.include?(ALLOW_CORE_COMMIT_ENV)
        return "#{path} 스크립트가 Owner 전용 승인·우회 옵션을 사용합니다."
      end
      hit = protected_reference(text)
      hit ? "#{path} 스크립트가 보호 대상(#{hit})을 다룹니다." : nil
    rescue SystemCallError, ArgumentError
      nil
    end

    def find_reason(args)
      return nil unless args.any? { |arg| FIND_ACTIONS.include?(arg) }

      follow = args.include?("-L") || args.include?("-follow")
      rest = args.drop_while { |arg| %w[-H -L -P].include?(arg) }
      starts = rest.take_while { |arg| !arg.start_with?("-") && !%w[( ) ! ,].include?(arg) }
      starts = ["."] if starts.empty?
      hit = starts.find { |arg| protection(arg) }
      return "find 가 #{label(hit)}의 #{hit} 를 변경합니다." if hit

      hit = starts.find { |arg| @project.covers_core?(arg, @cwd, follow_links: follow) }
      hit ? "find 가 #{hit} 아래의 AI Ops 헌법 폴더(.ai/)까지 변경할 수 있습니다. 시작 경로를 좁히세요." : nil
    end

    def tar_reason(args)
      flags = args.each_with_index.map do |arg, index|
        if arg.start_with?("--")
          arg
        elsif arg.start_with?("-") || index.zero?
          arg.delete("-")
        end
      end.compact
      extract = flags.any? { |flag| %w[--extract --get].include?(flag) || (!flag.start_with?("--") && flag.include?("x")) }
      create = flags.any? { |flag| %w[--create --append --update].include?(flag) || (!flag.start_with?("--") && flag.match?(/[cru]/)) }
      dirs = []
      files = []
      args.each_with_index do |arg, index|
        if arg == "-C" || arg == "--directory"
          dirs << args[index + 1].to_s
        elsif (match = arg.match(/\A--directory=(.+)\z/))
          dirs << match[1]
        elsif arg == "--file" || (arg.match?(/\A-?[A-Za-z]*f\z/) && !arg.start_with?("--") && (arg.start_with?("-") || index.zero?))
          files << args[index + 1].to_s
        elsif (match = arg.match(/\A--file=(.+)\z/))
          files << match[1]
        end
      end
      if extract
        hit = dirs.find { |dir| protection(dir) }
        hit ||= "." if dirs.empty? && protection(".")
        return "tar 가 #{label(hit)}에 파일을 풉니다." if hit
      end
      if create
        hit = files.find { |file| protection(file) }
        return "tar 가 #{label(hit)}의 #{hit} 에 씁니다." if hit
      end
      nil
    end

    def unzip_reason(args)
      index = args.index("-d")
      dir = index ? args[index + 1].to_s : "."
      protection(dir) ? "unzip 이 #{label(dir)}에 파일을 풉니다." : nil
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
      if sub == "guard" && args.include?("write-core-digest")
        return "aiops guard write-core-digest 는 core 무결성 기준을 다시 만들므로 Owner(사용자)만 실행할 수 있습니다."
      end
      if sub == "agent" && args.include?("--apply") && (args.include?("rename") || args.include?("migrate-identities"))
        return "aiops agent rename/migrate-identities --apply 는 Agent Registry를 바꾸므로 Owner(사용자)가 직접 실행해야 합니다. --check 결과를 Owner에게 보여 주세요."
      end
      if sub == "guard" && args.include?("allow-structure-edit")
        return "aiops guard allow-structure-edit 는 Owner 전용 파일 수정을 허용하므로 Owner(사용자)가 직접 실행해야 합니다."
      end

      nil
    end

    def git_reason(args)
      index = 0
      git_dir_protected = false
      while index < args.length && args[index].start_with?("-")
        option = args[index]
        if %w[-C --git-dir --work-tree].include?(option)
          git_dir_protected ||= !protection(args[index + 1].to_s).nil?
          index += 2
        elsif %w[-c --config-env --namespace --exec-path].include?(option)
          index += 2
        elsif (match = option.match(/\A--(?:git-dir|work-tree)=(.+)\z/))
          git_dir_protected ||= !protection(match[1]).nil?
          index += 1
        else
          index += 1
        end
      end
      sub = args[index]
      rest = args[(index + 1)..-1].to_a
      if GIT_HOOKED_SUBCOMMANDS.include?(sub) && skips_hooks?(sub, rest)
        return "git #{sub} 의 hook 건너뛰기(--no-verify)는 .ai/ 보호를 끄므로 Owner(사용자)만 할 수 있습니다."
      end
      return nil unless GIT_WRITE_SUBCOMMANDS.include?(sub) || (git_dir_protected && %w[push tag branch config].include?(sub))
      return "git #{sub} 가 AI Ops core 저장소(.ai/)를 변경합니다." if git_dir_protected

      hit = rest.reject { |arg| arg.start_with?("-") }.find { |arg| protection(arg) }
      hit ? "git #{sub} 가 #{label(hit)}의 #{hit} 를 변경합니다." : nil
    end

    def skips_hooks?(sub, args)
      args.each do |arg|
        break if arg == "--"
        return true if arg.length > 5 && arg.start_with?("--no-v") && "--no-verify".start_with?(arg)
        next unless sub == "commit" && arg.match?(/\A-[a-zA-Z]+\z/)

        arg[1..-1].each_char do |char|
          return true if char == "n"
          break if "mFcCt".include?(char)
        end
      end
      false
    end

    # Returns the first path-like word in text that points at a protected location.
    def protected_reference(text)
      return text if !text.include?("\n") && protection(text)

      text.scan(/[^\s'"=(),;<>|&`\[\]{}]+/).find do |word|
        next false unless word.include?(".ai") || word.include?(".git") || word.include?("receipt")

        protection(word)
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
      when "allow-structure-edit" then allow_structure_edit
      when "lock-structure" then lock_structure
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
        opts.on("--minutes N", Integer) { |value| @options[:minutes] = value }
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
          aiops guard allow-structure-edit [--minutes N] [--target DIR]   (Owner only)
          aiops guard lock-structure [--target DIR]
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

    # Fails closed: an unreadable payload or an inspector error denies the call.
    def pre_tool_use
      parse!
      raw = STDIN.read.to_s
      return deny("hook payload가 비어 있어 안전하게 차단합니다.") if raw.strip.empty?

      payload = JSON.parse(raw)
      return deny("hook payload가 JSON 객체가 아니어서 안전하게 차단합니다.") unless payload.is_a?(Hash)

      cwd = payload["cwd"].to_s
      cwd = Dir.pwd if cwd.empty?
      project = @options[:target] != Dir.pwd ? Project.new(@options[:target]) : project_for(cwd)
      reason = ToolCallInspector.new(project, cwd).blocked_reason(payload)
      reason ? deny(reason) : 0
    rescue JSON::ParserError => e
      deny("hook payload를 읽을 수 없어 안전하게 차단합니다: #{e.message.lines.first.to_s.strip}")
    rescue StandardError => e
      raise if e.is_a?(Error) || e.is_a?(OptionParser::ParseError)

      deny("guard 검사 중 오류가 나서 안전하게 차단합니다: #{e.class}: #{e.message}")
    end

    def deny(reason)
      warn "AI Ops 차단: #{reason}"
      warn "보호 대상(.ai/, Owner 전용 파일, receipt, git hook)은 Agent가 바꿀 수 없습니다. 꼭 필요하면 작업을 멈추고 Owner(사용자)에게 알리세요."
      2
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

    def hook_line
      "\"$(git rev-parse --show-toplevel)/.ai/bin/aiops\" guard staged || exit 1"
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
      if current && !current.include?(GIT_HOOK_MARKER) && current.include?("guard staged")
        puts "ok: pre-commit guard present in #{path}"
        return 0
      end
      hooks_path, _err, hooks_status = Open3.capture3("git", "-C", root, "config", "--get", "core.hooksPath")
      if hooks_status.success? && !hooks_path.strip.empty?
        # A custom hooks directory (husky, lefthook, ...) is usually tracked; never write into it.
        puts "needs_user_decision: core.hooksPath is set (#{hooks_path.strip}); add this line to its pre-commit hook to keep .ai/ protected:"
        puts "  #{hook_line}"
        return 0
      end
      if current && !current.include?(GIT_HOOK_MARKER)
        puts "needs_user_decision: existing pre-commit hook at #{path}; add this line to keep .ai/ protected:"
        puts "  #{hook_line}"
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

    # Owner-only: lets agents edit agent_registry.md / operating_model.md for a while.
    def allow_structure_edit
      parse!
      minutes = @options[:minutes] || 30
      raise Error, "--minutes must be between 1 and 240" unless minutes.between?(1, 240)

      path = structure_unlock_path
      until_time = Time.now + minutes * 60
      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, "#{until_time.to_i}\n")
      puts "ok: Agent가 Owner 전용 파일(agent_registry.md, operating_model.md)을 #{until_time.strftime('%H:%M')}까지 고칠 수 있습니다."
      puts "끝나면 aiops guard lock-structure 로 바로 잠그세요."
      0
    end

    def lock_structure
      parse!
      path = structure_unlock_path
      File.delete(path) if File.file?(path)
      puts "ok: Owner 전용 파일이 다시 잠겼습니다."
      0
    end

    def structure_unlock_path
      project = Project.new(git_toplevel(@options[:target]) || @options[:target])
      project.structure_unlock_path || raise(Error, "Owner 전용 파일 잠금 해제는 git 저장소에서만 쓸 수 있습니다. git이 아니면 Owner가 파일을 직접 고치세요.")
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

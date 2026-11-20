#!/usr/bin/env ruby
# frozen_string_literal: true

# Project history archive: .ai_project/history/
#
# Records keep why something was decided or removed (background, the Owner's
# own words, the judgment, experiment results, what was deleted, how to
# restore) as small text files, so cleanup of worktrees, reports, and build
# folders does not lose the reasoning. INDEX.md lists one row per record so
# agents can find them with grep.

require "date"
require "fileutils"
require "json"
require "optparse"
require "yaml"

module History
  SCHEMA = "aiops.history.v1"
  DIR = ".ai_project/history"
  INDEX = "INDEX.md"
  CATEGORIES = %w[cleanup decision experiment task-archive structure other].freeze
  TEXT_EXTENSIONS = %w[.md .txt .patch .diff .csv .tsv].freeze
  REQUIRED_SECTIONS = ["배경", "판단과 이유"].freeze
  PLACEHOLDER = "(작성 전)"
  DEFAULT_MAX_KB = 1024
  SLUG = /\A[a-z0-9][a-z0-9-]*\z/.freeze
  TASK_ID = /T-\d{8}-\d{3,}/.freeze
  ROW_LINK = /\[[^\]]*\]\(([^)]+)\)\s*\|\s*\z/.freeze
  INDEX_HEADER = <<~MD
    # History Index

    프로젝트 기록보관소 목록이다. 지우거나 정리하는 작업(worktree, 보고서, 빌드 폴더, Task 보관)과 중요한 결정의 배경·Owner 발언·판단 근거·실험 결과·복원 방법을 텍스트로 남긴다.

    - 찾기: 이 표를 먼저 grep하고(Task ID, 분류, 낱말), 필요한 기록만 연다.
    - 새 기록: `aiops history new <주제> --category <분류> --task <Task ID> --title "<제목>" --summary "<한 줄 요약>"`
    - 분류: #{CATEGORIES.join(", ")}
    - 검사: `aiops history lint`
    - 텍스트(md, txt, patch, diff, csv)만 넣고 기록 하나는 #{DEFAULT_MAX_KB} KB를 넘기지 않는다(운영 모델 `history_record_max_kb`로 조정). 로그 원본, json 덤프, 이미지, 빌드 산출물은 넣지 않는다.

    | 날짜 | 분류 | 제목 | Task | 요약 | 기록 |
    |---|---|---|---|---|---|
  MD

  module_function

  def dir(root)
    File.join(root, DIR)
  end

  def index_path(root)
    File.join(dir(root), INDEX)
  end

  def parse_front_matter(text)
    match = text.match(/\A---\s*\n(.*?)\n---\s*(\n|\z)/m)
    return nil unless match

    data = YAML.safe_load(match[1], permitted_classes: [Date, Time], aliases: false)
    data.is_a?(Hash) ? data : nil
  rescue Psych::Exception
    nil
  end

  def read(path)
    File.read(path, encoding: "UTF-8").scrub
  rescue SystemCallError
    ""
  end

  # Top-level entries of the history folder: one record each (a folder or a file).
  def entries(root)
    base = dir(root)
    return [] unless File.directory?(base)

    Dir.children(base).sort.reject do |name|
      name.start_with?(".") || name == INDEX || name == "README.md"
    end
  end

  # The main document of a record and the link INDEX should use.
  def record_doc(root, name)
    path = File.join(dir(root), name)
    if File.directory?(path)
      readme = File.join(path, "README.md")
      return [readme, "#{name}/README.md"] if File.file?(readme)

      first = Dir.glob(File.join(path, "*.md")).min
      return [first, "#{name}/#{File.basename(first)}"] if first

      [nil, "#{name}/"]
    else
      [path, name]
    end
  end

  def record_files(root, name)
    path = File.join(dir(root), name)
    return [path] if File.file?(path)

    Dir.glob(File.join(path, "**", "*"), File::FNM_DOTMATCH).select { |file| File.file?(file) }.sort
  end

  def front(root, name)
    doc, = record_doc(root, name)
    doc ? parse_front_matter(read(doc)) : nil
  end

  def v1?(data)
    data.is_a?(Hash) && data["schema"] == SCHEMA
  end

  def clean(text)
    text.to_s.gsub(/\s+/, " ").tr("|", "/").strip
  end

  def tasks_of(data, text)
    listed = Array(data && data["tasks"]).map(&:to_s).reject(&:empty?)
    listed = text.scan(TASK_ID).uniq.first(3) if listed.empty?
    listed
  end

  # A row for a record that was written before INDEX existed (or by hand).
  def row_for(root, name)
    doc, link = record_doc(root, name)
    text = doc ? read(doc) : ""
    data = parse_front_matter(text)
    body = text.sub(/\A---\s*\n.*?\n---\s*\n/m, "")
    date = (data && data["date"]).to_s
    date = name[/\A\d{4}-\d{2}-\d{2}/].to_s if date.empty?
    category = (data && data["category"]).to_s
    category = "other" unless CATEGORIES.include?(category)
    title = (data && data["title"]).to_s
    title = body[/^#\s+(.+)$/, 1].to_s if title.empty?
    title = name if title.strip.empty?
    summary = (data && data["summary"]).to_s
    if summary.empty?
      # Only the text between the title and the first section; a guess from
      # deeper in the record is more misleading than an empty summary.
      intro = body.sub(/\A\s*#\s+[^\n]*\n/, "").split(/^##\s/).first.to_s
      paragraph = intro.split(/\n\s*\n/).map(&:strip).find { |part| !part.empty? && !part.start_with?("#", "|", "-", "<!--", "```", "작성") }
      summary = paragraph.to_s.delete("*`")[/\A[^\n]*?[.!?。]|\A[^\n]*/].to_s
      summary = "#{summary[0, 117]}..." if summary.length > 120
    end
    format_row(date, category, title, tasks_of(data, text), summary, link)
  end

  def format_row(date, category, title, tasks, summary, link)
    label = link.sub(%r{/README\.md\z}, "")
    "| #{clean(date)} | #{clean(category)} | #{clean(title)} | #{clean(tasks.join(", "))} | #{clean(summary)} | [#{label}](#{link}) |"
  end

  def index_links(root)
    path = index_path(root)
    return [] unless File.file?(path)

    read(path).lines.map { |line| line.strip[ROW_LINK, 1] }.compact
  end

  def listed_names(root)
    index_links(root).map { |link| link.sub(%r{\A\./}, "").split("/").first }.compact.uniq
  end

  def ensure_index(root)
    path = index_path(root)
    return false if File.file?(path)

    FileUtils.mkdir_p(dir(root))
    File.open(path, File::WRONLY | File::CREAT | File::EXCL) { |file| file.write(INDEX_HEADER) }
    true
  rescue Errno::EEXIST
    false
  end

  def append_rows(root, rows)
    return if rows.empty?

    # Append under a lock so two sessions adding records at once keep both rows.
    File.open(index_path(root), "a+") do |file|
      file.flock(File::LOCK_EX)
      file.seek(0, IO::SEEK_END)
      if file.size.positive?
        file.seek(-1, IO::SEEK_END)
        last = file.read(1)
        file.seek(0, IO::SEEK_END)
        file.write("\n") unless last == "\n"
      end
      file.write(rows.map { |row| "#{row}\n" }.join)
    end
  end

  # Creates INDEX.md if needed and adds rows for records it does not list yet.
  # Existing rows are kept as written.
  def adopt(root)
    created = ensure_index(root)
    listed = listed_names(root)
    missing = entries(root).reject { |name| listed.include?(name) }
    append_rows(root, missing.map { |name| row_for(root, name) })
    [created, missing]
  end

  def max_kb(root)
    model = File.join(root, ".ai_project/operating_model.md")
    value = File.file?(model) ? (parse_front_matter(read(model)) || {})["history_record_max_kb"] : nil
    value.is_a?(Integer) && value >= 1 ? value : DEFAULT_MAX_KB
  end

  def section_body(text, heading)
    text[/^##\s+#{Regexp.escape(heading)}\s*\n(.*?)(?=^##\s|\z)/m, 1]
  end

  # Returns [errors, notes]. Records with the v1 front matter get the full
  # rules; older records only get notes, so existing archives are not blocked.
  def lint(root)
    errors = []
    notes = []
    unless File.directory?(dir(root))
      return [errors, notes]
    end
    unless File.file?(index_path(root))
      errors << "#{DIR}/#{INDEX} missing; run aiops history index"
      return [errors, notes]
    end

    names = entries(root)
    listed = listed_names(root)
    (names - listed).each { |name| errors << "#{name}: not listed in #{INDEX}; run aiops history index or add a row" }
    index_links(root).each do |link|
      target = File.join(dir(root), link.sub(%r{\A\./}, ""))
      errors << "#{INDEX}: link #{link} points to a missing file" unless File.exist?(target)
    end

    limit = max_kb(root)
    names.each do |name|
      doc, = record_doc(root, name)
      text = doc ? read(doc) : ""
      data = parse_front_matter(text)
      problems = []
      files = record_files(root, name)
      odd = files.reject { |file| TEXT_EXTENSIONS.include?(File.extname(file).downcase) }
      problems << "non-text files (#{odd.length}): #{odd.first(3).map { |file| file.sub("#{dir(root)}/", "") }.join(", ")}" unless odd.empty?
      size_kb = (files.map { |file| File.size(file) }.sum / 1024.0).ceil
      problems << "#{size_kb} KB is over #{limit} KB (history_record_max_kb); keep only the lines and numbers needed" if size_kb > limit

      unless v1?(data)
        problems.each { |problem| notes << "#{name}: older record (no #{SCHEMA} front matter): #{problem}" }
        next
      end

      errors.concat(problems.map { |problem| "#{name}: #{problem}" })
      errors << "#{name}: category #{data["category"].inspect} is not one of #{CATEGORIES.join(", ")}" unless CATEGORIES.include?(data["category"].to_s)
      %w[date title summary].each do |key|
        errors << "#{name}: front matter #{key} is empty" if data[key].to_s.strip.empty? || data[key].to_s.include?("{{")
      end
      REQUIRED_SECTIONS.each do |heading|
        body = section_body(text, heading)
        if body.nil?
          errors << "#{name}: section \"## #{heading}\" missing"
        elsif body.include?(PLACEHOLDER) || body.strip.empty?
          errors << "#{name}: section \"## #{heading}\" is not written yet"
        end
      end
      errors << "#{name}: template placeholders {{...}} remain" if text.include?("{{")
    end
    [errors, notes]
  end

  # Text of every record, for "is this Task mentioned anywhere" checks.
  def mentioned_task_ids(root)
    ids = {}
    return ids unless File.directory?(dir(root))

    Dir.glob(File.join(dir(root), "**", "*")).each do |file|
      next unless File.file?(file) && TEXT_EXTENSIONS.include?(File.extname(file).downcase)

      read(file).scan(TASK_ID) { |id| ids[id] = true }
    end
    ids
  end

  def create(root, slug, options)
    raise ArgumentError, "topic must be lowercase letters, digits, and hyphens (e.g. disk-cleanup)" unless slug =~ SLUG

    date = options[:date] || Date.today.to_s
    raise ArgumentError, "--date must be YYYY-MM-DD" unless date =~ /\A\d{4}-\d{2}-\d{2}\z/
    category = options[:category] || "other"
    raise ArgumentError, "--category must be one of #{CATEGORIES.join(", ")}" unless CATEGORIES.include?(category)
    tasks = options[:tasks]
    tasks.each { |id| raise ArgumentError, "--task must look like T-YYYYMMDD-NNN: #{id}" unless id =~ /\A#{TASK_ID}\z/ }

    name = "#{date}-#{slug}"
    record_dir = File.join(dir(root), name)
    raise ArgumentError, "#{DIR}/#{name} already exists" if File.exist?(record_dir)

    template = File.read(File.expand_path("../templates/history/record.md", __dir__), encoding: "UTF-8")
    title = options[:title] || slug.tr("-", " ")
    summary = options[:summary] || ""
    values = {
      "DATE" => date,
      "CATEGORY" => category,
      "TITLE" => title,
      "SUMMARY" => summary.empty? ? "\"\"" : summary,
      "TASKS" => tasks.empty? ? "[]" : "[#{tasks.join(", ")}]"
    }
    text = template.gsub(/\{\{(\w+)\}\}/) { values.fetch(Regexp.last_match(1), Regexp.last_match(0)) }
    text = text.sub("- Task: []", "- Task: 없음")
    # JSON strings are valid YAML double-quoted strings, so titles with ":" stay intact.
    text = text.sub(/^title: .*$/) { "title: #{title.to_json}" }
    text = text.sub(/^summary: .*$/) { "summary: #{summary.to_json}" }

    ensure_index(root)
    Dir.mkdir(record_dir)
    File.write(File.join(record_dir, "README.md"), text)
    append_rows(root, [format_row(date, category, title, tasks, summary, "#{name}/README.md")])
    "#{DIR}/#{name}/README.md"
  end

  class CLI
    USAGE = <<~TEXT
      usage:
        aiops history new TOPIC [--category C] [--task TASK_ID]... [--title TEXT] [--summary TEXT] [--date YYYY-MM-DD] [--target DIR]
        aiops history index [--target DIR]
        aiops history lint [--target DIR]
    TEXT

    def initialize(argv)
      @argv = argv.dup
      @options = { target: Dir.pwd, tasks: [] }
    end

    def run
      action = @argv.shift
      if action.nil? || %w[-h --help help].include?(action)
        puts USAGE
        exit 0
      end
      positional = parse!
      root = find_root(File.expand_path(@options[:target]))
      case action
      when "new" then run_new(root, positional)
      when "index" then run_index(root)
      when "lint" then run_lint(root)
      else
        warn USAGE
        exit 2
      end
    rescue ArgumentError, OptionParser::ParseError, SystemCallError => e
      warn "error: #{e.message}"
      exit 2
    end

    private

    def parse!
      parser = OptionParser.new do |opts|
        opts.on("--target DIR") { |value| @options[:target] = value }
        opts.on("--category C") { |value| @options[:category] = value }
        opts.on("--task ID") { |value| @options[:tasks] << value }
        opts.on("--title TEXT") { |value| @options[:title] = value }
        opts.on("--summary TEXT") { |value| @options[:summary] = value }
        opts.on("--date DATE") { |value| @options[:date] = value }
        opts.on("-h", "--help") do
          puts USAGE
          exit 0
        end
      end
      parser.parse(@argv)
    end

    def find_root(start)
      dir = start
      loop do
        return dir if File.directory?(File.join(dir, ".ai_project"))
        parent = File.dirname(dir)
        raise ArgumentError, ".ai_project not found from #{start}; pass --target" if parent == dir

        dir = parent
      end
    end

    def run_new(root, positional)
      slug = positional.first
      raise ArgumentError, "history new requires a TOPIC (e.g. disk-cleanup)" if slug.nil? || positional.length > 1

      path = History.create(root, slug, @options)
      puts "created: #{path}"
      puts "next: fill in the sections (배경, Owner 발언 with the Owner's exact words, 판단과 이유, ...), then run aiops history lint"
    end

    def run_index(root)
      created, added = History.adopt(root)
      puts "created: #{DIR}/#{INDEX}" if created
      added.each { |name| puts "listed: #{name}" }
      puts "ok: #{DIR}/#{INDEX} lists every record" if added.empty?
    end

    def run_lint(root)
      errors, notes = History.lint(root)
      unless File.directory?(History.dir(root))
        puts "note: #{DIR} missing; aiops history new creates it"
        return
      end
      notes.each { |note| puts "note: #{note}" }
      errors.each { |error| puts "error: #{error}" }
      if errors.empty?
        puts "ok: history (#{History.entries(root).length} records)"
      else
        exit 1
      end
    end
  end
end

History::CLI.new(ARGV).run if $PROGRAM_NAME == __FILE__

#!/usr/bin/env ruby
# frozen_string_literal: true

require "cgi"
require "json"
require "open3"
require "optparse"
require "socket"
require "uri"

class DashboardServer
  MAPS = %w[summary dependencies swimlane critical-path workflow agents blockers].freeze

  def initialize(options)
    @aiops = File.expand_path(options.fetch(:aiops))
    @target = File.expand_path(options.fetch(:target))
    @port = options.fetch(:port)
    @refresh = options.fetch(:refresh)
    @open_browser = options.fetch(:open_browser)
    @dashboard = options.fetch(:dashboard)
    @server = nil
  end

  def run
    @server = TCPServer.new("127.0.0.1", @port)
    run_aiops(*dashboard_args("html"))
    actual_port = @server.local_address.ip_port
    url = "http://127.0.0.1:#{actual_port}/"
    install_signal_handlers

    $stdout.sync = true
    puts "AI Ops dashboard server"
    puts "target: #{@target}"
    puts "url: #{url}"
    puts "refresh: #{@refresh.zero? ? "manual" : "#{@refresh}s"}"
    puts "stop: Ctrl+C"

    open_browser(url) if @open_browser

    loop do
      socket = @server.accept
      handle(socket)
    rescue IOError, Errno::EBADF
      break
    end
  rescue Errno::EADDRINUSE
    suggestion = next_available_port(@port)
    message = "dashboard port #{@port} is already in use"
    message += "; try --port #{suggestion}" if suggestion
    warn message
    exit 1
  rescue Errno::EACCES
    warn "dashboard port #{@port} cannot be opened; choose a port above 1024"
    exit 1
  rescue RuntimeError => error
    warn error.message
    exit 1
  ensure
    @server&.close unless @server&.closed?
  end

  private

  def install_signal_handlers
    %w[INT TERM].each do |signal|
      Signal.trap(signal) { @server&.close }
    end
  end

  def handle(socket)
    request_line = socket.gets
    return unless request_line

    method, raw_target, version = request_line.split(" ", 3)
    unless %w[GET HEAD].include?(method) && version&.start_with?("HTTP/")
      consume_headers(socket)
      return respond(socket, 405, "text/plain; charset=utf-8", "method not allowed\n", method == "HEAD")
    end

    consume_headers(socket)
    path = request_path(raw_target)
    status, content_type, body = route(path)
    respond(socket, status, content_type, body, method == "HEAD")
  rescue StandardError => error
    respond(socket, 500, "text/plain; charset=utf-8", "dashboard server error: #{error.message}\n", false)
  ensure
    socket.close unless socket.closed?
  end

  def consume_headers(socket)
    total = 0
    100.times do
      line = socket.gets
      break unless line
      total += line.bytesize
      raise "request headers too large" if total > 65_536
      break if line == "\r\n" || line == "\n"
    end
  end

  def request_path(raw_target)
    URI.parse(raw_target.to_s).path
  rescue URI::InvalidURIError
    ""
  end

  def route(path)
    case path
    when "/"
      html = run_aiops(*dashboard_args("html"))
      [200, "text/html; charset=utf-8", decorate_html(html)]
    when "/dashboard.json"
      body = run_aiops(*dashboard_args("json"))
      JSON.parse(body)
      [200, "application/json; charset=utf-8", body]
    when "/healthz"
      [200, "application/json; charset=utf-8", JSON.generate({"status" => "ok", "target" => @target}) + "\n"]
    else
      match = path.match(%r{\A/maps/([a-z-]+)\.mmd\z})
      return [404, "text/plain; charset=utf-8", "not found\n"] unless match

      map = match[1]
      return [404, "text/plain; charset=utf-8", "unknown dashboard map\n"] unless MAPS.include?(map)

      [200, "text/plain; charset=utf-8", run_aiops(*map_args(map))]
    end
  rescue JSON::ParserError
    [500, "text/plain; charset=utf-8", "dashboard command returned invalid JSON\n"]
  rescue RuntimeError => error
    [500, "text/plain; charset=utf-8", "#{error.message}\n"]
  end

  def dashboard_args(kind)
    args = ["project", "dashboard", "--target", @target, "--view", @dashboard.fetch(:view), "--level", @dashboard.fetch(:level)]
    args.concat(["--format", "html", "--map", @dashboard.fetch(:map)])
    append_dashboard_scope(args)
    if kind == "json"
      args << "--json"
    else
      append_html_filters(args)
    end
    args
  end

  def map_args(map)
    args = ["project", "dashboard", "--target", @target, "--view", "work", "--format", "mermaid", "--map", map]
    append_dashboard_scope(args)
    args
  end

  def append_dashboard_scope(args)
    focus = @dashboard.fetch(:focus)
    args.concat(["--focus", focus]) unless focus.empty?
    args.concat(["--depth", @dashboard.fetch(:depth).to_s])
    args.concat(["--group-by", @dashboard.fetch(:group_by)])
  end

  def append_html_filters(args)
    {
      "--filter-status" => :filter_status,
      "--filter-agent" => :filter_agent,
      "--filter-role" => :filter_role,
      "--filter-workflow" => :filter_workflow
    }.each do |option, key|
      value = @dashboard.fetch(key)
      args.concat([option, value]) unless value.empty?
    end
  end

  def run_aiops(*args)
    stdout, stderr, status = Open3.capture3(@aiops, *args)
    return stdout if status.success?

    detail = stderr.strip
    detail = stdout.strip if detail.empty?
    raise "dashboard command failed#{detail.empty? ? "" : ": #{detail}"}"
  end

  def decorate_html(html)
    refresh_label = @refresh.zero? ? "수동 새로고침" : "#{@refresh}초마다 자동 새로고침"
    bar = <<~HTML
      <style>
      .serve-bar{position:sticky;top:0;z-index:50;display:flex;align-items:center;justify-content:space-between;gap:12px;padding:10px 32px;background:#0f172a;color:#f8fafc;border-bottom:1px solid #334155}.serve-bar div{display:flex;align-items:center;gap:10px;min-width:0}.serve-bar strong{white-space:nowrap}.serve-bar span{overflow:hidden;text-overflow:ellipsis;white-space:nowrap;color:#cbd5e1;font-size:13px}.serve-bar button{border:1px solid #64748b;border-radius:6px;background:#fff;color:#0f172a;padding:6px 10px;font-weight:700;cursor:pointer}@media(max-width:620px){.serve-bar{padding:10px 18px;align-items:flex-start}.serve-bar div{display:block}.serve-bar span{display:block;margin-top:2px}}
      </style>
      <div class="serve-bar" data-refresh-seconds="#{@refresh}"><div><strong>실시간 로컬 대시보드</strong><span>#{CGI.escapeHTML(refresh_label)} · #{CGI.escapeHTML(@target)}</span></div><button type="button" id="serve-refresh">지금 새로고침</button></div>
      <script>
      (()=>{const seconds=#{@refresh};const button=document.getElementById("serve-refresh");button.addEventListener("click",()=>window.location.reload());if(seconds>0)window.setTimeout(()=>window.location.reload(),seconds*1000);})();
      </script>
    HTML
    html.sub("<body>", "<body>\n#{bar}")
  end

  def respond(socket, status, content_type, body, head_only)
    reason = {200 => "OK", 404 => "Not Found", 405 => "Method Not Allowed", 500 => "Internal Server Error"}.fetch(status, "Error")
    payload = body.to_s
    headers = [
      "HTTP/1.1 #{status} #{reason}",
      "Content-Type: #{content_type}",
      "Content-Length: #{payload.bytesize}",
      "Cache-Control: no-store",
      "X-Content-Type-Options: nosniff",
      "X-Frame-Options: DENY",
      "Referrer-Policy: no-referrer",
      "Content-Security-Policy: default-src 'self'; script-src 'self' 'unsafe-inline' https://cdn.jsdelivr.net; style-src 'self' 'unsafe-inline'; img-src 'self' data:; connect-src 'self' https://cdn.jsdelivr.net",
      "Connection: close",
      "",
      ""
    ].join("\r\n")
    socket.write(headers)
    socket.write(payload) unless head_only
  end

  def next_available_port(port)
    return nil if port.zero?

    ((port + 1)..[port + 10, 65_535].min).find do |candidate|
      probe = TCPServer.new("127.0.0.1", candidate)
      probe.close
      true
    rescue Errno::EADDRINUSE, Errno::EACCES
      false
    end
  end

  def open_browser(url)
    command = if RUBY_PLATFORM.include?("darwin") && command_available?("open")
                ["open", url]
              elsif command_available?("xdg-open")
                ["xdg-open", url]
              end
    return warn("note: no supported browser opener found; open #{url}") unless command

    Process.spawn(*command, out: File::NULL, err: File::NULL)
  rescue StandardError => error
    warn "note: browser could not be opened (#{error.message}); open #{url}"
  end

  def command_available?(name)
    ENV.fetch("PATH", "").split(File::PATH_SEPARATOR).any? do |directory|
      path = File.join(directory, name)
      File.file?(path) && File.executable?(path)
    end
  end
end

options = {
  port: 8765,
  refresh: 0,
  open_browser: false,
  dashboard: {
    view: "main",
    level: "standard",
    map: "summary",
    focus: "",
    depth: 2,
    group_by: "area",
    filter_status: "",
    filter_agent: "",
    filter_role: "",
    filter_workflow: ""
  }
}

OptionParser.new do |parser|
  parser.on("--aiops PATH") { |value| options[:aiops] = value }
  parser.on("--target DIR") { |value| options[:target] = value }
  parser.on("--port N", Integer) { |value| options[:port] = value }
  parser.on("--refresh N", Integer) { |value| options[:refresh] = value }
  parser.on("--open") { options[:open_browser] = true }
  parser.on("--view NAME") { |value| options[:dashboard][:view] = value }
  parser.on("--level NAME") { |value| options[:dashboard][:level] = value }
  parser.on("--map NAME") { |value| options[:dashboard][:map] = value }
  parser.on("--focus ID") { |value| options[:dashboard][:focus] = value }
  parser.on("--depth N", Integer) { |value| options[:dashboard][:depth] = value }
  parser.on("--group-by NAME") { |value| options[:dashboard][:group_by] = value }
  parser.on("--filter-status LIST") { |value| options[:dashboard][:filter_status] = value }
  parser.on("--filter-agent NAME") { |value| options[:dashboard][:filter_agent] = value }
  parser.on("--filter-role ROLE") { |value| options[:dashboard][:filter_role] = value }
  parser.on("--filter-workflow NAME") { |value| options[:dashboard][:filter_workflow] = value }
end.parse!

abort("dashboard server requires --aiops") unless options[:aiops]
abort("dashboard server requires --target") unless options[:target]
abort("dashboard server port must be between 0 and 65535") unless (0..65_535).cover?(options[:port])
abort("dashboard refresh must be between 0 and 86400 seconds") unless (0..86_400).cover?(options[:refresh])

DashboardServer.new(options).run

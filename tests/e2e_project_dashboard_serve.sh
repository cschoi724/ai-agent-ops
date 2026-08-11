#!/usr/bin/env sh
set -eu

repo_root="$(CDPATH= cd "$(dirname "$0")/.." && pwd)"
tmpdir="$(mktemp -d /tmp/aiops-e2e-dashboard-serve.XXXXXX)"
project="$tmpdir/project"
server_pid=""
partial_pid=""

cleanup() {
  if [ -n "$partial_pid" ]; then
    kill "$partial_pid" >/dev/null 2>&1 || true
    wait "$partial_pid" >/dev/null 2>&1 || true
  fi
  if [ -n "$server_pid" ]; then
    kill "$server_pid" >/dev/null 2>&1 || true
    wait "$server_pid" >/dev/null 2>&1 || true
  fi
  rm -rf "$tmpdir"
}
trap cleanup EXIT INT TERM

if ! ruby -rsocket -e 'server = TCPServer.new("127.0.0.1", 0); server.close' >/dev/null 2>&1; then
  printf '%s\n' "skip: localhost bind is not available"
  exit 0
fi

mkdir -p "$project/.ai_project"
ln -s "$repo_root" "$project/.ai"
printf '# Agent Instructions\n' > "$project/AGENTS.md"

"$repo_root/bin/aiops" project dashboard preset add e2e-live \
  --target "$project" \
  --view main \
  --format html \
  --map summary \
  --serve \
  --port 0 \
  --refresh 3 \
  >/dev/null

before_hash="$(find "$project" -type f -print | sort | xargs shasum -a 256 | shasum -a 256 | awk '{print $1}')"

"$repo_root/bin/aiops" project dashboard \
  --target "$project" \
  --preset e2e-live \
  >"$tmpdir/server.log" 2>&1 &
server_pid="$!"

attempt=0
while [ "$attempt" -lt 100 ]; do
  port="$(sed -n 's#^url: http://127\.0\.0\.1:\([0-9][0-9]*\)/$#\1#p' "$tmpdir/server.log" | tail -1)"
  [ -n "$port" ] && break
  kill -0 "$server_pid" >/dev/null 2>&1 || {
    cat "$tmpdir/server.log" >&2
    printf '%s\n' "dashboard server exited before startup" >&2
    exit 1
  }
  sleep 0.05
  attempt=$((attempt + 1))
done

[ -n "${port:-}" ] || {
  cat "$tmpdir/server.log" >&2
  printf '%s\n' "dashboard server port missing" >&2
  exit 1
}

request() {
  method="$1"
  path="$2"
  expected="$3"
  body_file="$4"
  header_file="$5"
  ruby -rsocket -e '
    method, port, path, expected, body_file, header_file = ARGV
    socket = TCPSocket.new("127.0.0.1", Integer(port))
    socket.write("#{method} #{path} HTTP/1.1\r\nHost: 127.0.0.1\r\nConnection: close\r\n\r\n")
    response = socket.read
    headers, body = response.split("\r\n\r\n", 2)
    status = headers.to_s.lines.first.to_s.split[1]
    abort("expected HTTP #{expected}, got #{status}") unless status == expected
    File.binwrite(body_file, body.to_s)
    File.binwrite(header_file, headers.to_s)
  ' "$method" "$port" "$path" "$expected" "$body_file" "$header_file"
}

request GET / 200 "$tmpdir/dashboard.html" "$tmpdir/dashboard.headers"
request GET /dashboard.json 200 "$tmpdir/dashboard.json" "$tmpdir/dashboard-json.headers"
sleep 1
request GET /dashboard.json 200 "$tmpdir/dashboard-latest.json" "$tmpdir/dashboard-latest.headers"
request GET /maps/dependencies.mmd 200 "$tmpdir/dependencies.mmd" "$tmpdir/map.headers"
request GET /healthz 200 "$tmpdir/health.json" "$tmpdir/health.headers"
request GET /unknown 404 "$tmpdir/not-found.txt" "$tmpdir/not-found.headers"
request POST / 405 "$tmpdir/method.txt" "$tmpdir/method.headers"
request HEAD / 200 "$tmpdir/head.txt" "$tmpdir/head.headers"

ruby -rsocket -e '
  socket = TCPSocket.new("127.0.0.1", Integer(ARGV[0]))
  socket.setsockopt(Socket::SOL_SOCKET, Socket::SO_LINGER, [1, 0].pack("ii"))
  socket.write("GET / HTTP/1.1\r\nHost: 127.0.0.1\r\n\r\n")
  socket.close
' "$port"
sleep 0.2
kill -0 "$server_pid" || {
  printf '%s\n' "dashboard server exited after client disconnect" >&2
  exit 1
}
request GET /healthz 200 "$tmpdir/health-after-disconnect.json" "$tmpdir/health-after-disconnect.headers"

ruby -rsocket -e '
  socket = TCPSocket.new("127.0.0.1", Integer(ARGV[0]))
  socket.write("GET / HTTP/1.1\r\nHost: 127.0.0.1\r\nX-Partial: waiting")
  response = socket.read
  status = response.lines.first.to_s.split[1]
  abort("expected HTTP 408, got #{status}") unless status == "408"
' "$port" &
partial_pid="$!"
sleep 0.2
request GET /healthz 200 "$tmpdir/health-during-partial.json" "$tmpdir/health-during-partial.headers"
wait "$partial_pid"
partial_pid=""

ruby -rsocket -e '
  socket = TCPSocket.new("127.0.0.1", Integer(ARGV[0]))
  payload = "GET / HTTP/1.1\r\nHost: 127.0.0.1\r\nX-Large: "
  payload << "a" * (65_536 - payload.bytesize)
  socket.write(payload)
  socket.close_write
  response = socket.read
  status = response.lines.first.to_s.split[1]
  abort("expected HTTP 431, got #{status}") unless status == "431"
' "$port"

ruby -rsocket -e '
  port, ready_file = ARGV
  sockets = Array.new(8) do
    socket = TCPSocket.new("127.0.0.1", Integer(port))
    socket.write("GET / HTTP/1.1\r\nHost: 127.0.0.1\r\nX-Partial: waiting")
    socket
  end
  File.write(ready_file, "ready\n")
  sleep 10
' "$port" "$tmpdir/overload-ready" &
partial_pid="$!"
attempt=0
while [ "$attempt" -lt 100 ]; do
  [ -s "$tmpdir/overload-ready" ] && break
  sleep 0.05
  attempt=$((attempt + 1))
done
[ -s "$tmpdir/overload-ready" ] || {
  printf '%s\n' "dashboard overload fixture did not start" >&2
  exit 1
}
sleep 0.2
request GET /healthz 503 "$tmpdir/busy.txt" "$tmpdir/busy.headers"
grep -qx 'dashboard server is busy' "$tmpdir/busy.txt" || {
  printf '%s\n' "dashboard overload response body missing" >&2
  exit 1
}
kill "$partial_pid" >/dev/null 2>&1 || true
wait "$partial_pid" >/dev/null 2>&1 || true
partial_pid=""
sleep 0.2
request GET /healthz 200 "$tmpdir/health-after-overload.json" "$tmpdir/health-after-overload.headers"

grep -q 'AI Ops dashboard server' "$tmpdir/server.log" || {
  printf '%s\n' "dashboard server startup title missing" >&2
  exit 1
}
grep -q '^refresh: 3s$' "$tmpdir/server.log" || {
  printf '%s\n' "dashboard server refresh setting missing" >&2
  exit 1
}
grep -q '실시간 로컬 대시보드' "$tmpdir/dashboard.html" || {
  printf '%s\n' "served dashboard banner missing" >&2
  exit 1
}
grep -q 'data-refresh-seconds="3"' "$tmpdir/dashboard.html" || {
  printf '%s\n' "served dashboard refresh metadata missing" >&2
  exit 1
}
grep -q '지금 새로고침' "$tmpdir/dashboard.html" || {
  printf '%s\n' "served dashboard manual refresh missing" >&2
  exit 1
}
grep -qi '^Cache-Control: no-store' "$tmpdir/dashboard.headers" || {
  printf '%s\n' "served dashboard no-store header missing" >&2
  exit 1
}
grep -qi '^Content-Security-Policy:' "$tmpdir/dashboard.headers" || {
  printf '%s\n' "served dashboard CSP header missing" >&2
  exit 1
}
grep -q '^flowchart ' "$tmpdir/dependencies.mmd" || {
  printf '%s\n' "served Mermaid source missing" >&2
  exit 1
}
grep -q '"status":"ok"' "$tmpdir/health.json" || {
  printf '%s\n' "dashboard server health response missing" >&2
  exit 1
}
[ ! -s "$tmpdir/head.txt" ] || {
  printf '%s\n' "dashboard HEAD response included a body" >&2
  exit 1
}

"$repo_root/bin/aiops" validate project-dashboard "$tmpdir/dashboard.json" >/dev/null
ruby -rjson -e '
  before = JSON.parse(File.read(ARGV[0]))
  after = JSON.parse(File.read(ARGV[1]))
  abort("served dashboard was not regenerated") if before["generated_at"] == after["generated_at"]
' "$tmpdir/dashboard.json" "$tmpdir/dashboard-latest.json"

if "$repo_root/bin/aiops" project dashboard --target "$project" --serve --port "$port" >"$tmpdir/collision.log" 2>&1; then
  printf '%s\n' "dashboard server port collision should fail" >&2
  exit 1
fi
grep -q "dashboard port $port is already in use; try --port" "$tmpdir/collision.log" || {
  printf '%s\n' "dashboard server port collision guidance missing" >&2
  exit 1
}

if "$repo_root/bin/aiops" project dashboard --target "$project" --refresh 3 >/dev/null 2>&1; then
  printf '%s\n' "dashboard refresh without serve should fail" >&2
  exit 1
fi
if "$repo_root/bin/aiops" project dashboard --target "$project" --serve --json >/dev/null 2>&1; then
  printf '%s\n' "dashboard serve with JSON should fail" >&2
  exit 1
fi
for invalid_filter in status agent role workflow; do
  if "$repo_root/bin/aiops" project dashboard --target "$project" --serve --port 0 "--filter-$invalid_filter" DOES_NOT_EXIST >"$tmpdir/invalid-filter.log" 2>&1; then
    printf '%s\n' "dashboard serve with unknown $invalid_filter filter should fail" >&2
    exit 1
  fi
  grep -q "unknown --filter-$invalid_filter value: DOES_NOT_EXIST" "$tmpdir/invalid-filter.log" || {
    printf '%s\n' "dashboard serve unknown $invalid_filter filter guidance missing" >&2
    exit 1
  }
done

after_hash="$(find "$project" -type f -print | sort | xargs shasum -a 256 | shasum -a 256 | awk '{print $1}')"
[ "$before_hash" = "$after_hash" ] || {
  printf '%s\n' "dashboard server modified target project files" >&2
  exit 1
}

kill "$server_pid"
wait "$server_pid"
server_pid=""

mkdir -p "$tmpdir/fake-bin"
printf '%s\n' '#!/bin/sh' 'printf "%s\n" "$1" > "$AIOPS_OPEN_LOG"' > "$tmpdir/fake-bin/open"
cp "$tmpdir/fake-bin/open" "$tmpdir/fake-bin/xdg-open"
chmod +x "$tmpdir/fake-bin/open" "$tmpdir/fake-bin/xdg-open"

PATH="$tmpdir/fake-bin:$PATH" AIOPS_OPEN_LOG="$tmpdir/open.log" \
  "$repo_root/bin/aiops" project dashboard --target "$project" --serve --port 0 --open \
  >"$tmpdir/open-server.log" 2>&1 &
server_pid="$!"

attempt=0
while [ "$attempt" -lt 100 ]; do
  [ -s "$tmpdir/open.log" ] && break
  kill -0 "$server_pid" >/dev/null 2>&1 || {
    cat "$tmpdir/open-server.log" >&2
    printf '%s\n' "dashboard server exited before opening browser" >&2
    exit 1
  }
  sleep 0.05
  attempt=$((attempt + 1))
done

grep -Eq '^http://127\.0\.0\.1:[0-9]+/$' "$tmpdir/open.log" || {
  printf '%s\n' "dashboard server browser URL missing" >&2
  exit 1
}

kill "$server_pid"
wait "$server_pid"
server_pid=""

printf '%s\n' "ok: project dashboard serve"

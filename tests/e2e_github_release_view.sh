#!/usr/bin/env sh
set -eu

repo_root="$(CDPATH= cd "$(dirname "$0")/.." && pwd)"
tmpdir="$(mktemp -d /tmp/aiops-e2e-github-release.XXXXXX)"
project="$tmpdir/project"
fake_bin="$tmpdir/bin"
gh_log="$tmpdir/gh.log"
server_pid=""

cleanup() {
  if [ -n "$server_pid" ]; then
    kill -TERM "$server_pid" >/dev/null 2>&1 || true
    wait "$server_pid" >/dev/null 2>&1 || true
  fi
  rm -rf "$tmpdir"
}
trap cleanup EXIT INT TERM

mkdir -p "$project/.ai_project" "$fake_bin"
git init -b feature/release-view "$project" >/dev/null
git -C "$project" config user.email aiops@example.test
git -C "$project" config user.name "AI Ops Test"
printf '%s\n' '1.2.3' > "$project/VERSION"
printf '%s\n' '# fixture' > "$project/README.md"
git -C "$project" add VERSION README.md
git -C "$project" commit -m "seed GitHub release fixture" >/dev/null

cat > "$fake_bin/gh" <<'EOF'
#!/usr/bin/env sh
set -eu
printf '%s\n' "$*" >> "${AIOPS_TEST_GH_LOG:?}"
mode="${AIOPS_TEST_GH_MODE:-success}"

case "$1 $2" in
  "auth status")
    [ "$mode" != "auth-fail" ] || {
      printf '%s\n' 'not logged into any GitHub hosts' >&2
      exit 1
    }
    printf '%s\n' 'authenticated'
    ;;
  "repo view")
    printf '%s\n' '{"nameWithOwner":"example/dashboard-project","url":"https://github.com/example/dashboard-project"}'
    ;;
  "pr list")
    printf '%s\n' '[{"number":42,"title":"Release dashboard","url":"https://github.com/example/dashboard-project/pull/42","headRefName":"feature/release-view","baseRefName":"main","isDraft":false,"mergeable":"MERGEABLE"}]'
    ;;
  "pr checks")
    printf '%s\n' '[{"name":"release safety","state":"SUCCESS","bucket":"pass","link":"https://github.com/example/check/1","workflow":"CI"},{"name":"shell, schema, e2e","state":"IN_PROGRESS","bucket":"pending","link":"https://github.com/example/check/2","workflow":"CI"}]'
    exit 8
    ;;
  "run list")
    [ "$mode" != "partial" ] || {
      printf '%s\n' 'workflow API unavailable' >&2
      exit 1
    }
    printf '%s\n' '[{"databaseId":101,"workflowName":"CI","displayTitle":"Release dashboard","status":"completed","conclusion":"success","url":"https://github.com/example/run/101","headSha":"abc123","createdAt":"2026-08-11T00:00:00Z","updatedAt":"2026-08-11T00:01:00Z","event":"pull_request"}]'
    ;;
  "release view")
    [ "$mode" != "no-release" ] || {
      printf '%s\n' 'no releases found' >&2
      exit 1
    }
    printf '%s\n' '{"tagName":"v1.2.3","name":"Version 1.2.3","url":"https://github.com/example/dashboard-project/releases/tag/v1.2.3","publishedAt":"2026-08-10T00:00:00Z","isDraft":false,"isPrerelease":false,"targetCommitish":"main"}'
    ;;
  *)
    printf '%s\n' "unexpected gh command: $*" >&2
    exit 1
    ;;
esac
EOF
chmod +x "$fake_bin/gh"

run_aiops() {
  PATH="$fake_bin:$PATH" AIOPS_TEST_GH_LOG="$gh_log" AIOPS_TEST_GH_MODE="${AIOPS_TEST_GH_MODE:-success}" "$repo_root/bin/aiops" "$@"
}

rm -f "$gh_log"
run_aiops project dashboard --target "$project" --view release --json > "$tmpdir/local.json"
[ ! -e "$gh_log" ] || {
  printf '%s\n' "dashboard called gh without --github" >&2
  exit 1
}
ruby -rjson -e '
  data = JSON.parse(File.read(ARGV[0]))
  abort("local dashboard unexpectedly includes GitHub") if data.dig("views", "release").key?("github")
' "$tmpdir/local.json"

run_aiops project dashboard --target "$project" --view release --github --json > "$tmpdir/github.json"
run_aiops validate project-dashboard "$tmpdir/github.json" >/dev/null
ruby -rjson -e '
  data = JSON.parse(File.read(ARGV[0]))
  github = data.dig("views", "release", "github") || abort("GitHub projection missing")
  abort("GitHub status mismatch") unless github["status"] == "available"
  abort("repository mismatch") unless github.dig("repository", "name_with_owner") == "example/dashboard-project"
  abort("PR mismatch") unless github.dig("pull_request", "number") == 42 && github.dig("pull_request", "mergeable") == "MERGEABLE"
  checks = github["required_checks"]
  abort("required check counts mismatch") unless checks.values_at("status", "total", "passing", "failing", "pending") == ["pending", 2, 1, 0, 1]
  abort("latest run mismatch") unless github.dig("latest_run", "conclusion") == "success"
  abort("release version mismatch") unless github.dig("release", "tag") == "v1.2.3" && github.dig("release", "version_state") == "match"
' "$tmpdir/github.json"

ruby -rjson -e '
  source = JSON.parse(File.read(ARGV.shift))
  output_dir = ARGV.shift
  mutations = {
    "repository-number" => 42,
    "repository-empty" => {},
    "repository-name-missing" => {"url" => "https://github.com/example/dashboard-project"},
    "repository-name-invalid" => {"name_with_owner" => "invalid", "url" => "https://github.com/example/dashboard-project"},
    "repository-url-invalid" => {"name_with_owner" => "example/dashboard-project", "url" => 42}
  }
  mutations.each do |name, repository|
    document = Marshal.load(Marshal.dump(source))
    document.fetch("views").fetch("release").fetch("github")["repository"] = repository
    File.write(File.join(output_dir, "#{name}.json"), JSON.pretty_generate(document))
  end
' "$tmpdir/github.json" "$tmpdir"

for invalid_json in "$tmpdir"/repository-*.json; do
  if run_aiops validate project-dashboard "$invalid_json" > "$tmpdir/invalid-schema.out" 2>&1; then
    printf '%s\n' "invalid GitHub repository projection should fail: $invalid_json" >&2
    exit 1
  fi
  grep -q 'schema_error:' "$tmpdir/invalid-schema.out" || {
    printf '%s\n' "invalid GitHub repository schema error missing: $invalid_json" >&2
    exit 1
  }
done

mkdir -p "$tmpdir/no-gh-bin"
PATH="$tmpdir/no-gh-bin:/usr/bin:/bin" ruby "$repo_root/runtime/github_release_status.rb" \
  --target "$project" > "$tmpdir/no-gh.json"
ruby -rjson -e '
  data = JSON.parse(File.read(ARGV[0]))
  abort("missing gh should be unavailable") unless data["status"] == "unavailable" && data["reason_code"] == "gh_missing"
' "$tmpdir/no-gh.json"

mkdir -p "$tmpdir/non-git"
PATH="$tmpdir/no-gh-bin:/usr/bin:/bin" ruby "$repo_root/runtime/github_release_status.rb" \
  --target "$tmpdir/non-git" > "$tmpdir/non-git.json" 2> "$tmpdir/non-git.err"
[ ! -s "$tmpdir/non-git.err" ] || {
  printf '%s\n' "non-Git branch detection leaked stderr" >&2
  cat "$tmpdir/non-git.err" >&2
  exit 1
}

run_aiops project dashboard --target "$project" --view release --github --level detail --color never > "$tmpdir/github-terminal.out"
grep -q '^GitHub Release Status$' "$tmpdir/github-terminal.out" || {
  printf '%s\n' "advanced GitHub release section missing" >&2
  exit 1
}
grep -q 'Required Checks: pending (1 pass / 0 fail / 1 pending / 0 skipped)' "$tmpdir/github-terminal.out" || {
  printf '%s\n' "required check terminal summary missing" >&2
  exit 1
}

run_aiops release --target "$project" --github --color never > "$tmpdir/github-user.out"
grep -q '^GitHub 상태$' "$tmpdir/github-user.out" || {
  printf '%s\n' "user GitHub release section missing" >&2
  exit 1
}
grep -q '필수 검사: 진행 중 (통과 1 / 실패 0 / 대기 1 / 건너뜀 0)' "$tmpdir/github-user.out" || {
  printf '%s\n' "user required check summary missing" >&2
  exit 1
}

run_aiops project dashboard --target "$project" --view release --github --format html --output "$tmpdir/release.html" >/dev/null
grep -q 'GitHub 출시 상태' "$tmpdir/release.html" || {
  printf '%s\n' "GitHub HTML panel missing" >&2
  exit 1
}
grep -q '#42 Release dashboard' "$tmpdir/release.html" || {
  printf '%s\n' "GitHub HTML PR summary missing" >&2
  exit 1
}

rm -f "$gh_log"
run_aiops project dashboard --target "$project" --view release --github --repo explicit/repository --json > "$tmpdir/explicit-repo.json"
if grep -q '^repo view' "$gh_log"; then
  printf '%s\n' "explicit GitHub repository still triggered repo detection" >&2
  exit 1
fi
ruby -rjson -e '
  data = JSON.parse(File.read(ARGV[0]))
  abort("explicit repository missing") unless data.dig("views", "release", "github", "repository", "name_with_owner") == "explicit/repository"
' "$tmpdir/explicit-repo.json"

AIOPS_TEST_GH_MODE=auth-fail run_aiops release --target "$project" --github --color never > "$tmpdir/auth-fail.out"
grep -q '연결 상태: 확인 불가' "$tmpdir/auth-fail.out" || {
  printf '%s\n' "GitHub authentication fallback missing" >&2
  exit 1
}
grep -q 'GitHub CLI 인증이 필요합니다' "$tmpdir/auth-fail.out" || {
  printf '%s\n' "GitHub authentication guidance missing" >&2
  exit 1
}

AIOPS_TEST_GH_MODE=partial run_aiops project dashboard --target "$project" --view release --github --json > "$tmpdir/partial.json"
ruby -rjson -e '
  data = JSON.parse(File.read(ARGV[0]))
  github = data.dig("views", "release", "github")
  abort("partial GitHub status missing") unless github["status"] == "partial" && github.dig("latest_run", "status") == "unavailable"
' "$tmpdir/partial.json"

AIOPS_TEST_GH_MODE=no-release run_aiops project dashboard --target "$project" --view release --github --json > "$tmpdir/no-release.json"
ruby -rjson -e '
  data = JSON.parse(File.read(ARGV[0]))
  release = data.dig("views", "release", "github", "release")
  abort("missing release state mismatch") unless release["status"] == "not_found" && release["version_state"] == "release_missing"
' "$tmpdir/no-release.json"

for invalid_command in \
  "project dashboard --target $project --view main --github" \
  "project dashboard --target $project --view release --repo example/project" \
  "project dashboard --target $project --view release --github --repo invalid"
do
  if PATH="$fake_bin:$PATH" AIOPS_TEST_GH_LOG="$gh_log" "$repo_root/bin/aiops" $invalid_command > "$tmpdir/invalid.out" 2>&1; then
    printf '%s\n' "invalid GitHub dashboard options should fail: $invalid_command" >&2
    exit 1
  fi
done

if run_aiops project dashboard preset add invalid-github-view \
  --target "$project" --view main --github > "$tmpdir/invalid-preset.out" 2>&1; then
  printf '%s\n' "GitHub preset with a non-release view should fail" >&2
  exit 1
fi
grep -q 'github requires view release' "$tmpdir/invalid-preset.out" || {
  printf '%s\n' "invalid GitHub preset error missing" >&2
  exit 1
}

if run_aiops project dashboard preset add invalid-github-repo \
  --target "$project" --view release --repo example/dashboard-project > "$tmpdir/invalid-preset.out" 2>&1; then
  printf '%s\n' "GitHub repository preset without --github should fail" >&2
  exit 1
fi
grep -q 'repo requires github' "$tmpdir/invalid-preset.out" || {
  printf '%s\n' "invalid GitHub repository preset error missing" >&2
  exit 1
}

invalid_repo_index=0
for invalid_repo in \
  invalid \
  'owner/' \
  '/repo' \
  'owner/repo/extra' \
  'owner repo/name' \
  'owner/re!po'
do
  invalid_repo_index=$((invalid_repo_index + 1))
  if run_aiops project dashboard preset add "invalid-repo-$invalid_repo_index" \
    --target "$project" --view release --github --repo "$invalid_repo" > "$tmpdir/invalid-preset.out" 2>&1; then
    printf '%s\n' "invalid GitHub repository preset should fail: $invalid_repo" >&2
    exit 1
  fi
  grep -q 'repo must use owner/name format' "$tmpdir/invalid-preset.out" || {
    printf '%s\n' "invalid GitHub repository format guidance missing: $invalid_repo" >&2
    exit 1
  }
done

ruby -rjson -e '
  File.write(ARGV[0], JSON.pretty_generate({
    "schema" => "aiops.dashboard_presets.v1",
    "presets" => {
      "invalid-repository" => {
        "view" => "release",
        "github" => true,
        "repo" => "invalid"
      }
    }
  }))
' "$project/.ai_project/dashboard_presets.json"
if run_aiops validate dashboard-presets "$project/.ai_project/dashboard_presets.json" > "$tmpdir/invalid-preset.out" 2>&1; then
  printf '%s\n' "invalid repository in preset file should fail validation" >&2
  exit 1
fi
grep -Eq 'pattern mismatch|repo must use owner/name format' "$tmpdir/invalid-preset.out" || {
  printf '%s\n' "invalid preset repository validation guidance missing" >&2
  exit 1
}
rm -f "$project/.ai_project/dashboard_presets.json"

run_aiops project dashboard preset add github-release \
  --target "$project" \
  --view release \
  --github \
  --repo example/dashboard-project >/dev/null
run_aiops project dashboard --target "$project" --preset github-release --json > "$tmpdir/preset.json"
ruby -rjson -e '
  data = JSON.parse(File.read(ARGV[0]))
  abort("GitHub preset expansion missing") unless data.dig("views", "release", "github", "repository", "name_with_owner") == "example/dashboard-project"
' "$tmpdir/preset.json"

run_aiops project dashboard preset add --help > "$tmpdir/preset-help.out"
grep -q -- '--github' "$tmpdir/preset-help.out" || {
  printf '%s\n' "GitHub preset help missing --github" >&2
  exit 1
}
grep -q -- '--repo OWNER/NAME' "$tmpdir/preset-help.out" || {
  printf '%s\n' "GitHub preset help missing --repo" >&2
  exit 1
}

if ruby -rsocket -e 'server = TCPServer.new("127.0.0.1", 0); server.close' >/dev/null 2>&1; then
  : > "$gh_log"
  PATH="$fake_bin:$PATH" AIOPS_TEST_GH_LOG="$gh_log" AIOPS_TEST_GH_MODE=success \
    "$repo_root/bin/aiops" project dashboard \
      --target "$project" --view release --github --repo example/dashboard-project \
      --serve --port 0 --refresh 0 > "$tmpdir/server.log" 2>&1 &
  server_pid="$!"

  attempt=0
  while [ "$attempt" -lt 100 ]; do
    port="$(sed -n 's#^url: http://127\.0\.0\.1:\([0-9][0-9]*\)/$#\1#p' "$tmpdir/server.log" | tail -1)"
    [ -n "$port" ] && break
    kill -0 "$server_pid" >/dev/null 2>&1 || {
      cat "$tmpdir/server.log" >&2
      printf '%s\n' "GitHub dashboard server exited before startup" >&2
      exit 1
    }
    sleep 0.05
    attempt=$((attempt + 1))
  done
  [ -n "${port:-}" ] || {
    cat "$tmpdir/server.log" >&2
    printf '%s\n' "GitHub dashboard server port missing" >&2
    exit 1
  }

  request_dashboard_json() {
    output="$1"
    ruby -rsocket -e '
      port, output = ARGV
      socket = TCPSocket.new("127.0.0.1", Integer(port))
      socket.write("GET /dashboard.json HTTP/1.1\r\nHost: 127.0.0.1\r\nConnection: close\r\n\r\n")
      response = socket.read
      headers, body = response.split("\r\n\r\n", 2)
      abort("dashboard request failed") unless headers.to_s.lines.first.to_s.include?(" 200 ")
      File.write(output, body.to_s)
    ' "$port" "$output"
  }

  request_dashboard_json "$tmpdir/served-first.json"
  first_calls="$(wc -l < "$gh_log" | tr -d ' ')"
  request_dashboard_json "$tmpdir/served-second.json"
  second_calls="$(wc -l < "$gh_log" | tr -d ' ')"
  [ "$second_calls" -gt "$first_calls" ] || {
    printf '%s\n' "served GitHub status was not recollected per request" >&2
    exit 1
  }
  ruby -rjson -e '
    data = JSON.parse(File.read(ARGV[0]))
    github = data.dig("views", "release", "github")
    abort("served GitHub projection missing") unless github && github["status"] == "available"
  ' "$tmpdir/served-second.json"

  kill -TERM "$server_pid"
  wait "$server_pid"
  server_pid=""
fi

printf '%s\n' "ok: GitHub release view"

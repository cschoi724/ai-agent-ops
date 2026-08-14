#!/usr/bin/env sh
set -eu

repo_root="$(CDPATH= cd "$(dirname "$0")/.." && pwd)"
tmpdir="$(mktemp -d "${TMPDIR:-/tmp}/aiops-e2e-model-advisor.XXXXXX")"
trap 'rm -rf "$tmpdir"' EXIT INT TERM
project="$tmpdir/project"
mkdir -p "$project/.ai_project/tasks/active" "$project/docs" "$project/src" "$project/schemas" "$project/.codex" "$project/.claude"
ln -s "$repo_root" "$project/.ai"

cat > "$project/.ai_project/operating_model.md" <<'EOF'
---
schema: aiops.operating_model.v1
project: Model Advisor Fixture
canonical_status_ref:
---
EOF
cat > "$project/.ai_project/source_of_truth.md" <<'EOF'
# Source
EOF
cat > "$project/docs/README.md" <<'EOF'
# Docs
EOF
cat > "$project/src/app.rb" <<'EOF'
puts "app"
EOF
cat > "$project/schemas/public.schema.json" <<'EOF'
{}
EOF

create_task() {
  id="$1"
  workflow="$2"
  type="$3"
  allowed_path="$4"
  capability="$5"
  cat > "$project/.ai_project/tasks/active/${id}.md" <<EOF
---
schema: aiops.task.v1
id: $id
title: $id model advisor fixture
status: approved
type: $type
priority: medium
workflow: $workflow
target_agent: Execution Agent
target_role: Execution Role
required_capabilities: [$capability]
depends_on: []
blocks: []
allowed_paths: [$allowed_path]
source_of_truth: [.ai_project/source_of_truth.md]
created_by: Test
locked_by:
locked_at:
lock_session:
report_to: .ai_project/reports/${id}_task-report.md
qa_to: .ai_project/qa/${id}_qa-report.md
---

# $id
EOF
}

create_task T-20260814-101 docs docs docs/ documentation
create_task T-20260814-102 feature feature src/ implementation
create_task T-20260814-103 feature feature schemas/ implementation
create_task T-20260814-104 feature feature src/ visual_qa

git -C "$project" init -q
git -C "$project" add .
git -C "$project" -c user.name='AI Ops Test' -c user.email='test@example.invalid' commit -q -m fixture

cat > "$project/.codex/config.toml" <<'EOF'
model = "gpt-5.6-terra"
model_reasoning_effort = "medium"

[agents]
default_subagent_model = "gpt-5.6-luna"
default_subagent_reasoning_effort = "minimal"
EOF

cat > "$project/.claude/settings.json" <<'EOF'
{
  "model": "sonnet",
  "effortLevel": "medium",
  "availableModels": ["haiku", "sonnet", "opus", "opusplan", "claude-sonnet-fixture", "claude-opus-fixture"],
  "env": {
    "ANTHROPIC_DEFAULT_SONNET_MODEL": "claude-sonnet-fixture",
    "ANTHROPIC_DEFAULT_OPUS_MODEL": "claude-opus-fixture",
    "CLAUDE_CODE_SUBAGENT_MODEL": "haiku"
  }
}
EOF

recommend() {
  name="$1"
  shift
  "$repo_root/bin/aiops" model recommend --target "$project" "$@" --json > "$tmpdir/$name.json"
  "$repo_root/bin/aiops" validate model-recommendation "$tmpdir/$name.json" >/dev/null
}

"$repo_root/bin/aiops" validate model-catalog "$repo_root/runtime/model_catalog.json" >/dev/null

recommend codex-light --provider codex --role execution --task T-20260814-101 --codex-config "$project/.codex/config.toml"
recommend codex-standard --provider codex --role execution --task T-20260814-102 --codex-config "$project/.codex/config.toml"
recommend codex-strict --provider codex --role execution --task T-20260814-103 --codex-config "$project/.codex/config.toml"
recommend codex-vision --provider codex --role execution --task T-20260814-104 --codex-config "$project/.codex/config.toml"

ruby -rjson -e '
  light, standard, strict, vision = ARGV.map { |path| JSON.parse(File.read(path)) }
  abort("configured Codex session missing") unless light.dig("recommendations", "session", "requested_model") == "gpt-5.6-terra"
  abort("configured Codex effort missing") unless light.dig("recommendations", "session", "effort") == "medium"
  abort("Light Task should use luna") unless light.dig("recommendations", "task", "requested_model") == "gpt-5.6-luna"
  abort("Light Task should use low effort") unless light.dig("recommendations", "task", "effort") == "low"
  abort("configured worker missing") unless light.dig("recommendations", "delegated_worker", "requested_model") == "gpt-5.6-luna"
  abort("configured worker effort missing") unless light.dig("recommendations", "delegated_worker", "effort") == "minimal"
  abort("configured worker source missing") unless light.dig("recommendations", "delegated_worker", "source") == "configured_worker"
  abort("Standard coding Task should use Codex model") unless standard.dig("recommendations", "task", "requested_model") == "gpt-5.3-codex"
  abort("Standard Task must require independent verification") unless standard.dig("recommendations", "verification", "required") == true
  abort("Strict Task should use sol") unless strict.dig("recommendations", "task", "requested_model") == "gpt-5.6-sol"
  abort("Strict Task should use xhigh") unless strict.dig("recommendations", "task", "effort") == "xhigh"
  abort("vision Task should use vision profile") unless vision.dig("recommendations", "task", "profile") == "vision"
  abort("vision Task should use high effort") unless vision.dig("recommendations", "task", "effort") == "high"
  abort("advisor must remain advisory") unless strict["advisory_only"] == true
' "$tmpdir/codex-light.json" "$tmpdir/codex-standard.json" "$tmpdir/codex-strict.json" "$tmpdir/codex-vision.json"

recommend claude-strict --provider claude-code --role execution --task T-20260814-103 --claude-settings "$project/.claude/settings.json"
ruby -rjson -e '
  data = JSON.parse(File.read(ARGV[0]))
  abort("Claude session alias missing") unless data.dig("recommendations", "session", "requested_model") == "sonnet"
  abort("Claude alias was not resolved") unless data.dig("recommendations", "session", "resolved_model") == "claude-sonnet-fixture"
  abort("Claude Strict task should use opusplan") unless data.dig("recommendations", "task", "requested_model") == "opusplan"
  abort("Claude worker setting missing") unless data.dig("recommendations", "delegated_worker", "requested_model") == "haiku"
' "$tmpdir/claude-strict.json"

cat > "$tmpdir/claude-exact-settings.json" <<'EOF'
{
  "model": "claude-sonnet-4-6",
  "effortLevel": "high",
  "availableModels": ["claude-sonnet-4-6"]
}
EOF
recommend claude-exact --provider claude-code --role execution --claude-settings "$tmpdir/claude-exact-settings.json"
ruby -rjson -e '
  data = JSON.parse(File.read(ARGV[0]))
  abort("Claude exact session model missing") unless data.dig("recommendations", "session", "requested_model") == "claude-sonnet-4-6"
  abort("Claude exact model must resolve to itself") unless data.dig("recommendations", "session", "resolved_model") == "claude-sonnet-4-6"
  abort("Claude exact model should keep configured effort") unless data.dig("recommendations", "session", "effort") == "high"
  abort("Claude exact model recommendation should be ready") unless data["ready"] == true
  abort("recommendation provider command missing") unless data.dig("provider", "command") == "claude"
  data.fetch("recommendations").each_value do |item|
    abort("recommendation availability must be boolean") unless [true, false].include?(item["available"])
    fallback = item["fallback"]
    abort("fallback availability must be boolean") if fallback && ![true, false].include?(fallback["available"])
  end
' "$tmpdir/claude-exact.json"

cat > "$tmpdir/claude-1m-settings.json" <<'EOF'
{
  "model": "sonnet[1m]",
  "effortLevel": "high",
  "availableModels": ["sonnet[1m]", "opus[1m]"]
}
EOF
recommend claude-1m --provider claude-code --role execution --claude-settings "$tmpdir/claude-1m-settings.json"
ruby -rjson -e '
  data = JSON.parse(File.read(ARGV[0]))
  abort("Claude 1M alias missing") unless data.dig("recommendations", "session", "requested_model") == "sonnet[1m]"
  abort("floating 1M alias must not invent exact model") unless data.dig("recommendations", "session", "resolved_model").nil?
  abort("floating alias warning missing") unless data["warnings"].any? { |warning| warning.include?("floating alias sonnet[1m]") }
' "$tmpdir/claude-1m.json"

recommend codex-effort --provider codex --role execution --task T-20260814-103 --model gpt-5.6-sol --effort max --codex-config "$project/.codex/config.toml"
recommend claude-effort --provider claude-code --role execution --task T-20260814-102 --model sonnet --effort xhigh --claude-settings "$project/.claude/settings.json"
ruby -rjson -e '
  codex = JSON.parse(File.read(ARGV[0]))
  claude = JSON.parse(File.read(ARGV[1]))
  abort("Codex max should clamp to xhigh") unless codex.dig("recommendations", "task", "effort") == "xhigh"
  abort("Claude floating alias should preserve provider-handled xhigh") unless claude.dig("recommendations", "task", "effort") == "xhigh"
  abort("CLI source missing") unless codex.dig("recommendations", "task", "source") == "cli_override"
' "$tmpdir/codex-effort.json" "$tmpdir/claude-effort.json"

cat > "$tmpdir/fallback-overrides.json" <<'EOF'
{
  "schema": "aiops.model_overrides.v1",
  "managed_allowlist": {"codex": ["gpt-5.6-terra", "gpt-5.3-codex"]},
  "providers": {
    "codex": {
      "profiles": {
        "coding": {"model": "gpt-5.6-sol", "effort": "high", "fallback": "gpt-5.6-terra"}
      }
    }
  }
}
EOF
"$repo_root/bin/aiops" validate model-overrides "$tmpdir/fallback-overrides.json" >/dev/null
recommend fallback --provider codex --role execution --task T-20260814-102 --override-file "$tmpdir/fallback-overrides.json" --codex-config "$project/.codex/config.toml"
ruby -rjson -e '
  data = JSON.parse(File.read(ARGV[0]))
  task = data.dig("recommendations", "task")
  abort("allowed fallback not selected") unless task["requested_model"] == "gpt-5.6-terra" && task["source"] == "fallback"
' "$tmpdir/fallback.json"

cat > "$tmpdir/blocked-overrides.json" <<'EOF'
{
  "schema": "aiops.model_overrides.v1",
  "managed_allowlist": {"codex": ["organization-private-model"]}
}
EOF
if "$repo_root/bin/aiops" model recommend --target "$project" --provider codex --role execution --task T-20260814-102 --override-file "$tmpdir/blocked-overrides.json" --codex-config "$project/.codex/config.toml" --json > "$tmpdir/blocked.json"; then
  printf '%s\n' "unavailable required models should block recommendation" >&2
  exit 1
fi
"$repo_root/bin/aiops" validate model-recommendation "$tmpdir/blocked.json" >/dev/null
ruby -rjson -e 'd=JSON.parse(File.read(ARGV[0])); abort("blocker missing") if d["ready"] || d["blockers"].empty?' "$tmpdir/blocked.json"

cat > "$tmpdir/custom-overrides.json" <<'EOF'
{
  "schema": "aiops.model_overrides.v1",
  "providers": {
    "local_provider": {
      "display_name": "Local Provider",
      "command": "local-ai",
      "models": {
        "local-fast": {"alias": false, "efforts": ["low"], "vision": false},
        "local-main": {"alias": false, "efforts": ["medium", "high"], "vision": true}
      },
      "profiles": {
        "fast": {"model": "local-fast", "effort": "low", "fallback": "local-main"},
        "balanced": {"model": "local-main", "effort": "medium", "fallback": "local-fast"},
        "coding": {"model": "local-main", "effort": "high", "fallback": "local-fast"},
        "deep": {"model": "local-main", "effort": "high", "fallback": "local-fast"},
        "independent_review": {"model": "local-main", "effort": "high", "fallback": "local-fast"},
        "vision": {"model": "local-main", "effort": "high", "fallback": "local-fast"}
      }
    }
  }
}
EOF
"$repo_root/bin/aiops" validate model-overrides "$tmpdir/custom-overrides.json" >/dev/null
recommend custom --provider local-provider --role lead --override-file "$tmpdir/custom-overrides.json"
ruby -rjson -e 'd=JSON.parse(File.read(ARGV[0])); abort("custom provider failed") unless d.dig("provider", "id") == "local_provider" && d.dig("recommendations", "task", "requested_model") == "local-main"' "$tmpdir/custom.json"

ruby -rjson -e '
  data=JSON.parse(File.read(ARGV[0])); data["providers"]["local_provider"]["profiles"]["deep"]["model"]="missing-model"; File.write(ARGV[1], JSON.pretty_generate(data))
' "$tmpdir/custom-overrides.json" "$tmpdir/invalid-override-reference.json"
if "$repo_root/bin/aiops" validate model-overrides "$tmpdir/invalid-override-reference.json" >/dev/null 2>&1; then
  printf '%s\n' "override with unknown profile model should fail" >&2
  exit 1
fi

ruby -rjson -e '
  data=JSON.parse(File.read(ARGV[0])); data["providers"]["local_provider"]["profiles"].delete("vision"); File.write(ARGV[1], JSON.pretty_generate(data))
' "$tmpdir/custom-overrides.json" "$tmpdir/incomplete-custom-provider.json"
if "$repo_root/bin/aiops" validate model-overrides "$tmpdir/incomplete-custom-provider.json" >/dev/null 2>&1; then
  printf '%s\n' "incomplete custom provider should fail" >&2
  exit 1
fi

cat > "$tmpdir/unknown-managed-provider.json" <<'EOF'
{
  "schema": "aiops.model_overrides.v1",
  "managed_allowlist": {"codeex": ["gpt-5.6-luna"]}
}
EOF
if "$repo_root/bin/aiops" validate model-overrides "$tmpdir/unknown-managed-provider.json" >/dev/null 2>&1; then
  printf '%s\n' "unknown managed allowlist provider should fail" >&2
  exit 1
fi
if "$repo_root/bin/aiops" model recommend --target "$project" --provider codex --role execution --override-file "$tmpdir/unknown-managed-provider.json" --codex-config "$project/.codex/config.toml" >/dev/null 2> "$tmpdir/unknown-managed-provider.err"; then
  printf '%s\n' "unknown managed allowlist provider should fail at runtime" >&2
  exit 1
fi
grep -q 'unknown providers: codeex' "$tmpdir/unknown-managed-provider.err"

cat > "$tmpdir/unknown-profile.json" <<'EOF'
{
  "schema": "aiops.model_overrides.v1",
  "providers": {"codex": {"profiles": {"turbo": {"model": "gpt-5.6-luna", "effort": "low", "fallback": "gpt-5.6-terra"}}}}
}
EOF
if "$repo_root/bin/aiops" validate model-overrides "$tmpdir/unknown-profile.json" >/dev/null 2>&1; then
  printf '%s\n' "unknown override profile should fail" >&2
  exit 1
fi

cat > "$tmpdir/malformed-managed.json" <<'EOF'
{
  "schema": "aiops.model_overrides.v1",
  "managed_allowlist": []
}
EOF
if "$repo_root/bin/aiops" model recommend --target "$project" --provider codex --role execution --override-file "$tmpdir/malformed-managed.json" --codex-config "$project/.codex/config.toml" >/dev/null 2> "$tmpdir/malformed-managed.err"; then
  printf '%s\n' "malformed managed allowlist should fail" >&2
  exit 1
fi
grep -q '^error: managed model allowlist must be an object$' "$tmpdir/malformed-managed.err"
if grep -q 'runtime/model_advisor.rb:' "$tmpdir/malformed-managed.err"; then
  printf '%s\n' "malformed override leaked a stack trace" >&2
  exit 1
fi

cat > "$tmpdir/malformed-model-definition.json" <<'EOF'
{
  "schema": "aiops.model_overrides.v1",
  "providers": {"codex": {"models": {"broken-model": {}}}}
}
EOF
cat > "$tmpdir/malformed-profile-extra.json" <<'EOF'
{
  "schema": "aiops.model_overrides.v1",
  "providers": {
    "codex": {
      "profiles": {
        "coding": {
          "model": "gpt-5.3-codex",
          "effort": "high",
          "fallback": "gpt-5.6-terra",
          "unexpected": true
        }
      }
    }
  }
}
EOF
for override in "$tmpdir/malformed-model-definition.json" "$tmpdir/malformed-profile-extra.json"; do
  if "$repo_root/bin/aiops" validate model-overrides "$override" >/dev/null 2>&1; then
    printf '%s\n' "nested schema-invalid override should fail validation: $override" >&2
    exit 1
  fi
  if "$repo_root/bin/aiops" model recommend --target "$project" --provider codex --role execution --override-file "$override" --codex-config "$project/.codex/config.toml" >/dev/null 2> "$tmpdir/nested-override.err"; then
    printf '%s\n' "nested schema-invalid override should fail at runtime: $override" >&2
    exit 1
  fi
  if grep -q 'runtime/model_advisor.rb:' "$tmpdir/nested-override.err"; then
    printf '%s\n' "nested schema-invalid override leaked a stack trace: $override" >&2
    exit 1
  fi
done

"$repo_root/bin/aiops" model recommend --target "$project" --provider codex --role execution --task T-20260814-102 --codex-config "$project/.codex/config.toml" --locale ko --json > "$tmpdir/ko.json"
"$repo_root/bin/aiops" model recommend --target "$project" --provider codex --role execution --task T-20260814-102 --codex-config "$project/.codex/config.toml" --locale en --json > "$tmpdir/en.json"
ruby -rjson -e '
  a=JSON.parse(File.read(ARGV[0])); b=JSON.parse(File.read(ARGV[1])); a.delete("generated_at"); b.delete("generated_at"); abort("locale changed machine output") unless a == b
' "$tmpdir/ko.json" "$tmpdir/en.json"

"$repo_root/bin/aiops" model recommend --target "$project" --provider codex --role execution --task T-20260814-102 --codex-config "$project/.codex/config.toml" --locale ko > "$tmpdir/ko.out"
"$repo_root/bin/aiops" model recommend --target "$project" --provider codex --role execution --task T-20260814-102 --codex-config "$project/.codex/config.toml" --locale en > "$tmpdir/en.out"
grep -q '^AI Ops 모델 추천$' "$tmpdir/ko.out"
grep -q '^AI Ops model recommendation$' "$tmpdir/en.out"
grep -q '자동 변경하지 않습니다' "$tmpdir/ko.out"

cat > "$tmpdir/malformed.json" <<'EOF'
{
EOF
if "$repo_root/bin/aiops" model recommend --target "$project" --provider claude-code --role execution --claude-settings "$tmpdir/malformed.json" >/dev/null 2> "$tmpdir/malformed.err"; then
  printf '%s\n' "malformed provider settings should fail" >&2
  exit 1
fi
grep -q '^error: invalid model advisor input:' "$tmpdir/malformed.err"
if grep -q 'runtime/model_advisor.rb:' "$tmpdir/malformed.err"; then
  printf '%s\n' "malformed settings leaked a stack trace" >&2
  exit 1
fi

cat > "$tmpdir/malformed.toml" <<'EOF'
model = [
EOF
if "$repo_root/bin/aiops" model recommend --target "$project" --provider codex --role execution --codex-config "$tmpdir/malformed.toml" >/dev/null 2> "$tmpdir/malformed-toml.err"; then
  printf '%s\n' "malformed watched Codex TOML should fail" >&2
  exit 1
fi
grep -q '^error: invalid Codex config ' "$tmpdir/malformed-toml.err"
if grep -q 'runtime/model_advisor.rb:' "$tmpdir/malformed-toml.err"; then
  printf '%s\n' "malformed Codex config leaked a stack trace" >&2
  exit 1
fi

for args in '--effort impossible' '--task INVALID' '--unknown-option'; do
  if "$repo_root/bin/aiops" model recommend --target "$project" --provider codex --role execution $args >/dev/null 2> "$tmpdir/invalid-option.err"; then
    printf '%s\n' "invalid model advisor option should fail: $args" >&2
    exit 1
  fi
  if grep -q 'runtime/model_advisor.rb:' "$tmpdir/invalid-option.err"; then
    printf '%s\n' "invalid option leaked a stack trace: $args" >&2
    exit 1
  fi
done

if "$repo_root/bin/aiops" model recommend --target "$project" --provider codex --role execution --model 'gpt;touch-pwned' --codex-config "$project/.codex/config.toml" >/dev/null 2> "$tmpdir/unsafe.err"; then
  printf '%s\n' "unsafe model ID should fail" >&2
  exit 1
fi
grep -q 'unsupported characters' "$tmpdir/unsafe.err"
[ ! -e "$project/touch-pwned" ]

mkdir -p "$tmpdir/bin"
printf '#!/bin/sh\nexit 0\n' > "$tmpdir/bin/codex"
printf '#!/bin/sh\nexit 0\n' > "$tmpdir/bin/claude"
chmod +x "$tmpdir/bin/codex" "$tmpdir/bin/claude"
if env -u CODEX_HOME -u CLAUDE_CONFIG_DIR -u CLAUDE_CODE_ENTRYPOINT -u AIOPS_MODEL_PROVIDER -u AIOPS_AGENT_TOOL PATH="$tmpdir/bin:$PATH" \
  "$repo_root/bin/aiops" model recommend --target "$project" --role execution >/dev/null 2> "$tmpdir/ambiguous.err"; then
  printf '%s\n' "ambiguous provider detection should fail" >&2
  exit 1
fi
grep -q 'multiple model providers detected' "$tmpdir/ambiguous.err"

ruby -rjson -e '
  data=JSON.parse(File.read(ARGV[0])); data["recommendations"]["task"]["source"]="invalid"; File.write(ARGV[1], JSON.pretty_generate(data))
' "$tmpdir/codex-standard.json" "$tmpdir/invalid-recommendation.json"
if "$repo_root/bin/aiops" validate model-recommendation "$tmpdir/invalid-recommendation.json" >/dev/null 2>&1; then
  printf '%s\n' "invalid recommendation mutation should fail" >&2
  exit 1
fi

ruby -rjson -e '
  data=JSON.parse(File.read(ARGV[0])); data["recommendations"]["task"]["launch_command"]=["codex;touch", "/tmp/pwned"]; File.write(ARGV[1], JSON.pretty_generate(data))
' "$tmpdir/codex-standard.json" "$tmpdir/unsafe-launch-recommendation.json"
if "$repo_root/bin/aiops" validate model-recommendation "$tmpdir/unsafe-launch-recommendation.json" >/dev/null 2>&1; then
  printf '%s\n' "unsafe launch argv should fail recommendation validation" >&2
  exit 1
fi

cp "$tmpdir/malformed-profile-extra.json" "$project/.ai_project/model_overrides.json"
if "$repo_root/bin/aiops" model recommend --target "$project" --provider codex --role execution --codex-config "$project/.codex/config.toml" >/dev/null 2> "$tmpdir/auto-override.err"; then
  printf '%s\n' "auto-discovered schema-invalid override should fail at runtime" >&2
  exit 1
fi
grep -q 'profile coding unknown fields: unexpected' "$tmpdir/auto-override.err"
if grep -q 'runtime/model_advisor.rb:' "$tmpdir/auto-override.err"; then
  printf '%s\n' "auto-discovered schema-invalid override leaked a stack trace" >&2
  exit 1
fi

printf '%s\n' "ok: model advisor"

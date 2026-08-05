#!/usr/bin/env sh
set -eu

repo_root="$(CDPATH= cd "$(dirname "$0")/.." && pwd)"
tmpdir="$(mktemp -d /tmp/aiops-e2e-policy-rules.XXXXXX)"
trap 'rm -rf "$tmpdir"' EXIT INT TERM

"$repo_root/bin/aiops" validate policy-rules --core "$repo_root" >/tmp/aiops-e2e-policy-rules.out
grep -q 'ok: policy rules' /tmp/aiops-e2e-policy-rules.out || {
  printf '%s\n' "policy rules validation did not pass" >&2
  exit 1
}

make_invalid_core() {
  name="$1"
  invalid_core="$tmpdir/$name"
  mkdir -p "$invalid_core/runtime" "$invalid_core/schemas"
  cp "$repo_root/runtime/policy_rules.json" "$invalid_core/runtime/policy_rules.json"
  cp "$repo_root/schemas/policy_rules.schema.json" "$invalid_core/schemas/policy_rules.schema.json"
  printf '%s\n' "$invalid_core"
}

invalid_core="$(make_invalid_core invalid-severity)"
ruby -rjson -e '
  path = ARGV[0]
  data = JSON.parse(File.read(path))
  data["rules"][0]["severity"] = "critical"
  File.write(path, JSON.pretty_generate(data))
' "$invalid_core/runtime/policy_rules.json"
if "$repo_root/bin/aiops" validate policy-rules --core "$invalid_core" >/tmp/aiops-e2e-policy-rules-invalid-severity.out 2>&1; then
  printf '%s\n' "invalid severity unexpectedly passed" >&2
  exit 1
fi
grep -q 'schema_error: rule severity invalid' /tmp/aiops-e2e-policy-rules-invalid-severity.out || {
  printf '%s\n' "invalid severity error missing" >&2
  cat /tmp/aiops-e2e-policy-rules-invalid-severity.out >&2
  exit 1
}

invalid_core="$(make_invalid_core unknown-level)"
ruby -rjson -e '
  path = ARGV[0]
  data = JSON.parse(File.read(path))
  data["rules"][0]["applies_to"] = ["enterprise"]
  File.write(path, JSON.pretty_generate(data))
' "$invalid_core/runtime/policy_rules.json"
if "$repo_root/bin/aiops" validate policy-rules --core "$invalid_core" >/tmp/aiops-e2e-policy-rules-unknown-level.out 2>&1; then
  printf '%s\n' "unknown level unexpectedly passed" >&2
  exit 1
fi
grep -q 'schema_error: rule applies_to unknown level' /tmp/aiops-e2e-policy-rules-unknown-level.out || {
  printf '%s\n' "unknown level error missing" >&2
  cat /tmp/aiops-e2e-policy-rules-unknown-level.out >&2
  exit 1
}

invalid_core="$(make_invalid_core invalid-when)"
ruby -rjson -e '
  path = ARGV[0]
  data = JSON.parse(File.read(path))
  data["rules"][0]["when"] = ["core.present"]
  File.write(path, JSON.pretty_generate(data))
' "$invalid_core/runtime/policy_rules.json"
if "$repo_root/bin/aiops" validate policy-rules --core "$invalid_core" >/tmp/aiops-e2e-policy-rules-invalid-when.out 2>&1; then
  printf '%s\n' "invalid when unexpectedly passed" >&2
  exit 1
fi
grep -q 'schema_error: rule when must be a non-empty object' /tmp/aiops-e2e-policy-rules-invalid-when.out || {
  printf '%s\n' "invalid when error missing" >&2
  cat /tmp/aiops-e2e-policy-rules-invalid-when.out >&2
  exit 1
}

invalid_core="$(make_invalid_core invalid-when-key)"
ruby -rjson -e '
  path = ARGV[0]
  data = JSON.parse(File.read(path))
  data["rules"][0]["when"] = { "Core Present!" => false }
  File.write(path, JSON.pretty_generate(data))
' "$invalid_core/runtime/policy_rules.json"
if "$repo_root/bin/aiops" validate policy-rules --core "$invalid_core" >/tmp/aiops-e2e-policy-rules-invalid-when-key.out 2>&1; then
  printf '%s\n' "invalid when key unexpectedly passed" >&2
  exit 1
fi
grep -q 'schema_error: rule when key invalid' /tmp/aiops-e2e-policy-rules-invalid-when-key.out || {
  printf '%s\n' "invalid when key error missing" >&2
  cat /tmp/aiops-e2e-policy-rules-invalid-when-key.out >&2
  exit 1
}

invalid_core="$(make_invalid_core duplicate-rule)"
ruby -rjson -e '
  path = ARGV[0]
  data = JSON.parse(File.read(path))
  data["rules"][1]["id"] = data["rules"][0]["id"]
  File.write(path, JSON.pretty_generate(data))
' "$invalid_core/runtime/policy_rules.json"
if "$repo_root/bin/aiops" validate policy-rules --core "$invalid_core" >/tmp/aiops-e2e-policy-rules-duplicate-rule.out 2>&1; then
  printf '%s\n' "duplicate rule unexpectedly passed" >&2
  exit 1
fi
grep -q 'schema_error: rule ids must be unique' /tmp/aiops-e2e-policy-rules-duplicate-rule.out || {
  printf '%s\n' "duplicate rule error missing" >&2
  cat /tmp/aiops-e2e-policy-rules-duplicate-rule.out >&2
  exit 1
}

printf '%s\n' "ok: policy rules"

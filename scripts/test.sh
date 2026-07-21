#!/usr/bin/env sh
set -eu

repo_root="$(CDPATH= cd "$(dirname "$0")/.." && pwd)"

printf '%s\n' "== shell syntax =="
sh -n "$repo_root/bin/aiops"

printf '%s\n' "== release check =="
"$repo_root/bin/aiops" release-check --strict

printf '%s\n' "== e2e tests =="
for test_script in "$repo_root"/tests/e2e_*.sh; do
  printf '%s\n' "-- $(basename "$test_script")"
  sh "$test_script"
done

printf '%s\n' "ok: all tests passed"

#!/usr/bin/env sh
set -eu

repo_root="$(CDPATH= cd "$(dirname "$0")/.." && pwd)"

printf '%s\n' "== shell syntax =="
sh -n "$repo_root/bin/aiops"

printf '%s\n' "== release check =="
if git -C "$repo_root" diff --quiet && git -C "$repo_root" diff --cached --quiet; then
  "$repo_root/bin/aiops" release-check --strict --allow-pending-release
else
  printf '%s\n' "skip: release-check requires a clean tracked working tree"
fi

printf '%s\n' "== e2e tests =="
for test_script in "$repo_root"/tests/e2e_*.sh; do
  printf '%s\n' "-- $(basename "$test_script")"
  sh "$test_script"
done

printf '%s\n' "ok: all tests passed"

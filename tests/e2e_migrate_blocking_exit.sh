#!/usr/bin/env sh
set -eu

repo_root="$(CDPATH= cd "$(dirname "$0")/.." && pwd)"
tmpdir="$(mktemp -d /tmp/aiops-e2e-migrate-blocking.XXXXXX)"
trap 'rm -rf "$tmpdir"' EXIT INT TERM

if "$repo_root/bin/aiops" migrate --target "$tmpdir" >/tmp/aiops-e2e-migrate-blocking-missing-ai.out 2>&1; then
  printf '%s\n' "migrate should fail when .ai is missing" >&2
  exit 1
fi

grep -q 'blocking:' /tmp/aiops-e2e-migrate-blocking-missing-ai.out || {
  printf '%s\n' "migrate did not report blocking for missing .ai" >&2
  exit 1
}

ln -s "$repo_root" "$tmpdir/.ai"

if "$repo_root/bin/aiops" migrate --target "$tmpdir" --plan >/tmp/aiops-e2e-migrate-blocking-missing-project.out 2>&1; then
  printf '%s\n' "migrate plan should fail when .ai_project is missing" >&2
  exit 1
fi

grep -q '.ai_project missing' /tmp/aiops-e2e-migrate-blocking-missing-project.out || {
  printf '%s\n' "migrate did not report missing .ai_project" >&2
  exit 1
}

printf '%s\n' "ok: migrate blocking exit"

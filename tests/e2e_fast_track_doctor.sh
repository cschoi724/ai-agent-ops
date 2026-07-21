#!/usr/bin/env sh
set -eu

repo_root="$(CDPATH= cd "$(dirname "$0")/.." && pwd)"
tmpdir="$(mktemp -d /tmp/aiops-e2e-fast.XXXXXX)"
trap 'rm -rf "$tmpdir"' EXIT INT TERM

ln -s "$repo_root" "$tmpdir/.ai"
cp -R "$repo_root/templates/ai_project/fast_track" "$tmpdir/.ai_project"
mkdir -p \
  "$tmpdir/.ai_project/tasks/active" \
  "$tmpdir/.ai_project/tasks/backlog" \
  "$tmpdir/.ai_project/tasks/archive" \
  "$tmpdir/.ai_project/reports" \
  "$tmpdir/.ai_project/qa"

"$repo_root/bin/aiops" doctor --target "$tmpdir" --strict >/tmp/aiops-e2e-fast-doctor.out

grep -q 'mode: .ai_project fast_track' /tmp/aiops-e2e-fast-doctor.out || {
  printf '%s\n' "doctor did not detect fast_track mode" >&2
  exit 1
}

grep -q 'optional for fast_track missing .ai_project/branch_pr_strategy.md' /tmp/aiops-e2e-fast-doctor.out || {
  printf '%s\n' "doctor did not treat branch_pr_strategy as fast_track optional" >&2
  exit 1
}

printf '%s\n' "ok: fast_track doctor strict"

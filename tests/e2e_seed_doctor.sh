#!/usr/bin/env sh
set -eu

repo_root="$(CDPATH= cd "$(dirname "$0")/.." && pwd)"
tmpdir="$(mktemp -d /tmp/aiops-e2e-seed.XXXXXX)"
trap 'rm -rf "$tmpdir"' EXIT INT TERM

"$repo_root/bin/aiops" seed --target "$tmpdir" --core "$repo_root" --adapter both >/tmp/aiops-e2e-seed.out

[ -L "$tmpdir/.ai" ] || {
  printf '%s\n' "missing .ai symlink" >&2
  exit 1
}

[ -f "$tmpdir/AGENTS.md" ] || {
  printf '%s\n' "missing AGENTS.md" >&2
  exit 1
}

[ -f "$tmpdir/CLAUDE.md" ] || {
  printf '%s\n' "missing CLAUDE.md" >&2
  exit 1
}

"$repo_root/bin/aiops" doctor --target "$tmpdir" --strict >/tmp/aiops-e2e-seed-doctor.out

printf '%s\n' "ok: seed both and doctor strict"

#!/usr/bin/env sh
set -eu

repo_root="$(CDPATH= cd "$(dirname "$0")/.." && pwd)"
tmpdir="$(mktemp -d /tmp/aiops-e2e-ci-init.XXXXXX)"
trap 'rm -rf "$tmpdir"' EXIT INT TERM

ln -s "$repo_root" "$tmpdir/.ai"

"$repo_root/bin/aiops" ci init --target "$tmpdir" >/tmp/aiops-e2e-ci-init.out

workflow="$tmpdir/.github/workflows/aiops.yml"
[ -f "$workflow" ] || {
  printf '%s\n' "ci init did not create workflow" >&2
  exit 1
}

grep -q 'doctor --strict' "$workflow" || {
  printf '%s\n' "ci workflow does not run doctor strict" >&2
  exit 1
}

printf '%s\n' '# custom workflow' > "$workflow"
"$repo_root/bin/aiops" ci init --target "$tmpdir" >/tmp/aiops-e2e-ci-init-skip.out

grep -q '# custom workflow' "$workflow" || {
  printf '%s\n' "ci init overwrote existing workflow without --force" >&2
  exit 1
}

"$repo_root/bin/aiops" ci init --target "$tmpdir" --force >/tmp/aiops-e2e-ci-init-force.out

grep -q 'Migration dry-run' "$workflow" || {
  printf '%s\n' "ci init --force did not restore aiops workflow" >&2
  exit 1
}

printf '%s\n' "ok: ci init"

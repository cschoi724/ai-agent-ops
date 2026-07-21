#!/usr/bin/env sh
set -eu

repo_root="$(CDPATH= cd "$(dirname "$0")/.." && pwd)"
tmpdir="$(mktemp -d /tmp/aiops-e2e-migrate-product.XXXXXX)"
trap 'rm -rf "$tmpdir"' EXIT INT TERM

ln -s "$repo_root" "$tmpdir/.ai"
cp -R "$repo_root/templates/ai_project/fast_track" "$tmpdir/.ai_project"
mkdir -p "$tmpdir/Sources"
printf '%s\n' 'print("product sentinel")' > "$tmpdir/Sources/App.swift"

before="$(cksum "$tmpdir/Sources/App.swift")"
"$repo_root/bin/aiops" migrate --target "$tmpdir" --apply >/tmp/aiops-e2e-migrate-product.out
after="$(cksum "$tmpdir/Sources/App.swift")"

[ "$before" = "$after" ] || {
  printf '%s\n' "migrate apply modified product file" >&2
  exit 1
}

grep -q 'product code' /tmp/aiops-e2e-migrate-product.out && {
  printf '%s\n' "migrate apply output should not claim product code changes" >&2
  exit 1
}

printf '%s\n' "ok: migrate no product touch"

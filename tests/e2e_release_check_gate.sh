#!/usr/bin/env sh
set -eu

repo_root="$(CDPATH= cd "$(dirname "$0")/.." && pwd)"
tmpdir="$(mktemp -d /tmp/aiops-e2e-release-gate.XXXXXX)"
trap 'rm -rf "$tmpdir"' EXIT INT TERM

core="$tmpdir/core"
mkdir -p "$core"
tar -C "$repo_root" --exclude=.git -cf - . | tar -C "$core" -xf -

cat > "$core/runtime/agent_identity.rb" <<'RUBY'
#!/usr/bin/env ruby
warn "injected Agent identity runtime failure"
exit 1
RUBY

if "$core/bin/aiops" release-check --core "$core" --strict --allow-pending-release \
  > "$tmpdir/release-check.out" 2>&1; then
  printf '%s\n' "release-check accepted a failed seeded project gate" >&2
  exit 1
fi

grep -q '^warn: seeded project release gate failed$' "$tmpdir/release-check.out"
if grep -q '^ok: seeded project release gate$' "$tmpdir/release-check.out"; then
  printf '%s\n' "release-check reported a failed seeded project gate as successful" >&2
  exit 1
fi

printf '%s\n' "ok: release-check propagates seeded project failures"

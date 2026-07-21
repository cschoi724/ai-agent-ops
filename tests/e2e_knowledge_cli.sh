#!/usr/bin/env sh
set -eu

repo_root="$(CDPATH= cd "$(dirname "$0")/.." && pwd)"
tmpdir="$(mktemp -d /tmp/aiops-e2e-knowledge.XXXXXX)"
trap 'rm -rf "$tmpdir"' EXIT INT TERM

"$repo_root/bin/aiops" knowledge status --target "$tmpdir" >/tmp/aiops-e2e-knowledge-status-missing.out
grep -q 'missing: .ai_knowledge' /tmp/aiops-e2e-knowledge-status-missing.out || {
  printf '%s\n' "knowledge status did not report missing workspace" >&2
  exit 1
}

"$repo_root/bin/aiops" knowledge init --target "$tmpdir" --mode minimal >/tmp/aiops-e2e-knowledge-init.out
"$repo_root/bin/aiops" knowledge lint --target "$tmpdir" >/tmp/aiops-e2e-knowledge-lint.out

for file in README.md index.md log.md project_brief.md; do
  [ -f "$tmpdir/.ai_knowledge/$file" ] || {
    printf 'missing minimal knowledge file: %s\n' "$file" >&2
    exit 1
  }
done

[ ! -d "$tmpdir/.ai_knowledge/concepts" ] || {
  printf '%s\n' "minimal knowledge init should not create concepts directory" >&2
  exit 1
}

"$repo_root/bin/aiops" knowledge init --target "$tmpdir" --mode full --force >/tmp/aiops-e2e-knowledge-init-full.out

for dir in concepts decisions architecture open_questions; do
  [ -f "$tmpdir/.ai_knowledge/$dir/_template.md" ] || {
    printf 'missing full knowledge template: %s\n' "$dir" >&2
    exit 1
  }
done

"$repo_root/bin/aiops" knowledge lint --target "$tmpdir" >/tmp/aiops-e2e-knowledge-lint-full.out

printf '%s\n' "ok: knowledge cli"

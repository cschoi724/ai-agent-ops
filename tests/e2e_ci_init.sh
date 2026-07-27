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

ci_project="$(mktemp -d /tmp/aiops-e2e-ci-template.XXXXXX)"
trap 'rm -rf "$tmpdir" "$ci_project"' EXIT INT TERM

"$repo_root/bin/aiops" seed --target "$ci_project" --adapter both --mode link --core "$repo_root" >/tmp/aiops-e2e-ci-template-seed.out
cp -R "$repo_root/templates/ai_project/fast_track" "$ci_project/.ai_project"
perl -0pi -e 's/\{\{START_CONTEXT\}\}/ops_setup_only/g; s/\{\{READINESS_LEVEL\}\}/ops_only/g' "$ci_project/.ai_project/operating_model.md"
mkdir -p \
  "$ci_project/.ai_project/tasks/active" \
  "$ci_project/.ai_project/tasks/backlog" \
  "$ci_project/.ai_project/tasks/archive" \
  "$ci_project/.ai_project/handoffs"
"$repo_root/bin/aiops" knowledge init --target "$ci_project" --mode minimal >/tmp/aiops-e2e-ci-template-knowledge.out
"$repo_root/bin/aiops" ci init --target "$ci_project" >/tmp/aiops-e2e-ci-template-init.out

[ -f "$ci_project/.github/workflows/aiops.yml" ] || {
  printf '%s\n' "project ci template workflow was not created" >&2
  exit 1
}

"$repo_root/bin/aiops" doctor --target "$ci_project" --strict >/tmp/aiops-e2e-ci-template-doctor.out
"$repo_root/bin/aiops" validate --target "$ci_project" --strict >/tmp/aiops-e2e-ci-template-validate.out
"$repo_root/bin/aiops" migrate --target "$ci_project" --plan >/tmp/aiops-e2e-ci-template-migrate.out
"$repo_root/bin/aiops" knowledge lint --target "$ci_project" >/tmp/aiops-e2e-ci-template-knowledge-lint.out

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

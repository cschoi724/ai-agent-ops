#!/usr/bin/env sh
set -eu

repo_root="$(CDPATH= cd "$(dirname "$0")/.." && pwd)"

"$repo_root/bin/aiops" help >/tmp/aiops-e2e-help-quick.out
grep -q '^자주 쓰는 명령어$' /tmp/aiops-e2e-help-quick.out || {
  printf '%s\n' "quick help common command section missing" >&2
  exit 1
}
grep -q 'aiops status' /tmp/aiops-e2e-help-quick.out || {
  printf '%s\n' "quick help status command missing" >&2
  exit 1
}
grep -q '^처음 시작$' /tmp/aiops-e2e-help-quick.out || {
  printf '%s\n' "quick help getting started section missing" >&2
  exit 1
}
grep -q 'aiops bootstrap-guide' /tmp/aiops-e2e-help-quick.out || {
  printf '%s\n' "quick help bootstrap guide missing" >&2
  exit 1
}
if grep -q 'project snapshot --json' /tmp/aiops-e2e-help-quick.out; then
  printf '%s\n' "quick help exposed machine snapshot command" >&2
  exit 1
fi

"$repo_root/bin/aiops" --help --all >/tmp/aiops-e2e-help-all-option.out
grep -q 'aiops project snapshot \[--target DIR\] --json' /tmp/aiops-e2e-help-all-option.out || {
  printf '%s\n' "--help --all full reference missing snapshot command" >&2
  exit 1
}

"$repo_root/bin/aiops" help all >/tmp/aiops-e2e-help-all-topic.out
cmp -s /tmp/aiops-e2e-help-all-topic.out /tmp/aiops-e2e-help-all-option.out || {
  printf '%s\n' "help all diverges from --help --all" >&2
  exit 1
}

"$repo_root/bin/aiops" help ai >/tmp/aiops-e2e-help-ai.out
grep -q '^Agent / 자동화용 명령$' /tmp/aiops-e2e-help-ai.out || {
  printf '%s\n' "machine help header missing" >&2
  exit 1
}
grep -q 'aiops project dashboard --json' /tmp/aiops-e2e-help-ai.out || {
  printf '%s\n' "machine help dashboard json command missing" >&2
  exit 1
}

"$repo_root/bin/aiops" help machine >/tmp/aiops-e2e-help-machine.out
cmp -s /tmp/aiops-e2e-help-machine.out /tmp/aiops-e2e-help-ai.out || {
  printf '%s\n' "help machine diverges from help ai" >&2
  exit 1
}

"$repo_root/bin/aiops" help work >/tmp/aiops-e2e-help-work.out
grep -q '^aiops work$' /tmp/aiops-e2e-help-work.out || {
  printf '%s\n' "work help title missing" >&2
  exit 1
}
grep -q 'aiops work --format tree' /tmp/aiops-e2e-help-work.out || {
  printf '%s\n' "work help tree example missing" >&2
  exit 1
}
grep -q '비슷한 명령:' /tmp/aiops-e2e-help-work.out || {
  printf '%s\n' "work help related command section missing" >&2
  exit 1
}
"$repo_root/bin/aiops" work --help >/tmp/aiops-e2e-work-help-option.out
cmp -s /tmp/aiops-e2e-work-help-option.out /tmp/aiops-e2e-help-work.out || {
  printf '%s\n' "work --help diverges from help work" >&2
  exit 1
}

for topic in status work risks agents release doctor sync-status bootstrap-guide session-guide; do
  "$repo_root/bin/aiops" help "$topic" >/tmp/aiops-e2e-help-topic.out
  "$repo_root/bin/aiops" "$topic" --help >/tmp/aiops-e2e-help-command.out
  cmp -s /tmp/aiops-e2e-help-command.out /tmp/aiops-e2e-help-topic.out || {
    printf '%s\n' "$topic --help diverges from help $topic" >&2
    exit 1
  }
  grep -q '사용 예:' /tmp/aiops-e2e-help-topic.out || {
    printf '%s\n' "$topic help example section missing" >&2
    exit 1
  }
  grep -q '비슷한 명령:' /tmp/aiops-e2e-help-topic.out || {
    printf '%s\n' "$topic help related command section missing" >&2
    exit 1
  }
done

"$repo_root/bin/aiops" help bootstrap-guide >/tmp/aiops-e2e-help-bootstrap.out
grep -q '미연결 프로젝트에는 seed' /tmp/aiops-e2e-help-bootstrap.out || {
  printf '%s\n' "bootstrap help seed guidance missing" >&2
  exit 1
}
grep -q '운영 미구성 프로젝트에는 bootstrap' /tmp/aiops-e2e-help-bootstrap.out || {
  printf '%s\n' "bootstrap help setup guidance missing" >&2
  exit 1
}
grep -q 'aiops session-guide' /tmp/aiops-e2e-help-bootstrap.out || {
  printf '%s\n' "bootstrap help configured-project guidance missing" >&2
  exit 1
}

"$repo_root/bin/aiops" help bootstrap-guide --locale en >/tmp/aiops-e2e-help-bootstrap-en.out
AIOPS_LOCALE=en "$repo_root/bin/aiops" bootstrap-guide --help >/tmp/aiops-e2e-bootstrap-help-option-en.out
cmp -s /tmp/aiops-e2e-bootstrap-help-option-en.out /tmp/aiops-e2e-help-bootstrap-en.out || {
  printf '%s\n' "english bootstrap-guide --help diverges from help bootstrap-guide" >&2
  exit 1
}

"$repo_root/bin/aiops" help agent >/tmp/aiops-e2e-help-agent.out
"$repo_root/bin/aiops" agent inspect --help >/tmp/aiops-e2e-agent-help-option.out
cmp -s /tmp/aiops-e2e-agent-help-option.out /tmp/aiops-e2e-help-agent.out || {
  printf '%s\n' "agent inspect --help diverges from help agent" >&2
  exit 1
}
grep -q 'aiops agent inspect --json' /tmp/aiops-e2e-help-agent.out || {
  printf '%s\n' "Agent inspection help JSON example missing" >&2
  exit 1
}

"$repo_root/bin/aiops" help dashboard >/tmp/aiops-e2e-help-dashboard.out
grep -q '^aiops project dashboard$' /tmp/aiops-e2e-help-dashboard.out || {
  printf '%s\n' "dashboard help title missing" >&2
  exit 1
}
grep -q 'Mermaid' /tmp/aiops-e2e-help-dashboard.out || {
  printf '%s\n' "dashboard help mermaid description missing" >&2
  exit 1
}

"$repo_root/bin/aiops" help --locale en >/tmp/aiops-e2e-help-en.out
grep -q '^Common Commands$' /tmp/aiops-e2e-help-en.out || {
  printf '%s\n' "english quick help common command section missing" >&2
  exit 1
}
grep -q 'Show project status' /tmp/aiops-e2e-help-en.out || {
  printf '%s\n' "english quick help status text missing" >&2
  exit 1
}
grep -q '^Getting Started$' /tmp/aiops-e2e-help-en.out || {
  printf '%s\n' "english quick help getting started section missing" >&2
  exit 1
}
grep -q 'aiops bootstrap-guide' /tmp/aiops-e2e-help-en.out || {
  printf '%s\n' "english quick help bootstrap guide missing" >&2
  exit 1
}

AIOPS_LOCALE=en "$repo_root/bin/aiops" help work >/tmp/aiops-e2e-help-work-env-en.out
grep -q '^Examples:$' /tmp/aiops-e2e-help-work-env-en.out || {
  printf '%s\n' "AIOPS_LOCALE english work help example section missing" >&2
  exit 1
}

if "$repo_root/bin/aiops" help unknown >/tmp/aiops-e2e-help-unknown.out 2>&1; then
  printf '%s\n' "unknown help topic unexpectedly succeeded" >&2
  exit 1
fi
grep -q 'unknown help topic: unknown' /tmp/aiops-e2e-help-unknown.out || {
  printf '%s\n' "unknown help topic error missing" >&2
  exit 1
}

printf '%s\n' "ok: help ux"

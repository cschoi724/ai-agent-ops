---
name: aiops-status
description: AI Ops 프로젝트 상태를 점검하고 사람이 이해하기 쉽게 요약한다. 사용자가 "AI Ops 상태 점검", "프로젝트 상태 알려줘", "막힌 거 있어?"처럼 물을 때 사용한다.
---

# AI Ops 상태 점검

읽기 전용 명령만 사용한다. 파일을 수정하지 않는다.

1. `aiops project snapshot --json`을 실행한다. `.ai/bin/aiops`가 있으면 그 경로를 사용해도 된다.
2. `health.overall`, `health.blockers`, `health.warnings`, `control.can_start_task`, `control.can_transition`, `tasks.by_status`를 확인한다.
3. 다중 worktree 프로젝트(`source_refs.canonical_status_ref`가 있음)면 `source_refs.status_ref_state`도 확인한다.
4. 필요하면 `aiops risks`, `aiops work`로 사람용 요약을 본다.

## 사용자에게 보고하는 형식
- 전체 상태: 정상 / 주의 / 차단 중 하나와 한 줄 이유
- 진행 중인 일감: Task ID 짧은 호칭 + 제목 + 상태 + 담당
- 막힌 것과 이유: blocker를 사람이 이해하는 말로
- 다음 추천 행동: 사용자가 할 일과 Agent가 할 일을 구분

내부 상태값(`verification_ready` 등)은 괄호 안에만 보조로 쓰고, 문장은 쉬운 말로 쓴다.

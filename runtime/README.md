# Runtime

`runtime/`은 Task 실행 중 직접 참조하는 workflow와 queue 규칙을 담는다.

| 문서 | 역할 |
|---|---|
| `workflow.md` | 기본 책임 단계와 상태 흐름 |
| `task_queue.md` | Task 상태, lock, routing, metadata 기준 |
| `role_handoff.md` | Role 전환 시 다음 Agent에게 전달할 말 기준 |
| `bootstrap_options.json` | Bootstrap 선택 후보의 기계 판독 가능한 catalog |
| `dashboard_server.rb` | localhost dashboard 요청·새로고침 runtime |
| `dashboard_presets.rb` | built-in/local dashboard preset 조회·검증·확장 runtime |
| `github_release_status.rb` | 명시 요청 시 GitHub PR·required check·workflow run·release 상태를 읽는 runtime |
| `task_risk_profile.rb` | Task 범위와 Git 변경을 Light/Standard/Strict 운영 profile로 계산하는 runtime |
| `task_lifecycle.rb` | Task accept/advance readiness와 원자적 전이를 처리하는 runtime |
| `task_cleanup.rb` | 완료 Task branch/worktree 정리 계획과 적용을 처리하는 runtime |
| `model_catalog.json` | provider별 실제 model/effort/profile 기본 catalog와 공식 근거 |
| `model_advisor.rb` | Role, Task profile, local provider config와 allowlist를 실제 모델 추천으로 해석하는 runtime |

# AI Agent Ops 개발 가이드 (Contributor / Agent용)

이 문서는 **ai-agent-ops 레포 자체를 개발하는 사람과 AI Agent**를 위한 가이드다.
AI Ops를 *적용받는* 프로젝트의 운영 규칙은 `README.md`, `QUICKSTART.md`, `core/constitution.md`를 따른다.

> 새 Agent 세션은 이 문서를 먼저 읽고, 사용자 작업 지시를 받은 뒤 해당 영역의 코드/문서를 깊게 읽는다.
> 기준 버전: v0.17.1 (2026-11-18), 분석일: 2026-11-17. 줄 번호는 drift되므로 함수명/키워드로 `grep` 한다.

---

## 1. 제품 한눈에 보기

- **정체**: Codex/Claude 같은 AI Agent가 프로젝트 안에서 Role·상태·승인·검증·인계를 기록하며 팀처럼 일하게 하는 *운영 하네스*. 런타임 엔진이 아니라 **repo-native 문서 + CLI + JSON schema 계약**이다.
- **흐름**: `seed → bootstrap → task → execution → verification → completion`
- **배포**: Homebrew `cschoi724/tap` (`Formula/ai-agent-ops.rb`, tag tarball). 명령어는 `aiops`.
- **대상 프로젝트에 생기는 것**
  - `.ai/` : 이 레포(core)의 symlink 또는 copy. 사용자는 직접 수정하지 않는다.
  - `AGENTS.md` / `CLAUDE.md` : `templates/tool_adapters/{codex,claude}/` 에서 렌더링되는 어댑터
  - `.ai_project/` : 프로젝트별 상태 (operating_model, agent_registry, task_board, tasks/{active,backlog,archive}, handoffs, reports, qa, `.runtime/`)
  - `.ai_knowledge/` : 선택. Agent 온보딩 지식 계층
- **언어 원칙**: 사용자 출력과 운영 문서는 한국어 기본, `--locale en` 지원. 기계 JSON 값·모델 ID·Agent 고유명은 번역하지 않는다. CHANGELOG·PR 본문은 영어.

## 2. 핵심 도메인 모델

| 개념 | 의미 | 정의 위치 |
|---|---|---|
| Role (7종) | Direction, Lead, Execution, Verification, Completion, Release, Ops Governance | `models/role_model.md` |
| Agent | Role을 수행하는 지속 정체성. `roles`=assigned_roles, 전이 시 `active_role` 기록 | `models/agent_registry.md`, `.ai_project/agent_registry.md` |
| Agent ID | 불변 식별자(`target_agent_id`), 표시 이름(`agent`)과 alias 분리 (v0.16.0) | `runtime/agent_identity.rb` |
| Task | 실행 지시의 source of truth. YAML front matter (`schema: aiops.task.v1`) | `templates/tasks/task.md`, `schemas/task.schema.json` |
| Workflow | feature(기본) / bugfix / docs / ops_migration / release. 자식은 `inherits: feature` | `runtime/workflows.json`, `workflows/*.md` |
| Status | proposed → scoped → approved → in_progress → verification_ready → verification_in_progress → verification_passed → completion_review → done (+ blocked, rework_requested, cancelled) | `runtime/workflow.md` |
| Risk Profile | light / standard / strict. light는 in_progress → completion_review 단축 가능 | `runtime/task_risk_profile.rb` |
| Policy rule | snapshot 위에서 평가되는 규칙(현재 8개, basic/team/regulated) | `runtime/policy_rules.json` |
| canonical_status_ref | 다중 worktree에서 공용 기준이 되는 ref | `docs/shared_status.md`, `policies/shared_status_policy.md` |

**불변 원칙 (깨면 안 됨)**
- fail-closed: 판단이 애매하면 전이·적용을 막는다. 임의 Agent 선택 금지.
- 승인 없는 commit/push/PR/merge/deploy 금지. Execution 밖 범위 구현 금지. 자기 검증 금지.
- Snapshot·dashboard는 projection이지 source of truth가 아니다. Task 파일이 source of truth.
- 과거 기록(archive Task, report, QA, handoff, receipt)은 소급 수정하지 않는다.
- `--check`/dry-run 경로는 파일·lock·receipt를 쓰지 않는다. apply는 rollback 가능한 bundle로.

## 3. 레포 구조

| 경로 | 내용 | Formula 설치 |
|---|---|---|
| `bin/aiops` | **CLI 본체 (~13,100줄 POSIX sh + inline `ruby -e`)** | O |
| `runtime/*.rb` | 분리된 Ruby 모듈 11개 (아래 §4.3) | O |
| `runtime/*.json` | workflows, policy_rules, bootstrap_options, model_catalog catalog | O |
| `runtime/*.md` | workflow / task_queue / role_handoff 운영 문서 | O |
| `schemas/` | `aiops.*.v1` JSON schema 약 30개 | O |
| `core/ models/ policies/ bootstrap/ agents/ workflows/` | Agent가 읽는 헌법·모델·정책·runbook (한국어) | O |
| `templates/` | seed/bootstrap 시 복사·렌더되는 템플릿 (`ai_project/{fast_track,guided_full}`, tasks, reports, qa, ci, tool_adapters, ai_knowledge, project_docs) | O |
| `adapters/` | LangGraph / OpenAI Agents 연결 계약 문서 (`aiops export runtime`) | O |
| `docs/` | 사용자 문서 (installation, distribution, agent_intent, project_state, shared_status) | O |
| `tests/` | e2e 셸 테스트 55개 + 브라우저 visual 테스트 | X |
| `design_notes/` | 차수별 개선 계획/논의 메모 (진행 상태 표시 포함) | X |
| `scripts/test.sh` | 전체 테스트 진입점 | O |
| `Formula/ai-agent-ops.rb` | Homebrew formula (설치 대상 디렉터리 목록 명시) | O |
| `DEVELOPMENT.md`, `CLAUDE.md`, `AGENTS.md` (루트) | 이 개발 가이드와 Agent 진입점. **Formula가 설치하지 않음** | X |

## 4. 아키텍처

### 4.1 실행 모델

```
aiops (sh)
  main() → case 분기 → cmd_<name>()            # bin/aiops 하단
     ├─ 옵션 파싱은 sh while/case
     ├─ 로직은 대부분 inline `ruby -ryaml -rjson ... -e '...' "$args"`
     └─ 일부는 `ruby "$core/runtime/<module>.rb" ...` 로 위임
```

- core 위치: `default_core_dir()` → `AIOPS_CORE_HOME` 또는 스크립트 기준 상위 디렉터리. 대상 프로젝트는 `--target DIR`(기본 `pwd`).
- **Ruby 2.6 호환 필수** (macOS 기본 ruby, CI `macos-latest`). `filter_map`, `tally`, pattern matching, endless method, `Hash#except` 등 2.7+ 기능 금지.
- inline Ruby 안에서는 sh 작은따옴표 때문에 `'` 를 쓸 수 없다 → `34.chr`/`39.chr`, `%w[]`, 큰따옴표로 우회한다(기존 코드 패턴 참고).
- 의존성 없음(gem 설치 없음). stdlib만 사용.
- **POSIX sh에는 지역 변수가 없다.** 함수 안에서 `failed`, `adapter`, `target` 같은 흔한 이름에 값을 넣으면 호출한 쪽 값이 바뀐다. 실제로 `check_conditional_project_files`의 `failed=0`이 validate/doctor 실패를 지웠고, `seed_adapter`의 `adapter=`가 `--adapter both`를 덮어썼다. 헬퍼 함수는 고유한 변수 이름을 쓴다.
- Ruby heredoc(`<<~X`, `%(...)`) 안에 sh 코드를 넣으면 ``가 Ruby 보간으로 바뀌고 들여쓰기가 지워진다. bin/aiops 수정은 Edit 도구나 작은따옴표 heredoc을 쓴다.

### 4.2 `bin/aiops` 지도 (v0.16.0 기준 대략 줄 번호)

| 영역 | 함수 / 위치 |
|---|---|
| 도움말 | `usage_all` (4), `usage_quick` (190), `usage_machine` (255), `usage_command_help` (310), `cmd_help` (696) |
| 공용 헬퍼 | `die`, `info`, `check_required_file/dir`, `task_field_value`, `project_field_value`, `conditional_project_file_*` (733~950) |
| 검증 | `validate_front_matter` (950, 300줄 inline), `validate_project_relationships` (1279), `validate_project_status_requirements` (1466), `validate_project` (1661) |
| Task 헬퍼 | `task_find_file`, `task_next_id`, `task_update_front_matter`, `task_transition_allowed`, `workflow_status_field` (1741~2020) |
| 상태 공유 | `cmd_status_ref`, `cmd_sync_status`, `cmd_worktree` (2302~2490) |
| 마이그레이션 | `cmd_migrate_verify`, `cmd_migrate` (2737~3090) |
| Registry | `registry_agents_for_role`, `registry_resolve_identity` (3235~3344) |
| seed / doctor | `cmd_seed` (3432), `cmd_doctor` (3536) |
| **project** | `cmd_project` (3733~8942, 5,200줄): `dashboard` (3739, 렌더러 inline 약 2,900줄 @4079), `snapshot` (6985, 약 700줄), `inspect` (7713), `context` (8033), `health` (8413) |
| validate | `cmd_validate` (8942): schema별 validator 다수 |
| task | `cmd_task` (9849): create/status/profile → risk_profile.rb, accept/advance → task_lifecycle.rb, close → task_cleanup.rb, transition/lock/unlock 은 sh |
| 기타 | `cmd_action` (10516), `cmd_handoff` (10965), `cmd_session_guide` (11265), `cmd_policy` (11388), `cmd_agent` (11580), `cmd_model` (11611), `cmd_role` (11632), `cmd_knowledge` (11912), `cmd_ci` (12140), `cmd_export` (12226), `cmd_version/update` (12428), `cmd_release_check` (12539), `cmd_bootstrap_guide` (12871), `cmd_user_dashboard_view` (13006), `main` (13102) |

사용자 단축 명령 `status/work/risks/agents/release` 는 `cmd_user_dashboard_view` → `project dashboard`의 view 프리셋이다.

### 4.3 `runtime/*.rb` 모듈

| 파일 | 역할 | 진입 |
|---|---|---|
| `task_lifecycle.rb` (887) | `task accept/advance`. HAPPY_PATH, 송·수신 readiness 검사, git-common-dir flock, staged tempfile → 원자 rename → 실패 시 rollback, receipt/handoff/board projection | `class TaskLifecycle` |
| `task_cleanup.rb` (768) | `task close`. 완료 Task의 worktree/branch 정리 (protected/dirty/unmerged 보호, SHA lease) | `class TaskCleanup` |
| `task_risk_profile.rb` (358) | light/standard/strict 계산. snapshot·context·lifecycle·model_advisor가 require | `module TaskRiskProfiles` |
| `agent_identity.rb` (447) | Registry 파싱, ID/이름/alias 해석(ambiguous→차단), 프로젝트 참조 감사 | `module AgentIdentity` |
| `agent_identity_migration.rb` (662) | `agent rename`, `agent migrate-identities` plan/apply/receipt | `class AgentIdentityMigration` |
| `model_advisor.rb` (778) | `model recommend` (codex / claude-code / custom, `model_catalog.json`) | `class ModelAdvisor` |
| `dashboard_server.rb` (432) | `project dashboard --serve` localhost 서버 | `class DashboardServer` |
| `dashboard_presets.rb` (430) | dashboard preset list/show/add/run | `class DashboardPresets` |
| `guard.rb` | `aiops guard`: 보호 hook 판정(Claude/Codex 공통 payload, fail-closed). 보호 대상은 `.ai/`, Agent Registry의 Operator Role 보유자(파일 수정 도구 결과를 `RegistryCheck`로 계산해 비교, 셸 수정은 차단, Bootstrap 생성은 허용, `allow-structure-edit`로 기한부 해제), transition receipt, `.git/hooks`·`config`·`aiops`. Owner 전용 명령(`--owner-approved`, `--no-verify`, `core.hooksPath`, `write-core-digest`, registry `--apply`) 차단, pre-commit, core 무결성(digest / git clean) | `module AiopsGuard` |
| `orchestrate.rb` | `aiops orchestrate plan`: Operator 세션의 다음 단계·담당 subagent·명령·Owner 정지 지점 계산(읽기 전용, gate 단계는 lifecycle `--check`로 사전 확인) | `class OrchestrationPlan` |
| `tool_extras.rb` | seed·doctor용 Role subagent, skill, hook 설정 설치와 상태 점검(settings 병합) | `class ToolExtras` |
| `github_release_status.rb` (336) | `--github` 시 `gh`로 PR/check/release 조회 (timeout 포함) | `class GitHubReleaseStatus` |

공통 패턴: `OptionParser` 기반 CLI, `--json` 기계 출력 + 한국어/영어 사용자 출력, 오류는 `XxxError` → 짧은 메시지(스택트레이스 노출 금지), 테스트용 실패 주입 ENV (`AIOPS_TEST_LIFECYCLE_FAIL`, `AIOPS_TEST_LIFECYCLE_HOLD_SECONDS` 등).

### 4.4 상태 계약 데이터 흐름

```
.ai_project/*.md (front matter / 표 / legacy "key: value")
  + git (branch, HEAD, canonical ref)
  + runtime/workflows.json, policy_rules.json
        │
        ├─ project snapshot --json  (aiops.project_snapshot.v1)  ← Agent가 먼저 읽는 계약
        │      └─ evaluate_policy → snapshot.policy
        ├─ project health --json    (독립 계산)
        ├─ project inspect          (독립 계산)
        ├─ validate project --strict (sh + inline ruby, 독립 계산)
        └─ doctor --strict           (sh)
                 │
project dashboard = snapshot JSON + health JSON (+ github JSON) 을 stdin으로 받아 렌더링
  → terminal / tree / mermaid / html / json(aiops.project_dashboard.v1), --serve
```

**주의**: snapshot / health / inspect / validate / doctor 는 같은 `.ai_project`를 **각자 따로 파싱**한다. `front_matter`, `legacy_field`, `table_value`, `scalar_string` 같은 헬퍼가 `bin/aiops` 안에 여러 벌 복제돼 있다(`front_matter` 9벌). 판단 규칙을 바꾸면 **모든 사본**을 함께 고치고 `tests/e2e_project_state_consistency.sh`로 일치를 확인한다.

### 4.5 Lifecycle 전이 규칙 위치

- 정상 경로 목적지: `TaskLifecycle::HAPPY_PATH` (하드코딩) + light profile 단축
- 허용 여부·역할: `runtime/workflows.json` 의 `transitions[].{from,to,allowed_roles,next_role,profiles}`
- 수동/예외 전이: `bin/aiops` `task_transition_allowed` + `task transition` (Profile 제한은 우회 불가)
- 두 곳(HAPPY_PATH와 catalog)이 어긋나면 "workflow does not allow automatic transition" 으로 막힌다. 상태를 추가/변경할 때 둘 다 수정.

## 5. 개발 환경과 테스트

```bash
# 개발 checkout (이 머신)
cd ~/Desktop/workspace/aiops/ai-agent-ops-repo
bin/aiops version

# 전체 테스트 (이 머신 약 2분 45초, 2026-11-17 main 기준 전부 통과 / release-check warnings 0)
sh scripts/test.sh
#  = sh -n, schema JSON 파싱, runtime ruby -cw, release-check(작업트리 clean일 때만), tests/e2e_*.sh 전부

# 주의: scripts/test.sh 는 작업 트리가 dirty면 release-check를 건너뛴다.
#       커밋한 뒤 release-check --strict --allow-pending-release 를 다시 돌려 PR 전에 확인한다.

# 단일 테스트
sh tests/e2e_task_lifecycle.sh

# 릴리스 게이트 (CI와 동일)
bin/aiops release-check --strict --allow-pending-release

# 수동 확인용 임시 프로젝트
d="$(mktemp -d)"; bin/aiops seed --target "$d" --adapter both --mode link --core "$PWD"
bin/aiops status --target "$d"
```

- e2e 테스트 관례: `mktemp -d /tmp/aiops-e2e-<name>.XXXXXX` + `trap rm`, `.ai`를 repo로 symlink, `.ai_project`를 heredoc으로 직접 구성, `grep -q`로 출력 단언, 실패 시 `exit 1`. 새 기능은 같은 형식의 `tests/e2e_<feature>.sh` 를 추가하면 `scripts/test.sh`가 자동 포함한다.
- `tests/visual_dashboard.sh` 는 Chrome + Node가 필요하며 CI `dashboard browser visual` job에서 돈다.
- CI (`.github/workflows/ci.yml`, macos-latest): test / release-check / project-ci-template / dashboard visual.

## 6. 변경 체크리스트

새 기능·수정 시 해당 항목을 모두 확인한다.

- [ ] 기능 코드 (`bin/aiops` 또는 `runtime/*.rb`). 새 로직이 크면 `runtime/` 모듈로 분리하는 방향을 우선한다.
- [ ] 새 기계 출력이면 `schemas/<name>.schema.json` + `aiops validate <name> FILE` validator
- [ ] 새 runtime/schema/템플릿 필수 파일이면 `cmd_release_check`의 required 목록에 추가
- [ ] 새 최상위 디렉터리면 `Formula/ai-agent-ops.rb` install 목록과 release-check의 Formula 검사에 추가
- [ ] 어댑터·subagent·skill·hook 변경은 `templates/tool_adapters/_source/`만 수정하고 `ruby scripts/build_adapters.rb`로 재생성 (Claude·Codex 동일 지원, parity 테스트)
- [ ] 도움말: `usage_all` / `usage_quick` / `usage_machine` / `usage_command_help` (ko/en), `tests/e2e_help_ux.sh`
- [ ] 사용자 출력 ko/en 라벨, Agent 고유명·기계값 비번역
- [ ] 판단 로직 변경이면 snapshot/health/inspect/validate/doctor 사본 일관성 (§4.4)
- [ ] Ruby 2.6 호환, stdlib only
- [ ] e2e 테스트 추가/갱신 → `sh scripts/test.sh` 통과
- [ ] 운영 문서(README 명령표, runtime/*.md, policies, templates/tool_adapters) 반영
- [ ] `CHANGELOG.md` `## Unreleased` 아래 Added / Changed / Fixed (영어)
- [ ] 진행 중 계획이 있으면 `design_notes/*.md` 상단 상태 줄 갱신 (완료 계획 문서는 정식 문서에 반영 후 삭제가 원칙)

## 7. Git / PR / 릴리스 절차

- 원격: `git@github-personal:cschoi724/ai-agent-ops.git` (이 머신의 `~/.ssh/config` 별칭 → 개인 키). 기본 `github.com` 은 회사 계정이므로 쓰지 않는다. 레포 로컬 author는 `cschoi724`.
- `gh`는 회사 계정이 활성 상태로 유지된다. ai-agent-ops 작업의 `gh` 명령은 `GH_TOKEN="$(gh auth token --user cschoi724)" gh ...` 형태로 실행하고 `gh auth switch`는 쓰지 않는다.
- **사용자 승인 없이 commit / push / PR 생성 / merge 하지 않는다.**
- 브랜치: `feature/<topic>`, `fix/<topic>`, `docs/<topic>`, `release/vX.Y.Z`, `release/vX.Y.Z-formula-sha` (또는 `chore/vX.Y.Z-formula-sha`)
- 커밋/PR 제목: `feat: ...`, `fix: ...`, `docs: ...`, `chore: ...`. PR 본문 섹션: Summary / Why / Safety / Validation (영어).
- 기능 PR은 독립 검증(다른 Agent/세션 리뷰) 후 "no High, Medium, or Low findings" 를 기록하는 관례.
- 릴리스 (버전 정책: `policies/versioning_policy.md`, Major=호환 깨짐 / Minor=기능·흐름 / Patch=수정)
  1. `release/vX.Y.Z` PR: `VERSION` 갱신, CHANGELOG `Unreleased` → `## X.Y.Z - YYYY-MM-DD`, Formula `url` tag 갱신
  2. merge 후 `vX.Y.Z` tag + GitHub Release 생성 (release note는 파일로 전달 — backtick 치환 방지) → tarball sha256 계산
  3. `release/vX.Y.Z-formula-sha` PR: Formula `sha256` 갱신
  4. tap 레포(`cschoi724/homebrew-tap`)에 Formula 반영
  5. `release-check --strict` (pending 허용 없이) warnings 0
  - 전체 체크리스트 원문: `docs/distribution.md` §릴리스 전 확인 항목

## 8. 이 머신의 설치 사본

- `~/Desktop/workspace/aiops/aiops` : 런처 스크립트 → `ai-agent-ops/bin/aiops` (`AIOPS_CORE_HOME` 설정)
- `~/Desktop/workspace/aiops/ai-agent-ops/` : v0.16.0 tarball 사본 (git 아님). **개발은 `ai-agent-ops-repo/` 에서만** 한다.

## 9. 현재 상태와 남은 과제 (2026-11-18 기준)

v0.17.1: v0.17.0(PR A~D #67~#70, 보안 보강 E-1 #71)에 Agent Registry 보호 완화(#74) 반영. 열린 PR은 #61(Draft, 문서만).

**진행 중 최우선 계획**: `design_notes/single_session_orchestration_plan.md` — 다음은 PR F(v0.18.0, 새 Task ID·협업 lock·worktree). 보류: guard가 git 최상위 대신 상위 폴더로 `.ai`를 찾기(앱 저장소가 프로젝트 폴더 안쪽에 있는 구조), seed 재실행 시 bootstrap 안내 문구. 아래 표의 1·2번은 이 계획과 함께 재검토한다.

| # | 과제 | 근거 | 비고 |
|---|---|---|---|
| 1 | Agent identity **4차**: ID 기반 계약 강제 — Registry v2/Task schema 전환, bootstrap ID 기본 생성, active/backlog `target_agent_id` 필수, 이름 fallback 제거, health/dashboard에 migration readiness | `design_notes/agent_identity_reference_integrity_plan.md` §10, §13 | §13 결정 항목 7개 선결 필요 (필드명, ID 생성 주체, alias 유지, handoff ID, rename 권한, Boss 권한, 직접 편집 허용) |
| 2 | Boss Automation Mode 논의 | PR #61 (`docs/boss-automation-discussion`) | 구현 미승인. 권한 경계 결정 필요 |
| 3 | 상태 전이 PR/CI 비용 정책 | `design_notes/status_transition_ci_cost_note.md` | 임시 메모, 정책 미확정 |
| 4 | 독립 검증 대기 항목 | efficiency plan 5차, dashboard follow-up 9차(HTML visual regression) | 이미 main 반영·릴리스됨, 문서상 검증 미기록 |
| 5 | design_notes 상태 줄 정합성 | identity plan 상단 "3~4차 미착수"(실제 3차 완료), `policy_rule_application_plan.md` "작업 전"(실제 0.11.x 구현, 완료 시 삭제 원칙) | 문서 정리 |
| 6 | 구조 부채 | `bin/aiops` 13k줄 단일 파일, dashboard 렌더러 inline 2.9k줄, 파서 헬퍼 다중 복제, 상태 판단 5중 독립 계산 | 공용 `runtime/project_state.rb` 같은 모듈 추출 후보. 큰 리팩터링은 사용자 승인 후 차수로 진행 |

## 10. 새 세션 시작 절차 (Agent용)

1. 이 문서를 읽는다. (`CLAUDE.md` / `AGENTS.md` 가 여기로 안내한다.)
2. `git status`, `git log --oneline -5`, `git fetch && git status -sb` 로 현재 위치 확인.
3. `cat VERSION`, `CHANGELOG.md` 의 `Unreleased`, `gh pr list -R cschoi724/ai-agent-ops` 로 진행 중 작업 확인.
4. 사용자 지시를 받으면 §4.2/§4.3 지도로 해당 영역을 찾고, 관련 `design_notes/`·정책 문서·e2e 테스트를 함께 읽는다.
5. 구현 전 계획을 짧게 공유하고, 구현 후 §6 체크리스트와 `sh scripts/test.sh` 결과를 보고한다.
6. 분석 결과가 이 문서와 달라졌으면 이 문서(특히 §4.2 줄 번호, §9 과제)를 갱신한다.

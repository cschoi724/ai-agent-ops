# Bootstrap Runbook

작성일: 2026-07-10  
상태: Draft vNext  
범위: AI Ops Agent가 프로젝트 bootstrap을 실제로 진행하는 실행 절차

## 1. 목적

이 문서는 AI Ops Agent가 `project_bootstrap_policy.md`를 실제 대화와 작업 순서로 실행하는 방법을 정의한다.

`project_bootstrap_policy.md`는 어떤 선택지가 있고 어떤 기준으로 확정하는지를 정의한다. 이 runbook은 AI Ops Agent가 사용자와 어떤 순서로 확인하고, 어떤 중간 산출물을 보여주고, 언제 파일을 생성하거나 갱신하는지를 정의한다.

## 2. 관계

기준 정책:

```text
.ai/bootstrap/project_bootstrap_policy.md
```

주요 출력 위치:

```text
.ai_project/operating_model.md
.ai_project/agent_registry.md
.ai_project/source_of_truth.md
.ai_project/task_board.md
.ai_project/branch_pr_strategy.md
.ai_project/workflow_overrides.md
.ai_project/ops_decisions.md
.ai_project/ops_issues.md
.ai_project/tasks/
.ai_project/reports/
.ai_project/qa/
```

Team별 구성이 필요한 경우:

```text
.ai_project/teams/<team_id>/team_context.md
.ai_project/teams/<team_id>/task_board.md
.ai_project/teams/<team_id>/branch_pr_strategy.md
```

## 3. 실행 원칙

- Discovery Phase에서는 파일을 수정하지 않는다.
- Apply Phase는 사용자가 적용 범위를 승인한 뒤에만 시작한다.
- 운영 구성 확정 전에는 제품 Task를 만들지 않는다.
- 사용자가 선택하지 않은 값은 최종 구성으로 기록하지 않는다.
- 불명확한 값은 `pending_decision` 또는 `open_question`으로 남긴다.
- Role 이름은 `role_model.md` 기준을 따른다.
- 삭제된 v1 Agent 문서에 의존하지 않는다.
- Release Role과 release workflow는 사용자가 선택하거나 실제 릴리즈 책임이 생길 때만 활성화한다.
- 기존 프로젝트 문서는 명시 승인 없이 삭제하거나 대체하지 않는다.
- Git commit, push, PR, merge 정책은 프로젝트별 `branch_pr_strategy.md`가 정해진 뒤에 따른다.

## 4. 시작 입력

AI Ops Agent는 bootstrap 시작 시 아래 정보를 확인한다.

```text
target_project_path:
is_current_repository:
bootstrap_goal:
scan_permission:
write_permission:
```

기본 질문:

```text
AI Ops bootstrap을 시작합니다.
먼저 Discovery Phase에서는 파일을 수정하지 않고 프로젝트 구조와 운영 후보만 정리합니다.

대상 프로젝트는 현재 저장소인가요, 아니면 다른 경로인가요?
이번 bootstrap의 목표는 신규 운영체계 구성, 기존 운영 마이그레이션, 복구, 조직 확장 중 어디에 가깝나요?
프로젝트 구조를 스캔해도 될까요?
```

## 5. 전체 실행 흐름

```text
0. Session Contract
1. Start Context Classification
2. Project Scan
3. Readiness Judgment
4. Operating Mode Recommendation
5. Team Configuration
6. Role / Agent Mapping
7. Workflow / State Configuration
8. Ownership / Coordination Configuration
9. Board Configuration
10. Branch / PR Configuration
11. Source of Truth Mapping
12. Operating Model Draft
13. Approval Gate
14. Apply
15. Post-Apply Validation
16. Next Action Proposal
```

## 6. Phase 0: Session Contract

목적:

- bootstrap 범위를 명확히 한다.
- Discovery Phase와 Apply Phase를 분리한다.
- 파일 수정 전 승인 게이트가 있음을 사용자에게 알린다.

출력:

```text
bootstrap_scope:
target_project_path:
discovery_only_until_approval: yes
expected_outputs:
```

## 7. Phase 1: Start Context Classification

AI Ops Agent는 운영 모드보다 먼저 프로젝트 출발점을 분류한다.

선택 후보:

| Start Context | 실행 방향 |
|---|---|
| `new_project_with_requirement` | 요구사항 수준을 함께 확인하고 Direction / Lead / Execution 활성 순서를 정한다 |
| `assigned_or_existing_project` | 기존 코드와 문서의 source of truth를 먼저 확인한다 |
| `blank_slate_discovery` | 제품 Task 없이 문제 정의와 탐색 질문부터 구성한다 |
| `rescue_or_recovery` | 빌드, 테스트, 문서, 현재 상태를 먼저 복구 관점으로 스캔한다 |
| `migration_or_modernization` | 기능 개발보다 전환 계획과 ownership 정리를 우선한다 |
| `ops_setup_only` | `.ai_project/` 운영 문서 구성에 집중한다 |
| `scale_up_existing_ops` | Team, ownership, board, coordination을 우선 정리한다 |
| `custom_start_context` | 사용자가 정의한 출발점을 기록하고 필요한 질문을 추가한다 |

`new_project_with_requirement`인 경우 readiness level도 확인한다.

```text
idea_only
idea_structured
planning_ready
implementation_ready
```

출력:

```text
start_context:
readiness_level:
start_context_summary:
initial_role_focus:
```

## 8. Phase 2: Project Scan

AI Ops Agent는 대상 프로젝트를 읽고 운영 구성 후보를 만든다.

확인 항목:

- 프로젝트 유형
- 사용 언어 / 플랫폼
- 저장소 구조
- 주요 코드 경로
- 기존 문서
- 기존 운영 지침
- Git 기본 branch
- CI 존재 여부
- 테스트 / 빌드 명령
- 현재 Task / issue / board 사용 여부
- source of truth 후보
- ownership 후보

출력 형식:

```text
project_scan_summary:
  project_type:
  start_context:
  readiness_level:
  primary_platforms:
  code_paths:
  docs_found:
  build_commands:
  test_commands:
  git_default_branch:
  ci_found:
  task_or_issue_system:
  source_of_truth_candidates:
  ownership_candidates:
  risks:
```

## 9. Phase 3: Readiness Judgment

Project Scan 이후 실행 준비 수준을 판단한다.

판단 항목:

- 요구사항을 Task로 나눌 수 있는가?
- 먼저 방향 결정이나 기획이 필요한가?
- 기존 source of truth가 있는가?
- 바로 구현할 수 있는가?
- Verification Role이 무엇을 검증해야 하는가?
- Branch / PR 전략을 지금 정할 수 있는가?

출력:

```text
readiness_summary:
recommended_next_phase:
execution_ready: yes / no
verification_ready: yes / no
branch_pr_ready: yes / no
required_decisions:
```

## 10. Phase 4: Operating Mode Recommendation

AI Ops Agent는 하나의 추천값과 대안을 함께 제시한다.

선택 후보:

```text
solo_light
team_basic
team_pr
multi_team
enterprise
custom
```

기본 추천 기준:

- 개인 실험 또는 작은 문서 작업: `solo_light`
- Lead / Execution / Verification만 필요한 경우: `team_basic`
- task branch, PR, merge가 필요한 경우: `team_pr`
- iOS / Android / Web / Backend처럼 Team 분리가 필요한 경우: `multi_team`
- Division, Release, QA, Business 운영까지 필요한 경우: `enterprise`

출력:

```text
recommended_operating_mode:
reason:
alternatives:
user_selection_required: yes
```

## 11. Phase 5: Team Configuration

선택 후보:

```text
single_team
platform_team
feature_team
module_team
custom_team
multi_team
```

Team별 최소 결정값:

```text
team_id:
team_name:
parent_division:
team_purpose:
allowed_paths:
owned_domains:
source_of_truth:
required_roles:
team_board_required:
branch_pr_override:
```

Team 구성은 특정 프로젝트에 종속된다. `.ai/`에는 일반 모델과 선택지를 두고, 실제 선택값은 `.ai_project/`에 기록한다.

## 12. Phase 6: Role / Agent Mapping

기본 Role 후보:

```text
Direction Role
Lead Role
Execution Role
Verification Role
Ops Governance Role
Release Role
```

초기 권장 활성화:

- 대부분의 개발 프로젝트: Lead / Execution / Verification / Ops Governance
- 아이디어 단계: Direction / Lead / Ops Governance
- 복구 프로젝트: Lead / Verification / Ops Governance
- 릴리즈가 없는 프로젝트: Release Role 비활성

결정값:

```text
role_id:
active:
assigned_agent:
scope:
required_capabilities:
handoff_target:
```

## 13. Phase 7: Workflow / State Configuration

선택 후보:

```text
standard_vnext
skip_scoped_for_simple_tasks
require_scoped_for_all_tasks
custom
```

기본 상태 흐름:

```text
proposed
triaged
scoped
approved
in_progress
verification_ready
verification_in_progress
verification_passed
completion_review
done
```

예외 상태:

```text
blocked
rework_requested
cancelled
superseded
```

결정값은 `.ai_project/workflow_overrides.md` 또는 `.ai_project/operating_model.md`에 기록한다.

## 14. Phase 8: Ownership / Coordination Configuration

Ownership 선택 후보:

```text
path_only
path_plus_domain
document_ownership
strict_parallel_control
custom
```

Coordination 선택 후보:

```text
single_active_task
parallel_with_dependencies
parallel_by_ownership
lead_coordinated_parallel
custom
```

결정값:

```text
ownership_policy:
coordination_policy:
parallel_work_allowed:
conflict_resolution_owner:
blocked_resolution_owner:
```

## 15. Phase 9: Board Configuration

선택 후보:

```text
project_board_only
project_plus_team_board
team_board_only
custom_views
```

기본 추천:

- single team: `project_board_only`
- multi team: `project_plus_team_board`
- 독립 제품 라인이 여러 개면: `custom_views`

결정값:

```text
board_policy:
project_board_path:
team_board_paths:
required_views:
review_cadence:
```

## 16. Phase 10: Branch / PR Configuration

선택 후보:

```text
feature_branch_pr
trunk_based_pr
gitflow
custom
```

기본 추천:

```text
feature_branch_pr
```

결정 항목:

```text
default_branch:
task_branch_pattern:
commit_owner:
commit_timing:
push_allowed:
pr_required:
review_required:
merge_owner:
delete_branch_after_merge:
```

안전 기본값:

- 작업은 task branch에서 진행한다.
- `main` 또는 기본 branch에 직접 push하지 않는다.
- Execution Role은 작업 단위 커밋을 만들 수 있다.
- Verification Role은 검증 결과를 기록한다.
- Lead Role이 최종 merge 여부를 확인한다.
- 자동 merge는 프로젝트별로 명시 승인된 경우에만 허용한다.

## 17. Phase 11: Source of Truth Mapping

AI Ops Agent는 프로젝트의 기준 문서를 확정하거나 누락을 기록한다.

확인 대상:

```text
requirements:
planning:
architecture:
design:
api:
operations:
test_strategy:
release_notes:
```

출력:

```text
source_of_truth:
  requirements:
  planning:
  architecture:
  design:
  api:
  operations:
  test_strategy:
  unresolved:
```

누락된 기준 문서는 임의로 생성하지 않고, 생성 후보로 제안한다.

## 18. Phase 12: Operating Model Draft

파일을 쓰기 전 사용자에게 아래 초안을 보여준다.

```text
Operating Model Draft

Start Context:
Readiness Level:
Operating Mode:
Organization:
Teams:
Active Roles:
Agent Mapping:
Workflow Policy:
Ownership Policy:
Coordination Policy:
Board Policy:
Branch / PR Policy:
Source of Truth:

Files to create:
Files to update:
Files not touched:

Open Questions:
Risks:
```

## 19. Phase 13: Approval Gate

AI Ops Agent는 Apply Phase 전에 명시 승인을 받아야 한다.

승인 질문:

```text
위 Operating Model Draft 기준으로 `.ai_project/` 문서를 생성 또는 갱신해도 될까요?
이번 Apply Phase에서 생성/수정할 파일은 아래 목록으로 제한합니다.
```

승인 전 금지:

- `.ai_project/` 파일 생성
- 기존 프로젝트 문서 수정
- 제품 Task 등록
- branch 생성
- commit 생성
- push / PR / merge

## 20. Phase 14: Apply

승인 후 실행한다.

기본 생성 후보:

```text
.ai_project/operating_model.md
.ai_project/agent_registry.md
.ai_project/source_of_truth.md
.ai_project/task_board.md
.ai_project/branch_pr_strategy.md
.ai_project/workflow_overrides.md
.ai_project/ops_decisions.md
.ai_project/ops_issues.md
```

필요 시 생성:

```text
.ai_project/teams/<team_id>/team_context.md
.ai_project/teams/<team_id>/task_board.md
.ai_project/teams/<team_id>/branch_pr_strategy.md
```

Apply 기록:

```text
applied_at:
applied_by:
source_policy_version:
created_files:
updated_files:
deferred_files:
open_questions:
```

## 21. Phase 15: Post-Apply Validation

AI Ops Agent는 생성/수정 후 정합성을 확인한다.

체크리스트:

- `.ai_project/operating_model.md`가 존재한다.
- Start Context와 Readiness Level이 기록되어 있다.
- 선택한 Operating Mode가 기록되어 있다.
- Role / Agent mapping이 기록되어 있다.
- Team이 있으면 ownership과 board 기준이 연결되어 있다.
- Branch / PR 전략이 선택값으로 기록되어 있다.
- Source of truth 누락 항목이 `unresolved`로 남아 있다.
- 사용자 승인 없이 제품 Task가 생성되지 않았다.
- Release Role이 불필요한 프로젝트에서 활성화되지 않았다.

출력:

```text
post_apply_report:
  validation_passed:
  created_files:
  updated_files:
  remaining_open_questions:
  recommended_next_action:
```

## 22. Phase 16: Next Action Proposal

bootstrap 완료 후 다음 작업을 제안한다.

Readiness별 기본 제안:

| Readiness | 다음 제안 |
|---|---|
| `idea_only` | Direction Role 중심 discovery Task 또는 기획 문서 작성 |
| `idea_structured` | 기획 정리 Task와 source of truth 후보 확정 |
| `planning_ready` | 구현 계획, milestone, task breakdown 작성 |
| `implementation_ready` | 첫 제품 Task를 `proposed` 상태로 등록 |
| `existing_project_scan_required` | 기존 문서와 코드 기준 정합성 점검 |
| `discovery_required` | 문제 정의 질문과 탐색 보드 구성 |
| `recovery_required` | 빌드/테스트/문서 상태 복구 Task 구성 |
| `ops_only` | 운영 문서 검토와 Agent 세션 시작 가이드 작성 |

## 23. Start Context별 실행 차이

### 23.1 `new_project_with_requirement`

- readiness level을 반드시 확인한다.
- `idea_only`에서는 Execution Role을 즉시 활성화하지 않는다.
- `implementation_ready`에서는 `team_pr` 또는 `team_basic`을 우선 검토한다.

### 23.2 `assigned_or_existing_project`

- Project Scan을 충분히 수행한다.
- 기존 문서와 실제 코드가 충돌하면 source of truth를 바로 확정하지 않는다.
- 첫 작업은 보통 운영 마이그레이션 또는 현황 정리 Task다.

### 23.3 `blank_slate_discovery`

- 제품 Task를 만들지 않는다.
- Direction Role 중심으로 문제 정의와 탐색 질문을 구성한다.
- source of truth는 discovery 결과 이후 확정한다.

### 23.4 `rescue_or_recovery`

- 빌드, 테스트, CI, 최근 변경 이력을 우선 확인한다.
- Verification Role을 초기에 활성화한다.
- feature 개발보다 복구 Task를 먼저 제안한다.

### 23.5 `migration_or_modernization`

- migration scope와 rollback 기준을 먼저 정한다.
- 기존 운영 문서 삭제나 대체는 별도 승인으로 처리한다.
- ownership과 coordination 정책을 초기에 확정한다.

### 23.6 `ops_setup_only`

- 제품 코드 변경을 하지 않는다.
- `.ai_project/` 운영 문서 생성에 집중한다.
- 첫 제품 Task를 만들지 않는다.

### 23.7 `scale_up_existing_ops`

- Team 분리 기준과 ownership 충돌 가능성을 먼저 확인한다.
- project board와 team board의 관계를 정한다.
- coordination policy를 명시적으로 선택한다.

## 24. 질문 팩

### 24.1 Start Context

```text
이 프로젝트의 시작 유형은 무엇인가요?
- 요구사항이 있는 신규 프로젝트/사업 시작
- 기존 프로젝트/업무/과업 인수
- 백지 탐색
- 복구 프로젝트
- 마이그레이션/현대화
- AI 운영체계만 도입
- 기존 운영 조직 확장
- custom
```

### 24.2 Readiness

```text
현재 요구사항 수준은 어디에 가깝나요?
- idea_only
- idea_structured
- planning_ready
- implementation_ready
```

### 24.3 Operating / Team

```text
추천 운영 모드는 `<mode>`입니다.
이유는 `<reason>`입니다.
이 모드로 진행할까요, 아니면 다른 구성을 선택할까요?
```

### 24.4 Role / Workflow

```text
초기 활성 Role은 Lead / Execution / Verification / Ops Governance로 제안합니다.
Release Role은 현재 비활성으로 두는 구성이 적절해 보입니다.
이 Role 구성으로 진행할까요?
```

### 24.5 Git

```text
Git 전략은 feature branch + PR 기반을 기본값으로 제안합니다.
Execution Role은 task branch에서 커밋하고, Verification Role이 검증한 뒤 Lead Role이 merge 여부를 확인하는 흐름입니다.
이 전략을 프로젝트 기본값으로 기록할까요?
```

### 24.6 Apply Approval

```text
아래 파일만 생성/수정하는 Apply Phase를 진행해도 될까요?
```

## 25. 금지사항

- Discovery Phase에서 파일을 수정하지 않는다.
- 승인 없이 `.ai_project/`를 생성하지 않는다.
- 승인 없이 기존 프로젝트 문서를 삭제하거나 이동하지 않는다.
- 운영 구성이 확정되기 전 제품 Task를 생성하지 않는다.
- 기본 branch에 직접 push하지 않는다.
- 사용자가 선택하지 않은 Git flow를 강제하지 않는다.
- Release Role이 필요하지 않은 프로젝트에 release workflow를 활성화하지 않는다.
- source of truth가 불명확한 문서를 최종 기준으로 단정하지 않는다.

## 26. 완료 기준

bootstrap은 아래 조건을 만족하면 완료로 본다.

- Start Context가 기록되어 있다.
- Readiness Level 또는 그에 준하는 준비 상태가 기록되어 있다.
- Operating Mode가 선택되어 있다.
- Organization / Team 구성이 선택되어 있다.
- Role / Agent mapping이 선택되어 있다.
- Workflow / State 운영 기준이 선택되어 있다.
- Ownership / Coordination 기준이 선택되어 있다.
- Board 기준이 선택되어 있다.
- Branch / PR 전략이 선택되어 있다.
- Source of truth 후보와 미해결 항목이 기록되어 있다.
- `.ai_project/operating_model.md`가 실제 프로젝트 운영 구성의 인덱스 역할을 한다.
- 다음 action이 discovery, planning, implementation, recovery, ops validation 중 하나로 제안되어 있다.

## 27. 변경 이력

| 날짜 | 변경 내용 |
|---|---|
| 2026-07-10 | Start Context 기반 프로젝트 bootstrap 실행 runbook 초안 작성 |

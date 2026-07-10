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
- Bootstrap Discovery는 일괄 제안이 아니라 대화형 의사결정으로 진행한다.
- AI Ops Agent는 한 번에 전체 Operating Model Draft를 만들지 않는다.
- 각 단계는 질문, 사용자 답변, Agent 의견, 결정값, 보류값을 `Decision Stack`에 쌓는다.
- 최종 Draft는 필수 결정값이 충분히 쌓인 뒤에만 제안한다.
- `.ai/`가 없는 프로젝트에서 운영체계 템플릿 설치가 필요하면 `install_runbook.md`를 먼저 따른다.
- 운영 구성 확정 전에는 제품 Task를 만들지 않는다.
- 사용자가 선택하지 않은 값은 최종 구성으로 기록하지 않는다.
- 불명확한 값은 `pending_decision` 또는 `open_question`으로 남긴다.
- Role 이름은 `role_model.md` 기준을 따른다.
- 삭제된 v1 Agent 문서에 의존하지 않는다.
- Release Role과 release workflow는 사용자가 선택하거나 실제 릴리즈 책임이 생길 때만 활성화한다.
- 기존 프로젝트 문서는 명시 승인 없이 삭제하거나 대체하지 않는다.
- Git commit, push, PR, merge 정책은 프로젝트별 `branch_pr_strategy.md`가 정해진 뒤에 따른다.

## 4. 시작 입력

### 4.0 Install과 Bootstrap 구분

AI Ops Agent는 install과 bootstrap을 구분한다.

```text
Install
  - `.ai/` 운영체계 템플릿을 프로젝트에 설치한다.
  - 기준 문서: .ai/bootstrap/install_runbook.md

Bootstrap
  - `.ai_project/`에 프로젝트별 운영 구성을 만든다.
  - 기준 문서: .ai/bootstrap/bootstrap_runbook.md
```

사용자가 `AI Ops 시드 구성해줘`라고 말하면 이 문서가 아니라 `install_runbook.md`를 따른다.

사용자가 `AI Ops bootstrap 시작해줘`라고 말했는데 대상 프로젝트에 `.ai/`가 없으면, 바로 `.ai_project/` 생성을 제안하지 않고 먼저 아래처럼 확인한다.

```text
현재 프로젝트에 `.ai/`가 없습니다.
먼저 `AI Ops 시드 구성해줘.`로 `.ai/` 운영체계 템플릿을 구성해주세요.
```

### 4.1 Bootstrap Trigger

사용자가 아래 문장을 말하면 AI Ops Agent는 bootstrap 요청으로 해석한다.

```text
AI Ops bootstrap 시작해줘.
```

동등한 표현:

```text
이 프로젝트 AI Ops bootstrap 해줘.
bootstrap 시작해줘.
AI 운영체계 초기 구성 시작해줘.
```

Trigger를 받으면 AI Ops Agent는 아래 기본 계약으로 시작한다.

```text
role: AI Ops Agent
mode: Discovery Phase
write_permission: no
goal: 단계별 질문 -> Decision Stack 누적 -> 최종 Operating Model Draft 제안
```

첫 응답은 짧게 시작한다.

```text
AI Ops bootstrap을 Discovery Phase로 시작합니다.
기준 문서는 `.ai/bootstrap/bootstrap_runbook.md`입니다.
현재 단계는 자동화 스크립트 실행이 아니라 문서 기반 Discovery입니다.
먼저 파일은 수정하지 않고 `.ai/`, `AGENTS.md`, `.ai_project/` 존재 여부를 확인한 뒤 단계별 질문으로 운영 구성을 결정하겠습니다.
각 답변은 Decision Stack에 쌓고, 필수 결정이 모이면 최종 Operating Model Draft를 제안하겠습니다.
```

첫 스캔 결과에는 아래 항목을 포함한다.

```text
AI Ops Source:
Runbook:
AGENTS.md:
.ai/:
.ai_project/:
Automation Script:
```

`Automation Script`는 실제 실행 스크립트가 없으면 `none`으로 기록한다.

현재 작업 디렉토리가 `ai-agent-ops` 템플릿 저장소인지, 실제 적용 대상 프로젝트인지 먼저 구분한다.

템플릿 저장소로 판단되는 신호:

- `core/`, `models/`, `policies/`, `runtime/`, `bootstrap/`, `templates/`가 루트에 있다.
- `bootstrap/project_bootstrap_policy.md`와 `bootstrap/bootstrap_runbook.md`가 루트에 있다.
- `.ai_project/`가 없다.
- 저장소 이름이나 branch가 `ai-agent-ops`, `ai-agent-ops-org`, `org-ops-model`에 가깝다.

템플릿 저장소로 판단되면 바로 `.ai_project/` 생성을 제안하지 않고 아래처럼 확인한다.

```text
현재 디렉토리는 ai-agent-ops 템플릿 저장소로 보입니다.
이 저장소 자체의 운영 구성을 점검할까요, 아니면 다른 대상 프로젝트 경로를 지정할까요?
```

실제 적용 대상 프로젝트로 판단되는 경우에만 해당 프로젝트 루트에 `.ai_project/` 생성을 후보로 제안한다.

### 4.2 시작 입력

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

## 5. 대화형 진행 원칙

AI Ops Agent는 bootstrap을 질의응답 방식으로 진행한다.

금지되는 진행:

- Project Scan 직후 전체 Operating Model Draft를 한 번에 제안한다.
- 사용자가 답하지 않은 제품 목표, MVP, Role, Git 전략을 확정값처럼 작성한다.
- 추천안을 길게 작성한 뒤 바로 Apply 승인 여부를 묻는다.
- 사용자의 의견 수렴 없이 `.ai_project/` 생성 파일 목록을 확정한다.

허용되는 진행:

- 현재 단계의 질문 1개 또는 밀접한 질문 2개만 묻는다.
- Agent 추천은 질문 뒤에 짧은 근거로 제시한다.
- 선택지를 제시할 때는 이름만 나열하지 않고, 각 선택지의 의미와 선택 시 달라지는 운영 방식을 함께 설명한다.
- Team, Role, Workflow처럼 운영 구조에 영향을 주는 단계에서는 `추천값`, `대안`, `선택하면 생기는 차이`, `나중에 바꿀 수 있는지`를 짧게 설명한다.
- 사용자의 답변을 `Decision Stack`에 누적한다.
- 결정되지 않은 항목은 `pending_decision`으로 둔다.
- 충분한 결정값이 모였는지 확인한 뒤 최종 Draft를 만든다.

선택지 설명 형식:

```text
선택지:
- option_id: 한 줄 의미. 선택하면 달라지는 점. 권장 상황.

추천:
- option_id: 추천 이유

확인:
- 이 값으로 확정할까요, 아니면 다른 선택지를 비교할까요?
```

설명 깊이 기준:

- Start Context / Readiness: 사용자가 자기 프로젝트 상태를 고를 수 있을 만큼 사례를 든다.
- Team / Role / Workflow: 선택 이후 실제 운영 방식이 어떻게 바뀌는지 설명한다.
- Ownership / Coordination / Branch: 안전성과 복잡도 trade-off를 설명한다.
- 사용자가 이미 잘 안다고 답하면 이후 단계는 더 짧게 진행할 수 있다.
- 사용자가 "무슨 뜻이야", "차이가 뭐야", "잘 모르겠어"라고 하면 해당 단계의 옵션 설명을 먼저 보강하고 결정을 미룬다.

Fast Track 진행 원칙:

- 전문 용어를 먼저 노출하지 않는다.
- 처음 질문은 "무엇을 하려는 프로젝트인지", "지금 단계가 아이디어/기획/구현/기존 프로젝트 중 어디인지", "혼자 쓸지 여러 Agent로 나눌지"에 집중한다.
- 운영 기본값은 AI Ops Agent가 추천하되, 확정 전 Decision Stack Review에서 사용자가 확인할 수 있게 한다.
- 고급 설정은 기본값과 "나중에 바꿀 수 있음"으로 처리한다.
- 사용자가 고급 설정을 원한다고 말하면 일반 Bootstrap 흐름으로 전환한다.
- Fast Track에서도 Apply 전에는 파일을 수정하지 않는다.

Decision Stack 형식:

```text
Decision Stack

confirmed:
  - key:
    value:
    reason:

pending:
  - key:
    question:
    options:

open_questions:
  - question:
    why_it_matters:

assumptions:
  - assumption:
    confidence:
    needs_confirmation:
```

각 단계가 끝날 때 Agent는 짧게 현재 stack을 요약한다.

```text
지금까지 확정된 결정:
- Start Context: ...
- Readiness: ...

아직 결정할 것:
- Operating Mode
- Team 구성

다음 질문:
...
```

## 6. 전체 실행 흐름

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
12. Decision Stack Review
13. Operating Model Draft
14. Approval Gate
15. Apply
16. Post-Apply Validation
17. Next Action Proposal
```

각 단계는 아래 패턴을 따른다.

```text
1. 이전 결정 요약
2. 현재 단계 질문
3. 선택지와 추천값 제시
4. 사용자 답변 대기
5. Decision Stack 업데이트
6. 다음 단계로 진행할지 확인
```

## 7. Phase 0: Session Contract

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

## 8. Phase 1: Start Context Classification

AI Ops Agent는 운영 모드보다 먼저 프로젝트 출발점을 분류한다.

선택 후보:

| Start Context | 의미 | 먼저 할 일 | 권장 상황 |
|---|---|---|---|
| `new_project_with_requirement` | 요구사항이나 아이디어가 있는 신규 프로젝트/사업 시작 | Readiness를 확인하고 Direction / Lead / Execution 활성 순서를 정한다 | 새 앱, 새 서비스, 새 사업 아이디어 |
| `assigned_or_existing_project` | 기존 프로젝트, 회사 업무, 과업, 인수인계 | 기존 코드와 문서의 source of truth를 먼저 확인한다 | 이미 있는 저장소나 업무를 맡았을 때 |
| `blank_slate_discovery` | 뭘 만들지부터 정해야 하는 백지 탐색 | 제품 Task 없이 문제 정의와 탐색 질문부터 구성한다 | 아이템 발굴, 리서치, 사업 주제 탐색 |
| `rescue_or_recovery` | 중단, 실패, 빌드 불가, 품질 문제 복구 | 빌드, 테스트, 문서, 현재 상태를 복구 관점으로 스캔한다 | 망가진 프로젝트, 정체된 프로젝트, 품질 회복 |
| `migration_or_modernization` | 기존 시스템/문서/운영을 새 구조로 이전 | 기능 개발보다 전환 계획과 ownership 정리를 우선한다 | 레거시 개편, 프레임워크 전환, 운영 모델 전환 |
| `ops_setup_only` | 제품 개발 없이 AI 운영체계만 도입 | `.ai_project/` 운영 문서 구성에 집중한다 | 운영 규칙만 먼저 깔고 싶을 때 |
| `scale_up_existing_ops` | 이미 돌아가는 프로젝트를 조직형으로 확장 | Team, ownership, board, coordination을 우선 정리한다 | 팀/플랫폼/기능이 늘어난 프로젝트 |
| `custom_start_context` | 위 분류로 설명되지 않는 출발점 | 사용자 정의 맥락을 기록하고 필요한 질문을 추가한다 | 특수한 조직/계약/프로세스가 있을 때 |

`new_project_with_requirement`인 경우 readiness level도 확인한다.

| Readiness | 의미 | 먼저 구성할 것 | Execution 활성 |
|---|---|---|---|
| `idea_only` | 아이디어만 있고 문제/사용자/범위가 불명확 | Direction Role 중심 discovery | 기본 비활성 |
| `idea_structured` | 아이디어와 핵심 기능은 있지만 기획 문서가 부족 | Direction + Lead로 기획 정리 | 제한적 또는 보류 |
| `planning_ready` | 기획/범위는 있으나 구현 계획과 Task 분해가 필요 | Lead 중심 scope/task breakdown | 준비 후 활성 |
| `implementation_ready` | 구현 요구사항과 성공 기준이 비교적 명확 | Lead + Execution + Verification | 활성 가능 |

질문 시에는 사용자가 고르기 쉽게 "현재 프로젝트가 신규/기존/백지/복구/마이그레이션/운영도입/확장 중 어디에 가까운지"부터 묻고, 신규 프로젝트이면 readiness를 이어서 묻는다.

출력:

```text
start_context:
readiness_level:
start_context_summary:
initial_role_focus:
```

## 9. Phase 2: Project Scan

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

## 10. Phase 3: Readiness Judgment

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

사용자에게 보여줄 설명:

| Readiness | 의미 | 선택하면 달라지는 점 | 다음 액션 |
|---|---|---|---|
| `idea_only` | 아이디어가 아직 문장 수준이거나 불명확 | 구현 Task를 만들지 않고 질문/탐색 중심으로 간다 | 문제 정의, 대상 사용자, 가치 가설 정리 |
| `idea_structured` | 목적과 핵심 기능이 대략 있음 | 제품 방향과 최소 범위를 문서화한 뒤 운영 구성을 확정한다 | 요구사항 초안, MVP 범위, 리스크 정리 |
| `planning_ready` | 기획은 있으나 구현 계획이 부족 | Task breakdown, source of truth, 검증 기준을 먼저 정한다 | milestone, architecture, test strategy 후보 |
| `implementation_ready` | 바로 구현 가능한 요구사항과 기준이 있음 | Execution/Verification Role을 활성화하고 첫 Task 등록을 검토한다 | branch/PR, board, 첫 proposed Task |
| `existing_project_scan_required` | 기존 프로젝트라 현황 확인이 먼저 필요 | 기존 문서와 실제 코드가 맞는지 검토한다 | source of truth 정합성 점검 |
| `discovery_required` | 문제 정의가 부족함 | Direction Role 중심으로 discovery board를 구성한다 | 질문 목록, 조사 Task |
| `recovery_required` | 복구/안정화가 먼저 필요 | 기능 개발보다 빌드/테스트/문서 복구를 우선한다 | recovery Task, Verification 기준 |
| `ops_only` | 제품 작업이 아니라 운영체계 구성 목적 | `.ai_project/` 구성과 세션 가이드만 만든다 | 운영 문서 적용, Agent 사용법 |

Readiness는 "프로젝트의 가치"가 아니라 "지금 바로 실행 가능한 정도"다. 사용자가 낮은 단계로 선택해도 실패가 아니라 안전한 시작점으로 기록한다.

## 11. Phase 4: Operating Mode Recommendation

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

사용자에게 보여줄 설명:

| 옵션 | 의미 | 선택하면 달라지는 점 | 권장 상황 |
|---|---|---|---|
| `solo_light` | 한 사람이 여러 Role을 가볍게 겸하는 최소 운영 | Team board 없이 단일 흐름으로 시작하고, 복잡한 승인 단계를 줄인다 | 아이디어/초기 기획/작은 개인 프로젝트 |
| `team_basic` | Lead / Execution / Verification을 분리한 기본 팀 운영 | 작업 등록, 실행, 검증 책임이 분리된다 | 구현과 검증을 나눠 안전하게 운영하고 싶을 때 |
| `team_pr` | 기본 팀 운영에 branch/PR/merge 흐름을 추가 | Execution은 task branch에서 작업하고 Verification 검토 후 Lead가 merge 판단한다 | 코드 프로젝트, 협업, 변경 이력 관리가 중요할 때 |
| `multi_team` | 플랫폼/기능/모듈별 Team을 분리 | Team ownership, board, cross-team coordination이 필요하다 | iOS/Web/Backend처럼 책임 경로가 분리될 때 |
| `enterprise` | Division, QA, Release, Business까지 확장 | 운영 문서와 승인 게이트가 많아지지만 대규모 조율에 강하다 | 여러 제품/팀/릴리즈 체계가 있는 조직 |
| `custom` | 사용자가 직접 운영 방식을 조합 | 자유도가 높지만 필수 결정값을 더 많이 확인해야 한다 | 기존 조직 규칙이 있거나 특수한 프로젝트 |

질문 시에는 추천값만 확정하지 말고, 최소 2개의 대안을 함께 비교한다.

출력:

```text
recommended_operating_mode:
reason:
alternatives:
user_selection_required: yes
```

## 12. Phase 5: Team Configuration

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

사용자에게 보여줄 설명:

| 옵션 | 의미 | 선택하면 달라지는 점 | 권장 상황 |
|---|---|---|---|
| `single_team` | 하나의 Team이 제품/프로젝트 작업을 대부분 처리 | project board 하나, 공통 branch 전략 하나로 단순하게 운영한다 | 초기 프로젝트, 작은 앱, Team 경계가 아직 불명확할 때 |
| `platform_team` | iOS, Android, Web, Backend처럼 플랫폼별 Team을 둔다 | path ownership과 빌드/테스트 기준을 Team별로 나눈다 | 플랫폼별 코드와 검증 방식이 다를 때 |
| `feature_team` | Auth, Search, Payment처럼 기능 도메인별 Team을 둔다 | 한 기능이 여러 경로를 수정할 수 있어 domain ownership을 중시한다 | 기능 도메인 책임이 플랫폼보다 중요할 때 |
| `module_team` | Design System, Networking, Persistence처럼 모듈별 Team을 둔다 | 공통 모듈 변경의 downstream 영향을 더 엄격히 본다 | 재사용 모듈이나 라이브러리 영향이 클 때 |
| `custom_team` | 사용자가 Team 이름과 책임을 직접 정한다 | 자유롭게 구성하되 Role, allowed paths, source of truth를 반드시 정한다 | 기존 조직명이 있거나 특수한 협업 구조일 때 |
| `multi_team` | 둘 이상의 Team을 조합한다 | Team별 board/ownership/coordination 결정이 추가된다 | 병렬 개발과 충돌 조율이 필요한 규모일 때 |

Team 질문 시 확인할 내용:

- Team을 나누는 기준이 `사람`, `플랫폼`, `기능`, `코드 경로`, `검증 책임` 중 무엇인지 묻는다.
- 초기 프로젝트에서 기준이 불명확하면 `single_team`을 추천하고, 나중에 Team을 분리할 수 있음을 설명한다.
- 사용자가 iOS Team 같은 구체 Team을 언급하면 Test/QA/Release를 바로 분리하지 말고 병목이나 release gate가 있는지 먼저 확인한다.
- Team 이름은 자유롭게 정할 수 있지만, Role과 workflow 계약은 유지해야 한다고 설명한다.

## 13. Phase 6: Role / Agent Mapping

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

사용자에게 보여줄 설명:

| Role | 쉬운 설명 | 주로 하는 일 | 활성화 기준 |
|---|---|---|---|
| Direction Role | "무엇을 왜 할지" 정하는 역할 | 목표, 우선순위, 승인, 제품 방향 판단 | 아이디어/기획/우선순위 결정이 필요할 때 |
| Lead Role | "작업이 실행 가능하게 정리"하는 역할 | Task 등록, 범위 조율, ownership, dependency, merge 판단 | 대부분의 프로젝트에서 기본 활성 |
| Execution Role | "실제로 만드는" 역할 | 구현, 문서 작성, 리팩터링, 개발자 검증, 작업 보고 | 구현/수정/조사 작업이 있을 때 |
| Verification Role | "독립적으로 확인"하는 역할 | 테스트, QA, PR review, 리스크 판단, rework 요청 | 결과 검증이 필요할 때 |
| Completion Role | "완료로 닫아도 되는지" 보는 역할 | 검증 결과 수용, 잔여 리스크, 후속 Task, done 처리 | 검증 이후 완료 판단이 필요할 때. 작은 팀은 Lead가 겸임 가능 |
| Release Role | "배포와 운영 인계" 역할 | release checklist, rollback, 운영 인계, 배포 승인 조건 | 실제 배포/릴리즈 게이트가 있을 때만 활성 |
| Ops Governance Role | "운영체계가 잘 작동하는지" 보는 역할 | Role 경계, workflow, 문서 구조, 운영 이슈 점검 | AI Ops 적용 프로젝트에서는 기본 활성 |

Role 질문 시 확인할 내용:

- Agent 이름과 Role을 분리해서 설명한다. 예: `PM Agent`가 `Lead Role`과 일부 `Direction Role`을 맡을 수 있다.
- Release Role은 배포 대상이나 release gate가 없으면 비활성으로 두는 것을 기본값으로 한다.
- Execution과 Verification은 같은 세션이 연속으로 처리하지 않는 것이 기본 안전 원칙임을 설명한다.
- 작은 프로젝트에서는 Direction/Lead/Completion을 한 Agent가 겸할 수 있지만, Task 상태 전이 책임은 구분한다고 설명한다.

결정값:

```text
role_id:
active:
assigned_agent:
scope:
required_capabilities:
handoff_target:
```

## 14. Phase 7: Workflow / State Configuration

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

사용자에게 보여줄 설명:

| 옵션 | 의미 | 선택하면 달라지는 점 | 권장 상황 |
|---|---|---|---|
| `standard_vnext` | proposed부터 done까지 모든 기본 단계를 사용 | 범위 정리, 승인, 실행, 검증, 완료 판단이 명확히 분리된다 | 일반 개발 프로젝트, 협업, 리스크가 있는 작업 |
| `skip_scoped_for_simple_tasks` | 단순 작업은 scoped를 생략하고 proposed -> approved로 갈 수 있음 | 속도는 빠르지만 ownership/allowed_paths가 애매한 작업은 표준 흐름으로 되돌린다 | solo_light, 문서 정리, 작은 수정 |
| `require_scoped_for_all_tasks` | 모든 작업이 반드시 scoped를 거침 | 느리지만 충돌, 책임, 경로, 기준 문서를 강하게 통제한다 | 여러 Team, 민감한 코드, 병렬 작업 |
| `custom` | 프로젝트별 상태 전이를 직접 정의 | 자유도가 높지만 상태별 담당 Role과 전이 조건을 별도 문서화해야 한다 | 기존 이슈/PR 프로세스가 이미 있을 때 |

상태 설명:

| 상태 | 의미 | 다음 판단 |
|---|---|---|
| `proposed` | 할 일 후보가 생겼지만 아직 실행 대상은 아님 | 목적, 우선순위, 성공 기준을 정한다 |
| `scoped` | 실행 가능한 범위와 책임이 정리됨 | 승인할지 판단한다 |
| `approved` | 실행 승인 완료 | Execution Role이 작업할 수 있다 |
| `in_progress` | 실행 중 | lock과 변경 범위를 관리한다 |
| `verification_ready` | 실행자가 검증 가능한 결과를 넘김 | Verification Role이 받을 수 있다 |
| `verification_in_progress` | 검증 중 | PASS, FAIL, BLOCKED를 판단한다 |
| `verification_passed` | 검증 통과 또는 리스크 수용 가능 | Completion Role이 완료 판단한다 |
| `completion_review` | 완료 확정 전 마지막 확인 | done, rework, blocked를 결정한다 |
| `done` | 완료 확정 | board와 후속 Task를 정리한다 |
| `blocked` | 외부 요인이나 의존성 때문에 진행 불가 | 차단 해소 주체를 정한다 |
| `rework_requested` | 수정 필요 | 재작업 범위와 담당 Role을 정한다 |
| `cancelled` | 진행하지 않기로 확정 | 이유를 기록하고 닫는다 |

Workflow 질문 시에는 "운영 부담을 줄이려면 짧은 흐름, 안전성을 높이려면 표준 또는 scoped 필수 흐름"이라는 trade-off를 설명한다.

## 15. Phase 8: Ownership / Coordination Configuration

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

사용자에게 보여줄 Ownership 설명:

| 옵션 | 의미 | 선택하면 달라지는 점 | 권장 상황 |
|---|---|---|---|
| `path_only` | 파일/디렉토리 경로 기준으로 책임을 나눈다 | 단순하고 이해하기 쉽지만 기능 도메인 영향은 놓칠 수 있다 | 초기 프로젝트, single team, 코드 경로가 명확할 때 |
| `path_plus_domain` | path 책임에 Auth/Search 같은 기능 도메인 책임을 더한다 | 같은 기능이 여러 경로에 걸쳐도 검토 주체를 정할 수 있다 | 대부분의 앱/서비스 개발, 플랫폼이 늘어날 가능성이 있을 때 |
| `document_ownership` | source of truth 문서 책임을 명시한다 | 요구사항/아키텍처/API 문서 변경 충돌을 통제한다 | 문서가 기준이 되는 프로젝트, 기획/설계가 중요한 프로젝트 |
| `strict_parallel_control` | ownership 충돌 가능성이 있으면 병렬 작업을 강하게 제한한다 | 속도는 느려지지만 충돌과 재작업을 줄인다 | multi-team, migration, 민감한 코드, 릴리즈 전 작업 |
| `custom` | 프로젝트별 ownership 규칙을 직접 정의한다 | 자유도가 높지만 충돌 판단 기준을 별도로 써야 한다 | 기존 CODEOWNERS나 조직별 owner 체계가 있을 때 |

사용자에게 보여줄 Coordination 설명:

| 옵션 | 의미 | 선택하면 달라지는 점 | 권장 상황 |
|---|---|---|---|
| `single_active_task` | 한 번에 하나의 핵심 Task만 진행한다 | 가장 단순하고 충돌 가능성이 낮지만 병렬성이 없다 | solo_light, 초기 기획, 작은 프로젝트 |
| `parallel_with_dependencies` | 선행/후행 관계가 명확한 Task만 병렬 허용 | `depends_on`, `blocks` 기록이 중요해진다 | 여러 작업을 나누되 순서가 중요한 경우 |
| `parallel_by_ownership` | ownership이 겹치지 않으면 병렬 허용 | Team/path/domain 경계가 명확해야 한다 | 플랫폼/기능별 병렬 개발 |
| `lead_coordinated_parallel` | Lead Role이 병렬 가능 여부를 매번 판단한다 | 유연하지만 Lead의 scope 판단 부담이 커진다 | 복잡한 협업, multi-team, cross-team 변경 |
| `custom` | 프로젝트별 조율 규칙을 직접 정의한다 | 자유도가 높지만 conflict/rework 기준이 필요하다 | 기존 PM/issue/PR 프로세스가 있을 때 |

질문 시 확인할 내용:

- 코드 경로만으로 책임을 나눌 수 있는지, 기능 도메인까지 봐야 하는지 확인한다.
- 문서가 의사결정 기준이면 `document_ownership` 또는 `path_plus_domain`에 문서 ownership을 포함한다.
- 초보자나 작은 프로젝트에는 `path_plus_domain` + `single_active_task`를 기본 후보로 제안한다.
- 병렬 작업을 원하면 dependency와 ownership 기록 부담이 늘어난다고 설명한다.

## 16. Phase 9: Board Configuration

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

사용자에게 보여줄 설명:

| 옵션 | 의미 | 선택하면 달라지는 점 | 권장 상황 |
|---|---|---|---|
| `project_board_only` | `.ai_project/task_board.md` 하나로 전체 현황을 본다 | 가장 단순하다. Team별 상세 view는 만들지 않는다 | single team, 초기 프로젝트, solo_light |
| `project_plus_team_board` | 전체 board와 Team별 board를 함께 둔다 | 전체 우선순위와 Team별 실행 현황을 분리해서 본다 | multi-team, platform team, 병렬 작업 |
| `team_board_only` | Team별 board 중심으로 운영한다 | 전체 조율 문서가 약해질 수 있어 Lead coordination이 중요하다 | 독립 Team이 강하고 중앙 board가 필요 없을 때 |
| `custom_views` | Role/Team/Domain/Release별 view를 직접 구성한다 | 가장 유연하지만 운영 문서가 늘어난다 | enterprise, 여러 제품 라인, 복잡한 보고 체계 |

Board 설명 시 강조할 점:

- Board는 현황판이고, 실행 지시의 source of truth는 Task 파일이다.
- 초기에는 `project_board_only`로 시작하고, Team이 늘어나면 `project_plus_team_board`로 확장할 수 있다.
- 사용자가 "관리 복잡도를 줄이고 싶다"고 하면 `project_board_only`를 추천한다.

## 17. Phase 10: Branch / PR Configuration

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

사용자에게 보여줄 설명:

| 옵션 | 의미 | 선택하면 달라지는 점 | 권장 상황 |
|---|---|---|---|
| `feature_branch_pr` | Task마다 branch를 만들고 PR로 합친다 | 안전하고 이해하기 쉽다. Execution/Verification/Lead 역할 분리가 명확하다 | 기본 추천, 대부분의 코드 프로젝트 |
| `trunk_based_pr` | 짧은 branch 또는 작은 PR을 빠르게 main에 합친다 | 빠르지만 CI와 작은 변경 단위가 중요하다 | 숙련 팀, 강한 테스트/CI가 있는 프로젝트 |
| `gitflow` | main/develop/release/hotfix branch를 분리한다 | 릴리즈 관리가 강하지만 복잡도가 높다 | 정기 릴리즈, 운영 버전 관리가 필요한 제품 |
| `custom` | 프로젝트별 Git 규칙을 직접 정의한다 | 기존 회사/오픈소스 프로세스를 반영할 수 있다 | 이미 정해진 branch 전략이 있을 때 |

세부 결정 옵션:

| 항목 | 기본 후보 | 의미 |
|---|---|---|
| `default_branch` | `main` | 최종 기준 branch |
| `task_branch_pattern` | `task/<task-id>-<slug>` | Task와 branch 추적을 쉽게 한다 |
| `commit_owner` | `Execution Role` | 실제 변경한 실행자가 작업 단위 커밋을 만든다 |
| `commit_timing` | `after_task_unit` | 한 작업 단위가 검증 가능할 때 커밋한다 |
| `push_allowed` | `with_user_approval` | 원격 push는 사용자 승인 후 진행한다 |
| `pr_required` | `yes` | main 직접 merge를 피한다 |
| `review_required` | `Verification Role` | 독립 검증을 거친다 |
| `merge_owner` | `Lead Role` | 최종 merge 판단 책임을 분리한다 |
| `delete_branch_after_merge` | `yes` | 병합 후 branch 정리를 기본값으로 한다 |

Git 질문 시에는 저장소가 아직 없으면 전략을 `pending_decision`으로 남기고 Git 초기화를 강제하지 않는다.

## 18. Phase 11: Source of Truth Mapping

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

사용자에게 보여줄 설명:

| 영역 | 의미 | 후보 파일 예시 | 없을 때 처리 |
|---|---|---|---|
| `requirements` | 무엇을 만들지와 성공 기준 | `REQUIREMENTS.md`, `docs/product/requirements.md` | `unresolved`로 두고 Direction/Lead Task 후보 |
| `planning` | 일정, milestone, Task 분해 기준 | `ROADMAP.md`, `IMPLEMENTATION_PLAN.md` | 기획 정리 Task 후보 |
| `architecture` | 시스템 구조와 기술 결정 | `ARCHITECTURE.md`, `docs/architecture.md` | 구현 전 설계 Task 후보 |
| `design` | UX/UI/디자인 기준 | Figma, `DESIGN.md`, `docs/design/` | 필요한 경우 외부 링크 또는 pending |
| `api` | API 계약, schema, integration 기준 | `API.md`, OpenAPI spec, `docs/api/` | Backend/API 작업 전 unresolved |
| `operations` | 운영, 배포, 장애 대응 기준 | `RUNBOOK.md`, `OPERATIONS.md` | 릴리즈 전까지 pending 가능 |
| `test_strategy` | 무엇을 어떻게 검증할지 | `TESTING.md`, `QA_CHECKLIST.md` | Verification 기준을 먼저 정해야 함 |
| `release_notes` | 배포 변경 요약 | `CHANGELOG.md`, `RELEASE_NOTES.md` | Release Role 비활성이면 optional |

Source of Truth 결정 규칙:

- 존재하지 않는 문서를 사실처럼 확정하지 않는다.
- 파일이 없으면 `unresolved` 또는 `to_create_candidate`로 기록한다.
- 여러 후보가 있으면 "현재 우선 기준"과 "보조 참고"를 분리한다.
- 제품 방향 문서와 운영체계 문서를 섞지 않는다. `.ai/`는 운영 헌법이고, 프로젝트 제품 기준은 프로젝트 문서 또는 `.ai_project/source_of_truth.md`에 연결한다.

## 19. Phase 12: Decision Stack Review

AI Ops Agent는 최종 Draft를 만들기 전에 지금까지 누적된 결정값을 검토한다.

이 단계의 목적:

- 사용자가 실제로 결정한 값과 Agent가 추정한 값을 분리한다.
- 최종 Draft에 들어갈 수 있는 항목과 보류해야 할 항목을 구분한다.
- 빠진 필수 결정이 있으면 Draft를 만들기 전에 질문한다.

Review 출력:

```text
Decision Stack Review

Confirmed Decisions:
- Start Context:
- Readiness Level:
- Product Direction:
- Operating Mode:
- Team:
- Active Roles:
- Workflow:
- Ownership:
- Board:
- Branch / PR:
- Source of Truth:

Pending Decisions:
- ...

Assumptions:
- ...

Open Questions:
- ...
```

필수 결정이 부족하면 아래처럼 묻고 멈춘다.

```text
아직 최종 Operating Model Draft를 만들기에는 아래 결정이 부족합니다.

1. ...
2. ...

먼저 1번부터 정하겠습니다.
...
```

필수 결정이 충분하면 아래처럼 확인한다.

```text
필수 결정값이 충분히 모였습니다.
지금까지의 Decision Stack을 기준으로 최종 Operating Model Draft를 작성해도 될까요?
```

## 20. Phase 13: Operating Model Draft

파일을 쓰기 전 사용자에게 아래 초안을 보여준다. 이 Draft에는 `Decision Stack`에서 확정된 값만 확정값으로 작성한다. 추정값은 `assumptions`, 미결정값은 `pending_decision` 또는 `unresolved`로 남긴다.

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

## 21. Phase 14: Approval Gate

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

## 22. Phase 15: Apply

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

## 23. Phase 16: Post-Apply Validation

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

## 24. Phase 17: Next Action Proposal

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

## 25. Start Context별 실행 차이

### 25.1 `new_project_with_requirement`

- readiness level을 반드시 확인한다.
- `idea_only`에서는 Execution Role을 즉시 활성화하지 않는다.
- `implementation_ready`에서는 `team_pr` 또는 `team_basic`을 우선 검토한다.

### 25.2 `assigned_or_existing_project`

- Project Scan을 충분히 수행한다.
- 기존 문서와 실제 코드가 충돌하면 source of truth를 바로 확정하지 않는다.
- 첫 작업은 보통 운영 마이그레이션 또는 현황 정리 Task다.

### 25.3 `blank_slate_discovery`

- 제품 Task를 만들지 않는다.
- Direction Role 중심으로 문제 정의와 탐색 질문을 구성한다.
- source of truth는 discovery 결과 이후 확정한다.

### 25.4 `rescue_or_recovery`

- 빌드, 테스트, CI, 최근 변경 이력을 우선 확인한다.
- Verification Role을 초기에 활성화한다.
- feature 개발보다 복구 Task를 먼저 제안한다.

### 25.5 `migration_or_modernization`

- migration scope와 rollback 기준을 먼저 정한다.
- 기존 운영 문서 삭제나 대체는 별도 승인으로 처리한다.
- ownership과 coordination 정책을 초기에 확정한다.

### 25.6 `ops_setup_only`

- 제품 코드 변경을 하지 않는다.
- `.ai_project/` 운영 문서 생성에 집중한다.
- 첫 제품 Task를 만들지 않는다.

### 25.7 `scale_up_existing_ops`

- Team 분리 기준과 ownership 충돌 가능성을 먼저 확인한다.
- project board와 team board의 관계를 정한다.
- coordination policy를 명시적으로 선택한다.

## 26. 질문 팩

질문 팩은 한 번에 모두 출력하지 않는다. 현재 단계에 필요한 질문만 제시하고, 사용자 답변을 받은 뒤 Decision Stack을 갱신한다.

질문 형식:

```text
현재 결정할 항목:
추천:
이유:
선택지:
각 선택지의 차이:
나중에 바꿀 수 있는지:
내 질문:
```

답변을 받은 뒤:

```text
Decision Stack 업데이트:
- confirmed:
- pending:

다음으로 정할 항목:
```

### 26.1 Start Context

```text
이 프로젝트의 시작 유형은 무엇인가요?
- new_project_with_requirement: 요구사항이나 아이디어가 있는 신규 프로젝트/사업입니다. Readiness를 함께 확인합니다.
- assigned_or_existing_project: 기존 프로젝트나 업무를 맡은 상황입니다. 기존 코드/문서/source of truth 스캔이 먼저입니다.
- blank_slate_discovery: 무엇을 할지부터 찾아야 합니다. 제품 Task 없이 문제 정의와 탐색 질문부터 시작합니다.
- rescue_or_recovery: 빌드 실패, 품질 문제, 중단된 프로젝트를 복구합니다. 기능 개발보다 안정화가 우선입니다.
- migration_or_modernization: 기존 시스템/문서/운영을 새 구조로 옮깁니다. 전환 계획과 ownership이 중요합니다.
- ops_setup_only: 제품 개발 없이 AI 운영체계만 도입합니다. `.ai_project/` 운영 문서 구성에 집중합니다.
- scale_up_existing_ops: 이미 돌아가는 운영을 조직/Team 기반으로 확장합니다. Team, board, coordination을 먼저 정합니다.
- custom_start_context: 위 분류로 설명되지 않는 특수한 출발점입니다.

가장 가까운 유형을 하나 고르거나, 섞여 있다면 어떤 점이 섞여 있는지 말해주세요.
```

### 26.2 Readiness

```text
현재 요구사항 수준은 어디에 가깝나요?
- idea_only: 아이디어만 있고 문제/사용자/범위가 아직 불명확합니다. 구현 Role은 기본 비활성입니다.
- idea_structured: 목적과 핵심 기능은 대략 있습니다. 기획 정리와 MVP 범위 확정이 먼저입니다.
- planning_ready: 기획은 있으나 구현 계획, milestone, Task 분해가 필요합니다.
- implementation_ready: 요구사항과 성공 기준이 명확해서 첫 구현 Task를 만들 수 있습니다.

낮은 단계를 고르는 것은 실패가 아니라 안전한 시작점입니다. 지금 상태에 가장 가까운 값을 골라주세요.
```

### 26.3 Operating / Team

```text
추천 운영 모드는 `<mode>`입니다.
이유는 `<reason>`입니다.

비교할 선택지는 아래입니다.
- solo_light: 한 사람이 여러 Role을 겸하는 최소 운영입니다. 빠르게 시작하지만 협업/PR/검증 분리는 약합니다.
- team_basic: Lead / Execution / Verification을 분리합니다. 구현과 검증을 나누고 싶을 때 적합합니다.
- team_pr: team_basic에 task branch, PR, merge 판단을 추가합니다. 코드 프로젝트와 협업에 적합합니다.
- multi_team: 플랫폼/기능/모듈별 Team ownership을 둡니다. 병렬 작업과 충돌 조율이 필요할 때 적합합니다.

Team 구성은 현재 `<team_recommendation>`을 추천합니다.
- single_team: project board 하나와 공통 운영 규칙으로 시작합니다.
- platform_team: iOS/Web/Backend처럼 플랫폼별 path, build, test 기준을 분리합니다.
- feature_team: Auth/Search처럼 기능 도메인 ownership을 기준으로 나눕니다.
- custom_team: Team 이름과 책임을 직접 정하되 Role, allowed paths, source of truth는 반드시 정합니다.

이 모드로 진행할까요, 아니면 다른 구성을 선택할까요?
```

### 26.4 Role / Workflow

```text
초기 활성 Role은 Lead / Execution / Verification / Ops Governance로 제안합니다.
Release Role은 현재 비활성으로 두는 구성이 적절해 보입니다.

각 Role의 의미는 아래입니다.
- Direction Role: 무엇을 왜 할지, 우선순위와 승인 기준을 정합니다.
- Lead Role: Task를 등록하고 scope, ownership, dependency, merge 판단을 조율합니다.
- Execution Role: 승인된 범위 안에서 실제 구현/문서/조사 작업을 수행하고 보고합니다.
- Verification Role: 실행 결과를 독립적으로 검증하고 PASS/rework/blocked를 판단합니다.
- Completion Role: 검증 이후 완료로 닫아도 되는지 확인합니다. 작은 팀에서는 Lead가 겸할 수 있습니다.
- Release Role: 실제 배포, rollback, 운영 인계가 있을 때만 활성화합니다.
- Ops Governance Role: 운영모델, Role 경계, workflow 문제가 없는지 점검합니다.

Workflow 후보는 아래입니다.
- standard_vnext: proposed -> scoped -> approved -> in_progress -> verification_ready -> verification_in_progress -> verification_passed -> completion_review -> done
- skip_scoped_for_simple_tasks: 단순 작업은 scoped를 생략할 수 있지만, ownership이 애매하면 표준 흐름을 사용합니다.
- require_scoped_for_all_tasks: 모든 작업에 scope/ownership/allowed_paths 정리를 강제합니다.
- custom: 기존 프로젝트 프로세스에 맞춰 상태 전이를 직접 정의합니다.

현재 Role과 Workflow 구성으로 진행할까요, 아니면 특정 Role/단계를 켜거나 끄고 싶나요?
```

### 26.5 Ownership / Coordination

```text
Ownership은 "누가 무엇을 책임지는가"이고, Coordination은 "어떤 순서와 조건으로 같이 일하는가"입니다.

Ownership 선택지는 아래입니다.
- path_only: 파일/디렉토리 기준입니다. 단순하지만 기능 도메인 영향은 놓칠 수 있습니다.
- path_plus_domain: path에 Auth/Search 같은 기능 도메인을 더합니다. 대부분의 앱/서비스 기본값으로 적합합니다.
- document_ownership: 요구사항, 아키텍처, API 문서 같은 source of truth 책임을 명시합니다.
- strict_parallel_control: 충돌 가능성이 있으면 병렬을 강하게 제한합니다. 안전하지만 느립니다.
- custom: 기존 owner/CODEOWNERS/조직 규칙을 따릅니다.

Coordination 선택지는 아래입니다.
- single_active_task: 한 번에 하나의 핵심 Task만 진행합니다. 가장 단순하고 안전합니다.
- parallel_with_dependencies: depends_on/blocks가 명확한 Task만 병렬 허용합니다.
- parallel_by_ownership: ownership이 겹치지 않으면 병렬 허용합니다.
- lead_coordinated_parallel: Lead Role이 병렬 가능 여부를 매번 판단합니다.
- custom: 기존 PM/issue/PR 프로세스를 따릅니다.

추천은 초기 프로젝트라면 path_plus_domain + single_active_task입니다.
병렬 작업을 바로 허용할까요, 아니면 먼저 단일 작업 흐름으로 시작할까요?
```

### 26.6 Board / Source of Truth

```text
Board는 현황판이고, Task 파일이 실행 지시의 기준입니다.

Board 선택지는 아래입니다.
- project_board_only: `.ai_project/task_board.md` 하나로 봅니다. 초기/단일 Team 기본값입니다.
- project_plus_team_board: 전체 board와 Team별 board를 함께 둡니다. multi-team에 적합합니다.
- team_board_only: Team별 board 중심입니다. 중앙 조율이 약해질 수 있습니다.
- custom_views: Role/Team/Domain/Release별 view를 직접 구성합니다.

Source of Truth는 "Agent가 무엇을 기준으로 판단해야 하는가"입니다.
- requirements: 요구사항과 성공 기준
- planning: milestone, 구현 계획, Task 분해
- architecture: 시스템 구조와 기술 결정
- design: UX/UI/디자인 기준
- api: API 계약과 schema
- operations: 운영/배포/장애 대응
- test_strategy: 테스트와 QA 기준
- release_notes: 배포 변경 요약

없는 문서는 임의로 만들지 않고 unresolved 또는 생성 후보로 남깁니다.
Board는 project_board_only로 시작하고, source of truth는 발견된 문서만 연결해도 될까요?
```

### 26.7 Git

```text
Git 전략은 feature branch + PR 기반을 기본값으로 제안합니다.
Execution Role은 task branch에서 커밋하고, Verification Role이 검증한 뒤 Lead Role이 merge 여부를 확인하는 흐름입니다.

선택지는 아래입니다.
- feature_branch_pr: Task마다 branch를 만들고 PR로 합칩니다. 가장 단순하고 안전한 기본값입니다.
- trunk_based_pr: 작은 PR을 빠르게 main에 합칩니다. 강한 CI와 작은 변경 단위가 필요합니다.
- gitflow: main/develop/release/hotfix를 나눕니다. 릴리즈 운영에는 강하지만 복잡합니다.
- custom: 이미 정해진 회사/팀 규칙을 따릅니다.

세부 기본값은 아래처럼 제안합니다.
- default_branch: main
- task_branch_pattern: task/<task-id>-<slug>
- commit_owner: Execution Role
- push_allowed: with_user_approval
- pr_required: yes
- review_required: Verification Role
- merge_owner: Lead Role

이 전략을 프로젝트 기본값으로 기록할까요, 아니면 저장소/Git 초기화 여부를 먼저 보류할까요?
```

### 26.8 Decision Stack Review

```text
지금까지의 Decision Stack을 검토하겠습니다.

확정된 항목:
- ...

보류된 항목:
- ...

가정:
- ...

이 상태로 최종 Operating Model Draft를 작성해도 될까요?
아니면 먼저 보류 항목 중 하나를 더 결정할까요?
```

### 26.9 Apply Approval

```text
아래 파일만 생성/수정하는 Apply Phase를 진행해도 될까요?
```

## 27. 금지사항

- Discovery Phase에서 파일을 수정하지 않는다.
- Project Scan 직후 전체 Operating Model Draft를 한 번에 제안하지 않는다.
- Decision Stack Review 없이 Apply 승인을 묻지 않는다.
- 승인 없이 `.ai_project/`를 생성하지 않는다.
- 승인 없이 기존 프로젝트 문서를 삭제하거나 이동하지 않는다.
- 운영 구성이 확정되기 전 제품 Task를 생성하지 않는다.
- 기본 branch에 직접 push하지 않는다.
- 사용자가 선택하지 않은 Git flow를 강제하지 않는다.
- Release Role이 필요하지 않은 프로젝트에 release workflow를 활성화하지 않는다.
- source of truth가 불명확한 문서를 최종 기준으로 단정하지 않는다.

## 28. 완료 기준

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
- Decision Stack Review를 거쳐 확정값, 보류값, 가정이 분리되어 있다.
- `.ai_project/operating_model.md`가 실제 프로젝트 운영 구성의 인덱스 역할을 한다.
- 다음 action이 discovery, planning, implementation, recovery, ops validation 중 하나로 제안되어 있다.

## 29. 변경 이력

| 날짜 | 변경 내용 |
|---|---|
| 2026-07-10 | Start Context 기반 프로젝트 bootstrap 실행 runbook 초안 작성 |

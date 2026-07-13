# Project Bootstrap Policy

작성일: 2026-07-09  
상태: Draft vNext  
범위: 프로젝트별 AI Agent 운영체계 구성 선택 절차

## 1. 목적

이 문서는 `ai-agent-ops`를 새 프로젝트 또는 기존 프로젝트에 적용할 때 AI Ops Agent가 어떤 순서로 선택지를 제시하고, 사용자의 결정으로 실제 프로젝트 운영체계를 구성하는지 정의한다.

`.ai/`는 일반화된 운영 규칙과 선택 가능한 재료를 제공한다. 실제 프로젝트 구성은 `.ai_project/`에 기록한다.

## 2. 핵심 원칙

- `.ai/`는 특정 프로젝트의 조직/팀/브랜치 전략을 고정하지 않는다.
- `.ai_project/`가 해당 프로젝트의 실제 운영 구성을 가진다.
- AI Ops Agent는 선택지를 제시하고 장단점을 설명한다.
- 사용자가 선택한 내용만 프로젝트 운영 구성으로 확정한다.
- 선택 결과는 `.ai_project/operating_model.md`와 관련 세부 문서에 기록한다.
- 운영 구성 확정 전에는 제품 Task를 만들거나 승인하지 않는다.

## 3. 구성 산출물

프로젝트 bootstrap의 핵심 산출물은 아래 문서다.

```text
.ai_project/operating_model.md
```

이 문서는 프로젝트별 실제 선택값의 인덱스 역할을 한다.

Fast Track 세부 설정은 아래 최소 문서에 나누어 기록한다.

```text
.ai_project/agent_registry.md
.ai_project/current_context.md
.ai_project/source_of_truth.md
.ai_project/task_board.md
.ai_project/ops_decisions.md
.ai_project/ops_issues.md
```

Guided Full에서는 아래 문서를 추가로 생성할 수 있다.

```text
.ai_project/branch_pr_strategy.md
.ai_project/workflow_overrides.md
.ai_project/ops_migration_plan.md
```

템플릿 기준:

```text
fast_track: .ai/templates/ai_project/fast_track/
guided_full: .ai/templates/ai_project/guided_full/
```

Team별 구성이 필요하면 아래 구조를 추가할 수 있다.

```text
.ai_project/teams/
  ios/
    team_context.md
    task_board.md
    branch_pr_strategy.md
```

## 4. Bootstrap 단계

AI Ops Agent는 아래 순서로 프로젝트 운영체계를 구성한다.

```text
0. Start Context 선택
1. Project Scan
2. Readiness Level 판단
3. Operating Mode 선택
4. Organization / Team 구성 선택
5. Role / Agent 매핑 선택
6. Workflow / State 운영 선택
7. Ownership / Coordination 구성 선택
8. Board 구성 선택
9. Branch / PR 전략 선택
10. Source of Truth 매핑
11. 적용 범위 승인
12. .ai_project 문서 생성
```

Bootstrap은 두 단계로 나누어 진행한다.

```text
Discovery Phase
  - 파일을 읽고 후보를 만든다.
  - 사용자에게 선택지를 제시한다.
  - 파일은 수정하지 않는다.

Apply Phase
  - 사용자가 승인한 선택값만 문서화한다.
  - .ai_project/ 문서를 생성하거나 갱신한다.
```

### 4.1 Bootstrap Mode 선택

Bootstrap은 시작 후 먼저 진행 방식을 선택한다.

| Mode | 의미 | 권장 사용자 |
|---|---|---|
| `fast_track` | 쉬운 질문과 안전 기본값으로 구성 | 처음 사용하는 사용자, 비개발자, 작은 프로젝트 |
| `guided_full` | 모든 주요 설정을 단계별로 비교하며 구성 | 운영 방식을 직접 정하고 싶은 사용자 |

처음 사용하는 사용자나 비개발자는 `fast_track`을 선택할 수 있다.

Fast Track은 모든 선택지를 한 번에 비교하지 않는다. AI Ops Agent가 쉬운 질문으로 상황을 파악한 뒤 안전 기본값을 제안하고, 사용자가 원하면 고급 설정으로 전환한다.

Fast Track은 제품 아이디어 발굴 세션이 아니다. AI Ops Agent는 운영 구성에 필요한 최소 맥락만 확인하고, 실제 문제 정의, 사용자 탐색, MVP 범위 결정은 Apply 이후 PM Agent / Direction Role 첫 세션으로 넘긴다.

Fast Track 기본값:

| 항목 | 기본값 | 이유 |
|---|---|---|
| Operating Mode | `solo_light` | 가장 단순하게 시작 |
| Team | `single_team` | Team 분리 부담 제거 |
| Active Roles | Direction / Lead / Ops Governance | 기획과 운영 구성 중심 |
| Execution / Verification | 구현 준비 시 활성 | 구현 전 과도한 Role 분리 방지 |
| Workflow | `skip_scoped_for_simple_tasks` | 단순 작업은 빠르게, 복잡한 작업은 표준 흐름 사용 |
| Ownership | `path_plus_domain` | 단순 path 기준에 기능 도메인 안전장치 추가 |
| Coordination | `single_active_task` | 충돌을 줄이는 쉬운 시작 |
| Board | `project_board_only` | 한 개 현황판으로 시작 |
| Branch / PR | `pending_decision` | 코드/Git 준비 전 확정하지 않음 |
| Release Role | inactive | 실제 배포 전까지 비활성 |

Fast Track도 Discovery Phase와 Apply Phase를 분리한다. 사용자 승인 없이 `.ai_project/`를 생성하지 않는다.

## 5. Step 0: Start Context 선택

AI Ops Agent는 프로젝트 운영 구성을 고르기 전에 먼저 프로젝트의 출발점을 분류한다.

Start Context는 "어떤 조직을 만들 것인가"보다 앞선 질문이다. 같은 `team_pr` 운영이라도 아이디어 단계, 기존 업무 인수, 백지 탐색, 복구 프로젝트는 필요한 Role 활성화 순서가 다르다.

선택 후보:

| Start Context | 설명 | 초기 활성 중심 |
|---|---|---|
| `new_project_with_requirement` | 요구사항이 있는 신규 프로젝트/사업 시작 | Direction -> Lead -> Execution/Verification |
| `assigned_or_existing_project` | 기존 프로젝트, 회사 업무, 과업, 인수인계 | Ops Governance scan -> Lead -> Execution/Verification |
| `blank_slate_discovery` | 뭘 할지부터 정하는 백지 탐색 | Direction Role 첫 세션 후보 |
| `rescue_or_recovery` | 중단, 실패, 빌드 불가, 품질 문제 프로젝트 복구 | Ops Governance + Lead + Verification |
| `migration_or_modernization` | 기존 시스템/문서/운영을 새 구조로 이전 | Ops Governance + Lead |
| `ops_setup_only` | 제품 개발 없이 AI 운영체계만 도입 | Ops Governance 중심 |
| `scale_up_existing_ops` | 이미 돌아가는 프로젝트를 multi-team/division으로 확장 | Lead + Ownership/Coordination |
| `custom_start_context` | 위 분류로 설명되지 않는 출발점 | 사용자 정의 |

`new_project_with_requirement`는 아래 readiness level을 함께 기록한다.

| Readiness Level | 의미 | 우선 구성 |
|---|---|---|
| `idea_only` | 아이디어만 있음 | Direction Role 중심, 구현 비활성 |
| `idea_structured` | 아이디어는 정리됨, 기획 필요 | Direction + Lead |
| `planning_ready` | 기획은 있음, 구현 계획 필요 | Direction + Lead + Verification 관점 |
| `implementation_ready` | 구현 요구사항이 명확함 | Lead + Execution + Verification |

질문 형식:

```text
이 프로젝트의 시작 유형을 선택해주세요.

1. 요구사항이 있는 신규 프로젝트/사업 시작
2. 기존 프로젝트/업무/과업을 맡은 경우
3. 백지에서 문제와 아이디어부터 찾는 경우
4. 중단/문제 프로젝트 복구
5. 기존 프로젝트 마이그레이션/현대화
6. AI 운영체계만 도입
7. 기존 운영을 조직형으로 확장
8. custom

요구사항이 있는 신규 프로젝트라면 현재 수준도 선택해주세요.
- idea_only
- idea_structured
- planning_ready
- implementation_ready
```

선택 결과는 `.ai_project/operating_model.md`에 기록한다.

## 6. Step 1: Project Scan

AI Ops Agent가 먼저 확인할 항목:

- Start Context
- Readiness Level
- 프로젝트 유형
- 사용 언어 / 플랫폼
- 저장소 구조
- 기존 문서
- 기존 `AGENTS.md` 또는 운영 지침
- Git 기본 branch
- CI 존재 여부
- 테스트/빌드 명령 존재 여부
- 현재 운영 중인 Task 또는 이슈 관리 방식

AI Ops Agent는 이 단계에서 파일을 수정하지 않는다.

Project Scan 결과는 아래 형식으로 사용자에게 요약한다.

```text
프로젝트 유형:
Start Context:
Readiness Level:
주요 플랫폼/언어:
발견한 코드 경로:
발견한 문서:
발견한 테스트/빌드 명령:
현재 Git 기본 branch:
CI 존재 여부:
추천 operating mode:
주의할 ownership 후보:
```

## 7. Step 2: Readiness Level 판단

AI Ops Agent는 Start Context와 Project Scan 결과를 바탕으로 실제 운영 준비 수준을 판단한다.

판단 항목:

- 요구사항이 Task로 나눌 만큼 명확한가?
- 제품/사업 방향 결정이 먼저 필요한가?
- 기존 코드와 문서의 source of truth가 있는가?
- 바로 구현할 수 있는가, 먼저 정리/복구/기획이 필요한가?
- Execution Role을 즉시 활성화해도 되는가?
- Verification Role이 무엇을 검증해야 하는가?

Readiness 결과는 Operating Mode 추천 근거로 사용한다.

```text
readiness_summary:
recommended_next_phase:
execution_ready: yes / no
verification_ready: yes / no
required_decisions:
```

## 8. Step 3: Operating Mode 선택

사용자에게 아래 선택지를 제시한다.

| 모드 | 설명 | 권장 상황 |
|---|---|---|
| `solo_light` | 1인 + AI Agent 최소 운영 | 작은 프로젝트, 빠른 실험 |
| `team_basic` | Lead / Execution / Verification 3 Role 운영 | 초기 조직형 운영 기본값 |
| `team_pr` | `team_basic` + branch/PR/merge 정책 | Git PR 기반 개발 |
| `multi_team` | 여러 Team, ownership, team board 운영 | iOS/Android/Web/Backend 등 병렬 |
| `enterprise` | Division 분리, QA/Release/Business 확장 | 큰 조직 또는 장기 운영 |

초기 권장값:

```text
team_pr
```

릴리즈가 없고 PR 기반 개발만 필요한 경우 `team_pr`가 가장 단순하고 안전하다.

질문 형식:

```text
운영 모드를 선택해주세요.

추천: team_pr
이유: Lead / Execution / Verification 3 Role을 유지하면서, task branch와 PR 기반 검증을 사용할 수 있습니다.

선택지:
1. solo_light
2. team_basic
3. team_pr
4. multi_team
5. enterprise
6. custom
```

## 9. Step 4: Organization / Team 구성 선택

Team 구성 후보와 최소 계약은 `.ai/models/team_model.md`를 따른다.

선택 가능한 기본 구성:

### 7.1 Minimal

```text
AI Agent Ops Organization
  Development Division
  AI Ops Division
```

### 7.2 Single Platform Team

```text
Development Division
  iOS Team
AI Ops Division
```

### 7.3 Multi Platform Team

```text
Development Division
  iOS Team
  Android Team
  Web Team
  Backend Team
AI Ops Division
```

### 7.4 Custom

사용자가 직접 Team 이름과 책임을 정한다.

예:

```text
Mobile Team
API Team
Admin Web Team
AI Ops Division
```

선택 결과는 `.ai_project/operating_model.md`에 기록한다.

질문 형식:

```text
이번 프로젝트의 활성 Team 구성을 선택해주세요.

추천:
Development Division
  iOS Team 또는 Product Team
AI Ops Division

선택지:
1. single_team
2. platform_team
3. feature_team
4. module_team
5. custom_team

추가로 정해야 할 값:
- Team 이름
- Team Lead 이름
- 기본 allowed_paths
- 기본 source_of_truth
```

## 10. Step 5: Role / Agent 매핑 선택

선택 가능한 기본 매핑:

### 8.1 Minimal 3 Role

```text
Lead Role
Execution Role
Verification Role
```

### 8.2 Bootstrap Agent Mapping

```text
PM Agent           -> Lead Role + Direction Role + Completion Role
Development Agent  -> Execution Role
QA Agent           -> Verification Role
AI Ops Agent       -> Ops Governance Role
```

### 8.3 Custom Agent Names

사용자가 Agent 이름을 직접 정한다.

예:

```text
iOS Lead      -> Lead Role
iOS Builder   -> Execution Role
iOS Reviewer  -> Verification Role
Ops Auditor   -> Ops Governance Role
```

원칙:

- Agent 이름은 자유롭게 정할 수 있다.
- 반드시 `target_role`과 capability 매핑이 있어야 한다.
- Role 책임과 상태 전이는 `.ai/models/role_model.md`와 `.ai/runtime/task_queue.md`를 따른다.

질문 형식:

```text
Role / Agent 매핑을 선택해주세요.

추천:
Lead Role         -> PM Agent 또는 Team Lead
Execution Role    -> Development Agent
Verification Role -> QA Agent
Ops Governance    -> AI Ops Agent

선택지:
1. bootstrap 기본 Agent 이름 사용
2. Team별 Agent 이름 사용
3. 사용자 지정 Agent 이름 사용

Release Role은 실제 배포가 생길 때까지 비활성으로 둘까요?
```

## 11. Step 6: Workflow / State 운영 선택

기본 상태 체계:

```text
proposed
  -> scoped
  -> approved
  -> in_progress
  -> verification_ready
  -> verification_in_progress
  -> verification_passed
  -> completion_review
  -> done
```

선택 옵션:

| 옵션 | 설명 |
|---|---|
| `standard_vnext` | 기본 vNext 상태 체계 |
| `skip_scoped_for_simple_tasks` | 단순 Task는 `proposed -> approved` 직접 허용 |
| `require_scoped_for_all_tasks` | 모든 Task에 `scoped` 필수 |
| `custom_workflow_overrides` | `.ai_project/workflow_overrides.md`에 예외 기록 |

초기 권장값:

```text
standard_vnext
```

PR 기반 팀 운영이면 `require_scoped_for_all_tasks`도 고려한다.

질문 형식:

```text
Workflow / State 운영 방식을 선택해주세요.

추천: standard_vnext
PR 기반 병렬 작업이 많으면: require_scoped_for_all_tasks

선택지:
1. standard_vnext
2. skip_scoped_for_simple_tasks
3. require_scoped_for_all_tasks
4. custom_workflow_overrides
```

## 12. Step 7: Ownership / Coordination 구성 선택

선택 옵션:

| 옵션 | 설명 |
|---|---|
| `path_only` | path ownership만 사용 |
| `path_plus_domain` | path + domain ownership 사용 |
| `document_ownership` | source of truth 문서 ownership도 관리 |
| `strict_parallel_control` | 병렬 작업은 Lead Role 명시 승인 필요 |

초기 권장값:

```text
path_only
document_ownership
strict_parallel_control
```

Team이 하나뿐이어도 ownership은 path 기준으로 시작하는 것이 안전하다.

질문 형식:

```text
Ownership / Coordination 기준을 선택해주세요.

추천:
- path_only
- document_ownership
- strict_parallel_control

선택지:
1. path_only
2. path_plus_domain
3. document_ownership
4. strict_parallel_control
5. custom
```

## 13. Step 8: Board 구성 선택

선택 옵션:

| 옵션 | 설명 |
|---|---|
| `project_board_only` | `.ai_project/task_board.md`만 사용 |
| `project_plus_team_board` | project board + team board 사용 |
| `custom_views` | 프로젝트가 별도 view를 정의 |

초기 권장값:

```text
project_board_only
```

Team이 여러 개이거나 Team별 active Task가 많아지면 `project_plus_team_board`로 확장한다.

질문 형식:

```text
Board 구성을 선택해주세요.

추천: project_board_only

선택지:
1. project_board_only
2. project_plus_team_board
3. custom_views
```

## 14. Step 9: Branch / PR 전략 선택

선택 옵션은 `.ai/policies/branch_pr_policy.md`를 따른다.

기본 후보:

```text
feature_branch_pr
trunk_based_pr
gitflow
```

초기 권장값:

```text
feature_branch_pr
```

릴리즈 Role이 비활성 상태라면 `gitflow`는 기본 권장하지 않는다.

선택 결과는 아래에 기록한다.

```text
.ai_project/branch_pr_strategy.md
```

질문 형식:

```text
Branch / PR 전략을 선택해주세요.

추천: feature_branch_pr
이유: task branch에서 작업하고 PR 검증 후 Lead Role이 merge하는 가장 단순하고 안전한 모델입니다.

선택지:
1. feature_branch_pr
2. trunk_based_pr
3. gitflow
4. custom

추가로 정해야 할 값:
- Execution Role이 task branch commit을 할 수 있는가
- Execution Role이 push를 할 수 있는가
- PR 생성 주체
- PR review 주체
- merge owner
```

## 15. Step 10: Source of Truth 매핑

AI Ops Agent는 프로젝트 문서를 분석해 source of truth 후보를 제시한다.

선택 항목:

- 현재 상태 문서
- 구현 계획 문서
- 아키텍처 문서
- API 계약 문서
- 테스트/QA 문서
- 변경 이력
- 결정 기록

결과는 아래에 기록한다.

```text
.ai_project/source_of_truth.md
```

질문 형식:

```text
프로젝트의 source of truth 문서를 선택해주세요.

확인할 영역:
- 현재 상태
- 구현 계획
- 아키텍처
- 결정 기록
- QA 기준
- 변경 이력

문서가 없으면 새로 만들까요, 아니면 현재는 미정으로 둘까요?
```

## 16. Step 11: 적용 범위 승인

AI Ops Agent는 문서 생성 전 아래를 사용자에게 제시한다.

```text
생성할 파일:
수정할 파일:
선택한 Start Context:
선택한 Readiness Level:
선택한 운영 모드:
선택한 Team 구조:
선택한 Role 매핑:
선택한 branch/PR 전략:
source of truth 매핑:
로컬 전용 여부:
```

사용자 승인 전에는 파일을 생성하거나 수정하지 않는다.

AI Ops Agent는 승인 요청 전 선택 결과를 아래 형식으로 정리한다.

```text
Operating Model Draft

operating_mode:
start_context:
readiness_level:
organization:
active_teams:
role_agent_mapping:
workflow_state_policy:
ownership_policy:
board_policy:
branch_pr_policy:
source_of_truth:
files_to_create:
files_to_update:
open_questions:
```

## 17. Step 12: 문서 생성

승인 후 AI Ops Agent는 선택 결과에 맞춰 `.ai_project/` 문서를 생성한다.

기본 생성 대상:

```text
.ai_project/README.md
.ai_project/operating_model.md
.ai_project/agent_registry.md
.ai_project/current_context.md
.ai_project/source_of_truth.md
.ai_project/task_board.md
.ai_project/branch_pr_strategy.md
.ai_project/ops_decisions.md
.ai_project/ops_issues.md
.ai_project/ops_migration_plan.md
.ai_project/workflow_overrides.md
.ai_project/tasks/
.ai_project/reports/
.ai_project/qa/
```

## 18. AI Ops Agent 질문 세트

프로젝트 bootstrap 시 AI Ops Agent는 아래 질문을 순서대로 제시한다.

```text
1. 이 프로젝트의 시작 유형은 무엇인가요?
2. 현재 readiness level은 어디인가요?
3. 운영 모드는 무엇으로 시작할까요?
4. 활성 Team은 무엇인가요?
5. Role/Agent 이름은 기본값을 쓸까요, 커스텀할까요?
6. 모든 Task에 scoped 단계를 필수로 둘까요?
7. ownership은 path만 쓸까요, domain도 쓸까요?
8. board는 project board만 쓸까요, team board도 만들까요?
9. Git 전략은 feature_branch_pr / trunk_based_pr / gitflow 중 무엇인가요?
10. Execution Role이 task branch에 commit/push할 수 있나요?
11. merge owner는 Lead Role인가요, 사용자인가요?
12. source of truth 문서는 무엇인가요?
```

질문은 한 번에 모두 던지기보다, 프로젝트 복잡도에 따라 묶어서 제시한다.

권장 질문 묶음:

| 묶음 | 포함 질문 | 목적 |
|---|---|---|
| 0차 | start context, readiness level | 프로젝트 출발점 결정 |
| 1차 | operating mode, Team 구성 | 운영 규모 결정 |
| 2차 | Role/Agent 매핑, workflow/state | 실행 흐름 결정 |
| 3차 | ownership, board, source of truth | 조율 기준 결정 |
| 4차 | branch/PR, commit/push/merge 권한 | Git 운영 결정 |
| 5차 | 생성/수정 파일 승인 | 적용 범위 확정 |

각 묶음이 끝날 때 AI Ops Agent는 현재 선택값과 남은 미결정을 요약한다.

## 19. 선택값 기록 규칙

선택값은 아래 우선순위로 기록한다.

| 선택 영역 | 기록 위치 |
|---|---|
| Start Context / Readiness Level | `.ai_project/operating_model.md` |
| 전체 운영 모드 | `.ai_project/operating_model.md` |
| 조직 / Team 구성 | `.ai_project/operating_model.md` |
| Agent / Role 매핑 | `.ai_project/agent_registry.md` |
| source of truth | `.ai_project/source_of_truth.md` |
| Board 전략 | `.ai_project/task_board.md` |
| Branch / PR 전략 | `.ai_project/branch_pr_strategy.md` |
| 예외 workflow | `.ai_project/workflow_overrides.md` |
| 결정 근거 | `.ai_project/ops_decisions.md` |
| 미결정/이슈 | `.ai_project/ops_issues.md` |

`.ai_project/operating_model.md`는 실제 프로젝트 운영 구성의 인덱스다. 세부 설정과 충돌하면 세부 문서를 확인하되, 선택값의 존재 여부는 `operating_model.md`를 우선한다.

## 20. Bootstrap 완료 기준

Bootstrap은 아래 조건을 모두 만족하면 완료로 본다.

- `.ai_project/operating_model.md`에 start context와 readiness level이 기록되어 있다.
- `.ai_project/operating_model.md`에 operating mode가 기록되어 있다.
- 하나 이상의 active Team이 기록되어 있다.
- active Team에 Lead / Execution / Verification 책임이 연결되어 있다.
- source of truth 기준이 기록되어 있다.
- branch/PR 전략 또는 Git 비사용 정책이 기록되어 있다.
- Task를 만들기 위한 기본 board와 task directory가 준비되어 있다.
- 미결정 사항은 `ops_issues.md` 또는 `operating_model.md`의 open questions에 기록되어 있다.

## 21. 금지사항

- `.ai/` 일반 정책을 프로젝트별 설정으로 직접 수정하지 않는다.
- 사용자가 선택하지 않은 Team이나 Role을 활성 구성으로 기록하지 않는다.
- 프로젝트별 선택값을 `.ai/`에 저장하지 않는다.
- 운영 구성 확정 전 제품 Task를 생성하지 않는다.
- branch/PR 전략 없이 commit/push 권한을 부여하지 않는다.
- source of truth 없이 실행 Task를 승인하지 않는다.

## 22. 변경 이력

| 날짜 | 변경 내용 |
|---|---|
| 2026-07-09 | 프로젝트별 운영체계 bootstrap 선택 정책 초안 작성 |
| 2026-07-09 | 단계별 질문 형식, 선택값 기록 규칙, 완료 기준 추가 |
| 2026-07-10 | Start Context와 Readiness Level 분류 단계 추가 |

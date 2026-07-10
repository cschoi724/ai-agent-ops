# Branch and PR Policy

작성일: 2026-07-09  
상태: Draft vNext  
범위: 조직형 AI Agent 운영체계의 Git branch / commit / PR / merge 일반 정책

## 1. 목적

이 문서는 `ai-agent-ops` vNext에서 Git branch, commit, push, PR, merge를 다루는 일반 정책을 정의한다.

이 문서는 특정 프로젝트의 Git 전략을 고정하지 않는다. `.ai/`는 선택 가능한 안전한 기본 모델과 설정 후보를 제공하고, 실제 프로젝트는 `.ai_project/`에서 팀 구성과 함께 전략을 선택한다.

## 2. 기본 원칙

- `.ai/`는 재사용 가능한 일반 정책과 선택지를 제공한다.
- 실제 branch/PR 전략은 프로젝트별 `.ai_project/`에 기록한다.
- main/master/default branch에서 직접 작업하지 않는다.
- Task 단위 branch를 기본으로 한다.
- PR은 검증과 merge 판단의 기본 단위다.
- commit, push, PR 생성, merge 권한은 Role별로 분리한다.
- merge는 기본적으로 Lead Role 또는 프로젝트가 지정한 merge owner만 수행한다.
- Task 파일이 branch/PR 상태의 source of truth다.

## 3. 추천 기본 전략

가장 단순하고 안전한 기본값은 `feature_branch_pr` 전략이다.

```yaml
branch_strategy:
  model: feature_branch_pr
  base_branch: main
  branch_naming: "{type}/{task_id}-{slug}"
  commit_policy: execution_role_can_commit_task_branch
  push_policy: execution_role_can_push_task_branch
  pr_required: true
  pr_creator: Execution Role
  pr_reviewer: Verification Role
  merge_owner: Lead Role
  merge_method: squash
  ci_required: true
  delete_branch_after_merge: true
```

이 전략의 의미:

- Lead Role이 Task scope와 branch 전략을 정한다.
- Execution Role이 task branch에서 구현하고 커밋한다.
- Execution Role이 task branch를 push하고 PR을 생성할 수 있다.
- Verification Role이 PR diff, 테스트, 리스크를 검증한다.
- Lead Role이 최종 merge와 Task 완료 처리를 담당한다.
- default branch 직접 push는 금지한다.

## 4. 선택 가능한 전략

### 4.1 Feature Branch PR

대부분의 초기 프로젝트에 권장한다.

```yaml
model: feature_branch_pr
base_branch: main
pr_required: true
merge_owner: Lead Role
```

적합한 경우:

- Task 단위로 작업을 나누고 싶다.
- PR 검증 후 merge하고 싶다.
- release branch는 아직 필요 없다.
- iOS Team 같은 단일 Team 파일럿을 운영한다.

### 4.2 Trunk Based With PR

짧은 branch와 빠른 PR을 선호할 때 사용한다.

```yaml
model: trunk_based_pr
base_branch: main
short_lived_branches: true
pr_required: true
merge_owner: Lead Role
```

적합한 경우:

- Task가 작고 빠르다.
- branch 수명을 짧게 유지할 수 있다.
- CI가 안정적이다.

### 4.3 GitFlow

릴리즈 브랜치, 핫픽스 브랜치가 필요한 프로젝트에서만 사용한다.

```yaml
model: gitflow
base_branch: develop
feature_branch: feature/*
release_branch: release/*
hotfix_branch: hotfix/*
merge_owner: Lead Role
release_owner: Release Role
```

초기 vNext 운영에서는 권장하지 않는다. Release Role이 활성화되고 배포 주기가 반복될 때 선택한다.

## 5. Role별 권한

| 작업 | Direction Role | Lead Role | Execution Role | Verification Role | Ops Governance Role |
|---|---:|---:|---:|---:|---:|
| branch 전략 선택 | 제안 | 승인/조율 | 제안 가능 | 제안 가능 | 운영 관점 제안 |
| task branch 생성 | 가능 | 가능 | 가능 | 금지 | 금지 |
| 작업 branch commit | 금지 | 제한적 가능 | 가능 | 금지 | 금지 |
| 작업 branch push | 금지 | 가능 | 프로젝트 설정에 따라 가능 | 금지 | 금지 |
| PR 생성 | 금지 | 가능 | 가능 | 금지 | 금지 |
| PR review | 가능 | 가능 | 자기 PR은 금지 | 가능 | 운영 변경 PR만 가능 |
| CI 확인 | 가능 | 가능 | 가능 | 가능 | 가능 |
| merge | 금지 | 가능 | 금지 | 금지 | 운영 Task에 한해 설정 시 가능 |
| default branch 직접 push | 금지 | 금지 | 금지 | 금지 | 금지 |

기본값:

```text
commit = Execution Role
push = Execution Role on task branch
PR creation = Execution Role
PR review = Verification Role
merge = Lead Role
done = Lead Role or Completion Role
```

## 6. Task 상태와 Git 흐름

Git 흐름은 vNext Task 상태 위에 얹는다.

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

권장 매핑:

| Task 상태 | Git/PR 상태 | 담당 Role |
|---|---|---|
| `scoped` | branch 전략과 branch 이름 결정 | Lead Role |
| `approved` | branch 생성 준비 | Execution Role |
| `in_progress` | branch 작업, commit, local verification | Execution Role |
| `verification_ready` | PR opened, review requested | Execution Role |
| `verification_in_progress` | PR review, CI/test 확인 | Verification Role |
| `verification_passed` | PR approved, CI passed | Verification Role |
| `completion_review` | merge 전 최종 확인 | Lead Role |
| `done` | merged, Task 완료 | Lead Role / Completion Role |

## 7. Task Metadata

Branch/PR 정보는 Task metadata 또는 Task 본문에 기록한다.

권장 metadata:

```yaml
branch:
  strategy: feature_branch_pr
  base: main
  name: feature/T-YYYYMMDD-001-task-slug
  owner: {{EXECUTION_AGENT}}

pr:
  url:
  status: not_opened
  review_status:
  ci_status:
  merge_target: main
  merge_method: squash
  merge_owner: {{TEAM_LEAD}}
```

상태값 후보:

```yaml
pr.status: not_opened | opened | closed | merged
pr.review_status: not_requested | requested | changes_requested | approved
pr.ci_status: not_required | pending | passed | failed
```

초기 Task 템플릿에 위 필드가 없어도 된다. Git/PR 전략을 사용하는 프로젝트는 `.ai_project/`의 Task 템플릿 override 또는 Task 본문에 기록한다.

## 8. Branch Naming

기본 branch naming:

```text
{type}/{task_id}-{slug}
```

예시:

```text
feature/T-20260709-001-ios-auth-error
bugfix/T-20260709-002-login-crash
docs/T-20260709-003-update-agent-guide
ops/T-20260709-004-workflow-model
```

규칙:

- Task ID를 포함한다.
- 공백은 사용하지 않는다.
- 소문자와 hyphen을 권장한다.
- default branch 이름과 혼동되는 이름을 쓰지 않는다.
- 여러 Task를 한 branch에 섞지 않는다.

## 9. Commit 정책

기본 정책:

- Execution Role은 task branch에서 commit할 수 있다.
- commit은 Task 범위 안의 변경만 포함한다.
- commit message는 Task ID를 포함한다.
- `.ai/` 변경과 프로젝트 변경은 같은 commit에 섞지 않는다.
- default branch에 직접 commit하지 않는다.

권장 commit message:

```text
<type>: <summary> (<task_id>)
```

예시:

```text
fix: handle auth error state (T-20260709-001)
docs: update iOS team guide (T-20260709-002)
```

프로젝트가 더 보수적인 운영을 원하면 아래 옵션을 선택한다.

```yaml
commit_policy: lead_approval_required
```

이 경우 Execution Role은 변경 제안만 하고, commit은 Lead Role 승인 후 진행한다.

## 10. Push 정책

기본 정책:

- Execution Role은 프로젝트 설정이 허용하면 task branch를 push할 수 있다.
- default branch 직접 push는 금지한다.
- push 전 local verification 결과를 기록한다.
- push 후 PR URL 또는 branch 상태를 Task에 기록한다.

선택 옵션:

```yaml
push_policy: execution_role_can_push_task_branch
```

또는 더 보수적으로:

```yaml
push_policy: lead_approval_required
```

## 11. PR 정책

기본 정책:

- PR은 Task 단위로 만든다.
- PR 제목에 Task ID를 포함한다.
- PR 설명은 Task 파일, 변경 범위, 검증 결과를 연결한다.
- PR review는 Verification Role이 수행한다.
- 자기 PR을 자기 혼자 approve하지 않는다.
- PR이 approved이고 CI가 필요한 경우 passed 상태일 때만 merge 후보가 된다.

권장 PR 제목:

```text
[T-YYYYMMDD-001] Short task title
```

권장 PR 설명:

```text
Task:
- T-YYYYMMDD-001

Scope:
-

Verification:
-

Risk:
-
```

## 12. Merge 정책

기본 정책:

- merge는 Lead Role이 수행한다.
- merge 전 Task는 `completion_review` 상태여야 한다.
- Verification Role의 검증 결과가 `verification_passed`여야 한다.
- 필요한 CI가 passed여야 한다.
- ownership 또는 dependency 충돌이 없어야 한다.
- merge 후 Task를 `done`으로 전환한다.

금지:

- Execution Role은 자기 PR을 merge하지 않는다.
- Verification Role은 검증 통과만 기록하고 merge하지 않는다.
- default branch에 직접 push로 merge를 대체하지 않는다.

## 13. 프로젝트별 설정 위치

실제 프로젝트는 아래 중 하나에 branch/PR 설정을 기록한다.

권장:

```text
.ai_project/branch_pr_strategy.md
```

Team별 설정이 필요하면:

```text
.ai_project/teams/ios/branch_pr_strategy.md
```

운영 결정 이력은 아래에도 기록한다.

```text
.ai_project/ops_decisions.md
```

## 14. 프로젝트별 설정 템플릿

프로젝트에서 아래 항목을 선택한다.

```yaml
branch_strategy:
  model: feature_branch_pr
  base_branch: main
  branch_naming: "{type}/{task_id}-{slug}"

permissions:
  commit_policy: execution_role_can_commit_task_branch
  push_policy: execution_role_can_push_task_branch
  pr_creator: Execution Role
  pr_reviewer: Verification Role
  merge_owner: Lead Role

pull_request:
  required: true
  ci_required: true
  review_required: true
  self_approval_allowed: false

merge:
  method: squash
  delete_branch_after_merge: true
  default_branch_direct_push: false
```

## 15. Project Bootstrap 질문

새 프로젝트에서 팀 구성을 시작할 때 아래 질문에 답한다.

```text
1. 기본 branch는 무엇인가? main / develop / other
2. 사용할 전략은 무엇인가? feature_branch_pr / trunk_based_pr / gitflow
3. Execution Role이 task branch에 commit할 수 있는가?
4. Execution Role이 task branch를 push할 수 있는가?
5. PR은 필수인가?
6. CI 통과가 merge 조건인가?
7. merge owner는 누구인가? Lead Role / Project Owner / other
8. merge 방식은 무엇인가? squash / merge_commit / rebase
9. branch 삭제 정책은 무엇인가?
```

이 질문의 답은 `.ai_project/branch_pr_strategy.md` 또는 팀별 branch strategy 문서에 기록한다.

## 16. 금지사항

- default branch에서 직접 작업하지 않는다.
- default branch에 직접 push하지 않는다.
- 여러 Task를 한 branch에 섞지 않는다.
- Task ID 없는 branch를 만들지 않는다.
- Task ID 없는 PR을 만들지 않는다.
- Verification Role 없이 merge하지 않는다.
- Execution Role이 자기 PR을 단독 approve하거나 merge하지 않는다.
- `.ai/` 변경과 프로젝트 코드 변경을 같은 commit/PR에 섞지 않는다.

## 17. 변경 이력

| 날짜 | 변경 내용 |
|---|---|
| 2026-07-09 | 조직형 AI Agent 운영체계의 branch / PR 일반 정책 초안 작성 |

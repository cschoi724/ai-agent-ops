# Project Branch and PR Strategy

작성일: {{DATE}}  
프로젝트: {{PROJECT_NAME}}

## 1. 목적

이 문서는 현재 프로젝트에서 선택한 branch / commit / PR / merge 전략을 기록한다.

일반 정책은 `.ai/policies/branch_pr_policy.md`를 따른다. 이 문서는 프로젝트별 선택값만 기록한다.

## 2. Selected Strategy

```yaml
branch_strategy:
  model: feature_branch_pr
  base_branch: main
  branch_naming: "{type}/{task_id}-{slug}"
```

## 3. Role Permissions

```yaml
permissions:
  commit_policy: execution_role_can_commit_task_branch
  push_policy: execution_role_can_push_task_branch
  pr_creator: Execution Role
  pr_reviewer: Verification Role
  merge_owner: Lead Role
```

## 4. Pull Request Rules

```yaml
pull_request:
  required: true
  ci_required: true
  review_required: true
  self_approval_allowed: false
```

## 5. Merge Rules

```yaml
merge:
  method: squash
  delete_branch_after_merge: true
  default_branch_direct_push: false
```

## 6. Project Decisions

| 항목 | 선택값 | 결정 사유 |
|---|---|---|
| 기본 branch | main | |
| 전략 | feature_branch_pr | |
| Execution Role commit | allowed on task branch | |
| Execution Role push | allowed on task branch | |
| PR 필수 | yes | |
| CI 필수 | yes | |
| merge owner | Lead Role | |
| merge method | squash | |

## 7. Team Overrides

Team별 예외가 없으면 아래 표를 비워둔다.

| Team | Strategy Path | 예외 내용 | 승인 |
|---|---|---|---|
|  |  |  |  |

## 8. 변경 이력

| 날짜 | 변경 내용 |
|---|---|
| {{DATE}} | 프로젝트 branch / PR 전략 초기 기록 |

# Branch and PR Policy

작성일: 2026-07-10
상태: Draft vNext Slim Reference
범위: branch, commit, push, PR, merge 운영 기준

## 1. 목적

이 문서는 AI Agent가 Git 작업을 수행할 때 지켜야 하는 안전 기준을 정의한다.

프로젝트별 실제 선택값은 `.ai_project/operating_model.md`와 `.ai_project/branch_pr_strategy.md`에 기록한다.

## 2. 기본 원칙

- 기본 branch에 직접 push하지 않는다.
- commit, push, PR, merge는 프로젝트 정책과 사용자 승인 범위를 따른다.
- 여러 worktree 또는 task branch를 사용하면 공용 상태 기준은 `shared_status_policy.md`의 `canonical_status_ref`를 따른다.
- Execution Role은 작업 단위 변경과 commit을 맡을 수 있다.
- Verification Role은 검증 결과와 review 근거를 기록한다.
- Lead Role은 merge 가능 여부를 최종 판단한다.
- 자동 merge는 명시적으로 허용된 경우에만 가능하다.

## 3. Canonical Branch / PR Model

운영모델 front matter의 canonical 값은 `schemas/operating_model.schema.json`과 `runtime/bootstrap_options.json`을 따른다.

| Canonical 값 | 의미 | 기존/세부 전략 alias |
|---|---|---|
| `pending_decision` | Git 전략 미정 | no_git, not_initialized |
| `simple_safe` | 안전 기본값, 사용자 승인 중심 | local_only_with_approval |
| `branch_per_task` | Task마다 branch 생성 | `feature_branch_pr` |
| `pr_required` | PR과 독립 review 필수 | `trunk_based_pr` |
| `custom` | 프로젝트별 전략 | `gitflow`, 회사 정책 |

문서나 bootstrap 대화에서 `feature_branch_pr`, `trunk_based_pr`, `gitflow`가 나오면 위 canonical 값으로 매핑한다.

## 4. 권장 기본값

코드 프로젝트의 안전 기본값:

```yaml
branch_pr: branch_per_task
default_branch: main
task_branch_pattern: task/<task-id>-<slug>
commit_owner: Execution Role
commit_timing: after_task_unit
push_allowed: with_user_approval
pr_required: true
review_required: Verification Role
merge_owner: Lead Role
delete_branch_after_merge: true
```

Git 저장소가 없거나 구현 준비 전이면 `pending_decision`으로 둔다.

## 5. Role별 책임

| Role | 가능 | 금지 |
|---|---|---|
| Lead Role | branch 전략 결정 제안, merge 판단, 충돌 조율 | 검증 없이 merge 승인 |
| Execution Role | task branch 생성, 작업 commit, PR 초안 작성 | 승인 없이 push/merge |
| Verification Role | PR review, CI/test 확인, risk 기록 | 자기 구현을 독립 검증으로 처리 |
| Completion Role | merge 후 done 판단 | 미검증 변경 완료 처리 |
| Release Role | release branch, tag, rollback 확인 | release 책임 없을 때 임의 활성 |
| Ops Governance Role | 정책 위반 점검 | 제품 merge 판단 대체 |

## 6. Task 상태와 Git 흐름

| Task 상태 | Git 작업 |
|---|---|
| `proposed` | branch 생성 금지 |
| `scoped` | branch 전략과 allowed paths 확인 |
| `approved` | task branch 생성 가능 |
| `in_progress` | 작업 commit 가능 |
| `verification_ready` | PR 또는 diff 검증 요청 가능 |
| `verification_in_progress` | review/test 수행 |
| `verification_passed` | Lead merge 판단 가능 |
| `completion_review` | merge 결과와 잔여 리스크 확인 |
| `done` | branch 정리 가능 |

## 7. Branch Naming

기본 패턴:

```text
task/<task-id>-<short-slug>
```

예:

```text
task/T-20260727-001-login-flow
```

팀별 prefix가 필요하면 프로젝트별 branch strategy에 기록한다.

## 8. Commit 정책

Execution Role은 작업 단위가 검증 가능해졌을 때 commit할 수 있다.

권장:

- 하나의 commit은 하나의 명확한 변경 목적을 가진다.
- Task ID를 commit 메시지에 포함한다.
- generated artifact와 source 변경을 구분한다.
- 사용자 승인 없이 unrelated cleanup을 섞지 않는다.

commit 권한 세부 기준은 `policies/commit_policy.md`를 따른다.

## 9. Push 정책

원격 push는 사용자 승인 또는 프로젝트 정책이 필요하다.

기본값:

```yaml
push_allowed: with_user_approval
```

금지:

- 기본 branch 직접 push
- 승인되지 않은 remote 변경
- force push 기본 허용

## 10. PR 정책

PR에는 아래 정보가 있어야 한다.

```text
Task:
Scope:
Changed paths:
Validation:
Risks:
Handoff:
```

Verification Role은 PR 또는 diff를 보고 검증 근거를 남긴다.

## 11. Merge 정책

merge 조건:

- Task가 `verification_passed` 또는 그에 준하는 승인 상태다.
- Verification 결과가 기록되어 있다.
- unresolved risk가 Lead Role에 의해 수용되었다.
- branch가 기본 branch와 충돌하지 않는다.
- Task 상태와 dependency가 최신 `canonical_status_ref` 기준으로 확인되었다.

merge owner 기본값은 Lead Role이다.

## 12. 프로젝트별 설정 위치

```text
.ai_project/branch_pr_strategy.md
.ai_project/teams/<team_id>/branch_pr_strategy.md
```

Team별 override는 플랫폼, repo, CI, release gate가 다를 때만 둔다.

다중 worktree 또는 task branch 운영에서는 아래 값을 함께 기록한다.

```yaml
canonical_status_ref: origin/main
```

## 13. Bootstrap 질문

Branch / PR 결정 시 필요한 최소 질문:

1. 현재 Git 저장소인가?
2. 기본 branch는 무엇인가?
3. Task branch와 PR을 사용할 것인가?
4. 누가 commit, push, review, merge를 맡는가?
5. 원격 작업은 사용자 승인 후 진행할 것인가?

선택 후보는 `runtime/bootstrap_options.json`을 기준으로 제시한다.

## 14. 금지사항

- 기본 branch 직접 push를 기본값으로 두지 않는다.
- Execution Role이 자기 변경을 검증 완료로 확정하지 않는다.
- 사용자가 승인하지 않은 push, PR, merge를 하지 않는다.
- release 책임이 없는 프로젝트에 GitFlow를 기본 추천하지 않는다.
- branch/PR 정책이 미정인 상태에서 commit/push 자동화를 강제하지 않는다.

## 15. 변경 이력

| 날짜 | 변경 내용 |
|---|---|
| 2026-07-10 | branch / commit / PR / merge 일반 정책 추가 |
| 2026-07-27 | canonical option과 상세 전략 alias를 분리하고 slim reference로 압축 |

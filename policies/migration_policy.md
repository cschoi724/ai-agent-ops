# Migration Policy

이 문서는 기존 프로젝트의 `.ai_project/`를 현재 AI Agent Ops core 기준으로 갱신할 때 지켜야 하는 정책이다.

## 1. 원칙

- Migration Discovery Phase에서는 파일을 수정하지 않는다.
- Apply Phase는 사용자가 Migration Plan과 파일 수정 범위를 승인한 뒤에만 진행한다.
- 자동 적용은 운영 파일에 한정한다.
- 제품 코드, 제품 문서, Task 상태, Role/Agent 매핑, branch/PR 전략은 임의 변경하지 않는다.
- migration은 release, schema, ownership 변경과 같은 순차 gate로 취급한다.

## 2. 대상 범위

자동 점검 대상:

- `.ai/`
- `.ai/VERSION`
- `.ai_project/`
- `.ai_project/operating_model.md`의 `core_version`
- `.ai_project/tasks/`
- `.ai_knowledge/`
- `AGENTS.md`
- `CLAUDE.md`

자동 적용 가능 대상:

- `.ai_project/operating_model.md`의 core version 기록
- `.ai_project/tasks/active/`
- `.ai_project/tasks/backlog/`
- `.ai_project/tasks/archive/`
- `.ai_project/ops_migration_plan.md`
- `.ai_project/ops_decisions.md`
- `.ai_project/ops_issues.md`
- `.ai_knowledge/` minimal workspace

자동 적용 금지 대상:

- 제품 코드
- 제품 문서
- `source_of_truth` 재지정
- Task 상태 변경
- Task 담당 Role/Agent 변경
- branch/PR 전략 확정
- commit, push, deploy

## 3. 판정 분류

Migration 점검 결과는 아래 네 범주로 나눈다.

| 범주 | 의미 |
|---|---|
| `blocking` | Apply 전에 해결해야 하는 구조 문제 |
| `safe_auto_fix` | 승인 후 CLI가 자동 적용 가능한 운영 파일 보강 |
| `needs_user_decision` | 사용자가 방향을 정해야 하는 운영 선택 |
| `manual_only` | Agent/CLI가 자동 변경하지 않는 제품 또는 권한 영역 |

## 4. 승인 기준

Agent는 적용 전에 아래 내용을 사용자에게 보여준다.

- 현재 core version
- 프로젝트에 기록된 core version
- 예상 영향
- 자동 적용할 파일과 디렉토리
- 사용자 결정이 필요한 항목
- 자동 변경하지 않는 항목

사용자가 승인해야만 `aiops migrate --apply` 또는 동등한 Apply 작업을 진행한다.

## 5. 검증 기준

Apply 후에는 아래 검증을 실행한다.

```bash
aiops doctor --strict
aiops knowledge lint
```

Task 파일을 변경하지 않았더라도 기존 Task가 있으면 필요에 따라 아래 검증을 추가한다.

```bash
aiops validate task .ai_project/tasks/active/T-YYYYMMDD-001.md
```

검증 결과는 `completed`, `completed_with_warnings`, `failed` 중 하나로 보고한다.

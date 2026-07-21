# AI Project Templates

작성일: {{DATE}}  
상태: Draft

## 1. 목적

이 디렉토리는 `.ai_project/` 생성용 템플릿을 bootstrap mode별로 제공한다.

`.ai/`는 공통 운영체계이고, `.ai_project/`는 프로젝트별 실제 운영 구성과 상태를 기록한다.

## 2. Template Sets

| Template Set | 용도 | 권장 상황 |
|---|---|---|
| `fast_track/` | 최소 운영 구성 | 처음 사용하는 사용자, 비개발자, 작은 프로젝트, discovery 중심 프로젝트 |
| `guided_full/` | 상세 운영 구성 | Team/Role/Workflow/Ownership/Branch/Source of Truth를 세부 선택한 프로젝트 |

## 3. Fast Track 생성 후보

Fast Track은 아래 문서만 기본 생성한다.

```text
.ai_project/README.md
.ai_project/operating_model.md
.ai_project/agent_registry.md
.ai_project/current_context.md
.ai_project/task_board.md
.ai_project/source_of_truth.md
.ai_project/ops_decisions.md
.ai_project/ops_issues.md
.ai_project/tasks/active/
.ai_project/tasks/backlog/
.ai_project/tasks/archive/
.ai_project/reports/
.ai_project/qa/
.ai_knowledge/README.md
.ai_knowledge/index.md
.ai_knowledge/log.md
.ai_knowledge/project_brief.md
```

Fast Track은 branch / PR, workflow override, team context를 기본 생성하지 않는다. `knowledge_mode: minimal`을 선택하면 `.ai_knowledge/` 최소 문서를 함께 생성한다. 필요해지면 Guided Full 문서를 추가한다.

## 4. Guided Full 생성 후보

Guided Full은 아래 문서를 기본 생성한다.

```text
.ai_project/README.md
.ai_project/operating_model.md
.ai_project/agent_registry.md
.ai_project/current_context.md
.ai_project/source_of_truth.md
.ai_project/task_board.md
.ai_project/branch_pr_strategy.md
.ai_project/workflow_overrides.md
.ai_project/ops_decisions.md
.ai_project/ops_issues.md
.ai_project/ops_migration_plan.md
.ai_project/tasks/active/
.ai_project/tasks/backlog/
.ai_project/tasks/archive/
.ai_project/reports/
.ai_project/qa/
.ai_knowledge/
```

Team별 구성이 필요하면 아래 문서를 추가한다.

```text
.ai_project/teams/{team_id}/team_context.md
.ai_project/teams/{team_id}/task_board.md
.ai_project/teams/{team_id}/branch_pr_strategy.md
```

## 5. 적용 원칙

- 사용자가 선택한 bootstrap mode에 맞는 템플릿만 기본 적용한다.
- Fast Track으로 시작한 프로젝트도 나중에 Guided Full 문서를 추가할 수 있다.
- `.ai_knowledge/`는 source of truth가 아니라 Agent 온보딩용 LLM Wiki다.
- 존재하지 않는 기준 문서는 `unresolved` 또는 `to_create_candidate`로 기록한다.
- `.ai_project/tasks/`의 Task 파일이 실행 지시의 source of truth다.

## 6. 변경 이력

| 날짜 | 변경 내용 |
|---|---|
| {{DATE}} | Fast Track / Guided Full 템플릿 세트 분리 |

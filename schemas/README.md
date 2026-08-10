# AI Ops Schemas

작성일: 2026-07-27
상태: Draft v1

## 목적

`schemas/`는 AI Ops 운영 문서의 기계 판독 가능한 규격을 정의한다.

AI Ops의 원칙은 다음과 같다.

```text
Schema-first, Markdown-second
```

- Schema는 CLI와 CI가 검증할 기준이다.
- Markdown은 사람이 읽고 운영 결정을 이해하기 위한 표현 계층이다.
- 실제 프로젝트 문서는 Markdown을 유지하되 상단 YAML front matter에 schema 대상 필드를 기록한다.

## 적용 방식

예시 Task 문서:

```md
---
schema: aiops.task.v1
id: T-20260727-001
title: 로그인 화면 구현
status: approved
workflow: feature
target_role: Execution Role
required_capabilities:
  - implementation
allowed_paths:
  - App/Login/
source_of_truth:
  - .ai_project/knowledge/project_brief.md
---

# 로그인 화면 구현
```

CLI는 front matter를 읽어 schema로 검증하고, 본문은 사람이 읽는 작업 설명으로 둔다.

## Schema 목록

| 파일 | 대상 | 설명 |
|---|---|---|
| `task.schema.json` | `.ai_project/tasks/**/*.md` front matter | Task metadata, 상태, Role 라우팅, lock, report/QA 경로 |
| `workflow.schema.json` | workflow definition | 상태 전이, 수행 Role, 다음 Role, 승인/인계 요구 |
| `workflow_catalog.schema.json` | `runtime/workflows.json` | workflow catalog, checkpoint, canonical publish 정책 |
| `handoff.schema.json` | handoff metadata/message | Role 간 인계 필수 정보 |
| `agent_registry.schema.json` | `.ai_project/agent_registry.md` front matter | Agent, Role, capability 매핑 |
| `operating_model.schema.json` | `.ai_project/operating_model.md` front matter | 프로젝트 운영 모드, workflow, board, ownership 선택값 |
| `runtime_export.schema.json` | `aiops export runtime` JSON | 외부 runtime adapter가 읽을 Task/Role/Handoff snapshot |
| `bootstrap_options.schema.json` | `runtime/bootstrap_options.json` | Bootstrap 선택 후보 catalog |
| `project_snapshot.schema.json` | `aiops project snapshot --json` JSON | Agent가 먼저 읽는 프로젝트 상태 계약과 통제 신호 |
| `project_dashboard.schema.json` | `aiops project dashboard --json` JSON | dashboard terminal/tree/Mermaid/HTML/UI renderer가 공유하는 projection 계약 |
| `policy_rules.schema.json` | `runtime/policy_rules.json` | 운영 판단 규칙 catalog |
| `policy_evaluation.schema.json` | `aiops policy evaluate --json` JSON | snapshot에 policy rule을 적용한 평가 결과 |
| `action_plan.schema.json` | `aiops action plan --json` JSON | Agent 작업 착수 전 의도/승인/차단 검토 계약 |

## 단계별 적용

1단계에서는 schema와 template front matter를 추가했다.

2단계부터 `aiops validate`가 이 schema 기준의 필수 필드와 허용 값을 검사한다.

3단계 이후 `aiops task transition`, `aiops handoff validate`가 같은 schema를 상태 전이 guardrail로 사용한다.

9단계 이후 `aiops export runtime`이 Task graph, Role assignment, 상태, Handoff, approval checkpoint를 runtime adapter용 JSON으로 내보낸다.

10단계 이후 다중 worktree 운영을 위해 `canonical_status_ref`, `status_ref`, `status_ref_sha`, `worktree_path`, `base_ref` 계열 필드를 optional로 기록한다. 기존 프로젝트 migration 충돌을 줄이기 위해 첫 단계에서는 required로 강제하지 않는다.

Workflow catalog 단계 이후 `runtime/workflows.json`은 상태별 checkpoint와 canonical publish 정책을 제공한다. Markdown workflow 문서는 설명 계층이고, CLI는 catalog를 읽어 상태 전이 출력과 검증을 보강한다.

Policy rules 단계 이후 `runtime/policy_rules.json`은 health, snapshot, validate에서 사용하는 운영 판단 규칙을 데이터화하기 위한 catalog 역할을 한다. `aiops policy evaluate --json`은 project snapshot을 입력으로 받아 적용된 rule을 `aiops.policy_evaluation.v1` 계약으로 출력한다. `project snapshot --json`도 같은 policy 평가 요약을 포함한다.

Action plan 단계 이후 Agent는 작업 착수 전 `aiops action plan --json`으로 의도한 행동과 승인 필요 항목, 차단 항목을 구조화할 수 있다. 이 계약은 자동 실행 엔진이 아니라 작업 전 검토 결과다.

Dashboard JSON 단계 이후 `aiops project dashboard --json`은 사람이 보는 terminal/tree/Mermaid/HTML 출력과 같은 의미를 공유하는 projection 계약을 제공한다. Dashboard JSON은 source of truth가 아니며 `project snapshot --json`과 `project health --json`에서 파생된다. `maps.summary`, `maps.dependencies`, `maps.swimlane`, `maps.critical_path`는 큰 프로젝트를 요약/필터링해 보는 renderer가 쓰는 파생 데이터를 담고, `views.risk`, `views.agents`, `views.release`는 전문 dashboard view가 쓰는 파생 데이터를 담는다.

## 호환성 원칙

- 기존 Markdown 본문은 유지한다.
- Fast Track은 최소 필드만 요구한다.
- Guided Full은 team, branch/PR, handoff, verification 정보를 더 엄격하게 요구할 수 있다.
- 사용자 커스텀 문서는 migration 단계에서 자동 수정 가능 항목과 사용자 결정 필요 항목으로 분리한다.

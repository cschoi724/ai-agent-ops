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
| `transition_receipt.schema.json` | 상태 전이 결과 JSON | Task ID, 전이 상태, 행동 Agent/Role, 다음 담당, 검증 근거, 위험과 blocker를 담는 compact receipt |
| `task_transition_plan.schema.json` | `aiops task advance/accept --json` JSON | 송신·수신 readiness, 자동 계산된 전이, 원자적 write set과 compact receipt projection |
| `task_risk_profile.schema.json` | `aiops task profile TASK_ID --json` JSON | 위험 신호, 선택 profile, 필수 Role·검증·보고·CI gate와 targeted validation projection |
| `task_cleanup_plan.schema.json` | `aiops task close TASK_ID --check --json` JSON | canonical 완료·merge·branch/worktree·승인 점검과 예상 정리 작업 |
| `task_cleanup_receipt.schema.json` | Task cleanup 결과 JSON | 실행된 branch/worktree 정리, 부분 실패, 재시도에 사용하는 로컬 receipt |
| `model_catalog.schema.json` | `runtime/model_catalog.json` | provider별 model, 지원 effort, 추천 profile과 공식 source 계약 |
| `model_overrides.schema.json` | `.ai_project/model_overrides.json` | project/custom provider mapping, alias와 managed allowlist override 계약 |
| `model_recommendation.schema.json` | `aiops model recommend --json` JSON | session, Task, 독립 검증, delegated worker별 실제 모델·effort·fallback 추천 계약 |
| `agent_identity_audit.schema.json` | `aiops agent inspect --json` JSON | Registry Agent 이름과 active/backlog/archive Task 참조의 정합성 감사 결과 |
| `agent_registry.schema.json` | `.ai_project/agent_registry.md` front matter | Agent, Role, capability 매핑 |
| `operating_model.schema.json` | `.ai_project/operating_model.md` front matter | 프로젝트 운영 모드, workflow, board, ownership 선택값 |
| `runtime_export.schema.json` | `aiops export runtime` JSON | 외부 runtime adapter가 읽을 Task/Role/Handoff snapshot |
| `bootstrap_options.schema.json` | `runtime/bootstrap_options.json` | Bootstrap 선택 후보 catalog |
| `project_snapshot.schema.json` | `aiops project snapshot --json` JSON | Agent가 먼저 읽는 프로젝트 상태 계약과 통제 신호 |
| `project_dashboard.schema.json` | `aiops project dashboard --json` JSON | dashboard terminal/tree/Mermaid/HTML/UI renderer가 공유하는 projection 계약. `--github` 사용 시 release view에 선택적 GitHub 상태 포함 |
| `dashboard_presets.schema.json` | `.ai_project/dashboard_presets.json` | 프로젝트별 dashboard 옵션 preset 계약 |
| `dashboard_locale.schema.json` | `.ai_project/dashboard_labels.*.json` | 사용자용 dashboard label의 locale별 프로젝트 override 계약 |
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

Transition receipt 단계 이후 `aiops.transition_receipt.v1`은 상태 전이의 공통 결과 계약이다. Task report, QA report, handoff와 최종 응답은 이 receipt를 입력으로 재사용할 수 있다. 기존 `aiops.handoff.v1`과 과거 Task/report/QA 파일은 그대로 유효하며 일괄 변환하지 않는다.

Transition automation 단계 이후 `aiops task accept`는 현재 담당자의 시작 전이를, `aiops task advance`는 다음 Role로의 인계를 처리한다. `--check`는 파일을 바꾸지 않고 readiness와 write set을 계산하며, `--json`은 `aiops.task_transition_plan.v1`으로 같은 판단을 제공한다. 실제 적용은 Task, lock, receipt, Role 간 handoff와 board projection을 하나의 rollback 가능한 bundle로 갱신한다.

Risk profile 단계 이후 `aiops task profile TASK_ID`는 Task scope와 실제 Git 변경 경로를 바탕으로 Light, Standard, Strict를 추천한다. Task의 선택적 `risk_profile`과 workflow의 `default_profile`을 읽되, schema·보안·migration·release 같은 위험 신호가 요구하는 최소 profile보다 낮출 수 없다. JSON은 실행 문자열이 아니라 argv 배열로 targeted validation 계획을 제공한다.

Safe Task Close 단계 이후 `aiops task close TASK_ID --check --json`은 canonical의 `done`, merge 증거, branch 소유권, worktree, 보호 규칙과 승인 정책을 파일 변경 없이 검사한다. `--apply`는 검증된 linked worktree와 local branch만 정리하며 `--delete-remote`가 있을 때만 SHA lease를 사용해 원격 branch를 삭제한다. cleanup receipt는 새 운영 commit을 요구하지 않도록 `.ai_project/.runtime/task_cleanup/`에 로컬 cache로 기록한다.

Model Advisor 단계 이후 `runtime/model_catalog.json`은 Codex, Claude Code와 custom provider의 실제 모델·effort mapping을 제공한다. 선택적 `.ai_project/model_overrides.json`은 조직/project allowlist와 mapping만 덮어쓰며 인증 정보는 저장하지 않는다. `aiops.model_recommendation.v1`은 locale과 무관한 advisory-only projection이고 실행 명령은 shell 문자열이 아닌 argv 배열이다. provider command를 함께 기록해 validator가 model·effort와 argv 의미를 교차 검증한다.

Agent identity 호환 단계 이후 `aiops agent inspect`는 Agent Registry의 optional `id`·`aliases`와 Task의 optional `target_agent_id`·`target_agent`를 같은 resolver로 검사한다. ID가 canonical routing key이며 현재 이름과 단일 alias는 legacy 호환 경로다. active/backlog의 미등록·모호·ID/이름 불일치 참조는 strict validation과 lifecycle을 차단하고, 이름 또는 alias 기반 참조는 `migration_required`로 보고한다. archive의 과거 이름은 감사 이력을 보존하기 위해 warning으로만 처리한다. `aiops.agent_identity_audit.v1`은 현재 표시 이름, 안정 ID, 해석 방식과 migration 상태를 자동화가 읽을 수 있는 JSON으로 제공한다.

Dashboard JSON 단계 이후 `aiops project dashboard --json`은 사람이 보는 terminal/tree/Mermaid/HTML 출력과 같은 의미를 공유하는 projection 계약을 제공한다. Dashboard JSON은 source of truth가 아니며 `project snapshot --json`과 `project health --json`에서 파생된다. `maps.summary`, `maps.dependencies`, `maps.swimlane`, `maps.critical_path`는 큰 프로젝트를 요약/필터링해 보는 renderer가 쓰는 파생 데이터를 담고, `views.risk`, `views.agents`, `views.release`는 전문 dashboard view가 쓰는 파생 데이터를 담는다.

Dashboard preset 단계 이후 `.ai_project/dashboard_presets.json`은 팀이 반복 사용하는 dashboard 옵션 조합을 저장한다. preset은 source data나 렌더링 결과를 저장하지 않고 실행 시 기존 dashboard 옵션으로 확장된다.

Dashboard locale 단계 이후 `aiops.dashboard_locale.v1`은 사용자 표시 문자열만 프로젝트별로 덮어쓴다. machine JSON, Task metadata, Mermaid 내부 ID는 locale file이 변경할 수 없다.

## 호환성 원칙

- 기존 Markdown 본문은 유지한다.
- Fast Track은 최소 필드만 요구한다.
- Guided Full은 team, branch/PR, handoff, verification 정보를 더 엄격하게 요구할 수 있다.
- 사용자 커스텀 문서는 migration 단계에서 자동 수정 가능 항목과 사용자 결정 필요 항목으로 분리한다.

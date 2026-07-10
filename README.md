# AI Agent Ops

작성일: 2026-06-29  
상태: Draft vNext  
범위: 조직형 AI Agent 운영체계

## 1. 목적

이 저장소는 여러 AI Agent를 하나의 조직처럼 운영하기 위한 운영체계다.

기존 v1 모델은 단일 프로젝트에서 PM Agent, Development Agent, QA Agent, AI Ops Agent가 Task Queue를 공유하는 안정 운영모델이었다. `org-ops-model` 브랜치의 vNext 모델은 그 기반을 확장해 Organization, Division, Team, Role, Capability, Workflow, Task를 분리한다.

최상위 원칙은 `core/constitution.md`를 따른다.

`.ai/`는 `ai-agent-ops` 운영체계와 템플릿 프레임워크로 별도 관리한다. 적용 대상 프로젝트별 Agent 작업 상태와 Agent 간 협업 기록은 `.ai_project/`에 둔다.

## 2. 먼저 읽을 문서

Agent는 아래 순서로 문서를 확인한다.

1. `.ai/core/constitution.md`
2. `.ai/models/org_model.md`
3. `.ai/models/team_model.md`
4. `.ai/models/role_model.md`
5. `.ai/policies/ownership_model.md`
6. `.ai/policies/coordination_policy.md`
7. `.ai/policies/board_model.md`
8. `.ai/bootstrap/project_bootstrap_policy.md`
9. `.ai/bootstrap/bootstrap_runbook.md`
10. 현재 템플릿 버전은 `.ai/VERSION`
11. 버전별 변경 이력은 `.ai/CHANGELOG.md`
12. `.ai/runtime/workflow.md`
13. `.ai/policies/document_governance.md`
14. `.ai/policies/project_workspace.md`
15. `.ai/models/agent_registry.md`
16. `.ai/models/capabilities.md`
17. `.ai/policies/commit_policy.md`
18. `.ai/policies/branch_pr_policy.md`
19. `.ai/runtime/task_queue.md`
20. 운영 점검 Role이면 `.ai/agents/ai_ops_agent.md`
21. 작업 유형에 맞는 `.ai/workflows/*.md`
22. 프로젝트가 초기화되어 있으면 `.ai_project/operating_model.md`, `.ai_project/current_context.md`, `.ai_project/tasks/` 문서

## 3. 디렉토리 구조

| 디렉토리 | 역할 |
|---|---|
| `core/` | 최상위 원칙과 헌법 |
| `models/` | Organization, Team, Role, Capability, Agent 모델 |
| `policies/` | ownership, coordination, board, Git, 문서 보호 정책 |
| `runtime/` | workflow와 task queue 실행 규칙 |
| `bootstrap/` | 프로젝트별 운영체계 초기 구성 절차 |
| `agents/` | 기본 bootstrap Agent 참고 문서 |
| `workflows/` | Task 유형별 workflow |
| `templates/` | `.ai_project`와 프로젝트 문서 템플릿 |

## 4. 버전과 변경 이력

현재 템플릿 버전:

```text
.ai/VERSION
```

버전별 변경 이력과 패치노트:

```text
.ai/CHANGELOG.md
```

## 5. 기본 운영

vNext 기본 운영 단위는 Agent 목록이 아니라 조직 구조다.

초기 실운영 후보:

```text
AI Agent Ops Organization
  Development Division
    선택 Team
  AI Ops Division
```

기존 v1의 기본 실행 Agent는 bootstrap Role로 유지한다.

- PM Agent
- Development Agent
- QA Agent

AI Ops Agent는 제품 Task 실행 라인 밖에서 운영 프로세스를 점검하는 독립 Agent로 선택 활성화할 수 있다.

- AI Ops Agent

이 구성은 고정 상한이 아니라 시작점이다. vNext에서는 Agent 이름보다 Organization, Division, Team, Role, Capability, Workflow, Task의 관계를 우선한다. 운영 중 반복 부담이나 독립 검토 필요성이 생기면 새 Role과 Team을 추가하고 capability를 위임한다. 운영 프로세스 충돌이나 역할 경계 문제는 AI Ops Division이 별도로 점검한다.

## 6. 저장소 원칙

- `.ai/`: `ai-agent-ops` 템플릿 저장소
- `.ai_project/`: 적용 대상 프로젝트의 Agent 협업 문서
- 적용 대상 프로젝트는 `.ai/`를 `.gitignore`로 제외한다.
- 적용 대상 프로젝트는 기본적으로 `.ai_project/`를 저장소에 포함한다.
- 단, 초기 마이그레이션이나 운영 실험 단계에서는 사용자 결정으로 `.ai_project/`를 로컬 전용으로 둘 수 있다.

## 7. 프로젝트 초기화와 운영 마이그레이션

AI Ops Agent는 사용자가 명시적으로 요청한 경우에만 `.ai_project/` 초기화 또는 운영 마이그레이션을 주도한다.

프로젝트별 실제 운영 구성은 `.ai/bootstrap/project_bootstrap_policy.md` 기준으로 선택하고, 실행 순서는 `.ai/bootstrap/bootstrap_runbook.md`를 따른다. 결과는 `.ai_project/operating_model.md`에 기록한다.

프로젝트 구성은 Start Context 선택으로 시작한다. AI Ops Agent는 요구사항이 있는 신규 프로젝트, 기존 프로젝트/업무 인수, 백지 탐색, 복구, 마이그레이션, 운영체계 도입, 조직 확장 중 어디서 시작하는지 먼저 분류한 뒤 운영 모드와 Team/Role 구성을 제안한다.

새 프로젝트 또는 기존 프로젝트에 AI Agent 운영 체계를 도입할 때는 아래 workflow를 따른다.

```text
.ai/workflows/ops_migration.md
```

Lead Role 또는 Direction Role은 제품/일정 영향과 source of truth 최종 판단을 담당하고, 첫 제품 Task는 운영 마이그레이션 이후 `.ai_project/tasks/`에 `proposed` 상태로 등록한다.

Agent 협업 문서 초기화 템플릿은 아래 위치에 있다.

```text
.ai/templates/ai_project/
```

Agent 실행 Task 템플릿은 아래 위치에 있다.

```text
.ai/templates/tasks/
```

프로젝트 자체의 핵심 문서 템플릿은 아래 위치에 있다.

```text
.ai/templates/project_docs/
```

선택한 프로젝트 문서 위치와 최종 기준은 `.ai_project/source_of_truth.md`에 기록한다.

## 8. Codex 적용

Codex 프로젝트에 적용할 선택 템플릿은 아래 위치에 있다.

```text
.ai/templates/tool_adapters/codex/AGENTS.md
```

## 9. 변경 제한

main 안정 운영모델에서는 `.ai/` 운영 문서를 사용자 승인 없이 수정하지 않는다.

`org-ops-model` 브랜치에서는 조직형 운영모델 설계를 위해 기존 디렉토리와 문서를 대규모로 개정할 수 있다. 단, 실제 프로젝트에 적용할 때는 `.ai/core/constitution.md`의 migration 원칙과 `.ai/policies/document_governance.md`를 따른다.

## 10. 변경 이력

| 날짜 | 변경 내용 |
|---|---|
| 2026-06-29 | `.ai/` 진입점 README v1 작성 |
| 2026-06-29 | 프로젝트 핵심 문서 템플릿 위치와 source of truth 기준 추가 |
| 2026-06-29 | AI Agent 커밋 정책 문서 참조 추가 |
| 2026-06-29 | Task Queue 정책과 템플릿 참조 추가 |
| 2026-06-29 | `.ai_project/` Git 포함 정책의 기본/예외 기준 명확화 |
| 2026-06-29 | AI Agent Ops 튜토리얼 문서 참조 추가 |
| 2026-06-30 | AI Ops Agent 독립 운영 기준 추가 |
| 2026-07-01 | 프로젝트 초기화와 운영 마이그레이션 주체를 AI Ops Agent로 정리 |
| 2026-07-03 | VERSION과 CHANGELOG 링크 추가 |
| 2026-07-09 | 조직형 운영체계 vNext 기준과 constitution 문서 참조 추가 |
| 2026-07-09 | org_model과 role_model 문서 참조 추가 |
| 2026-07-09 | ownership_model과 coordination_policy 문서 참조 추가 |
| 2026-07-09 | board_model 문서 참조 추가 |
| 2026-07-09 | branch_pr_policy 문서 참조 추가 |
| 2026-07-09 | project_bootstrap_policy와 operating_model 참조 추가 |
| 2026-07-09 | team_model 문서 참조 추가 |
| 2026-07-09 | 루트 운영 문서를 core/models/policies/runtime/bootstrap으로 재분류 |
| 2026-07-09 | v1 튜토리얼과 PM/Development/QA Agent 개별 문서 제거 |
| 2026-07-10 | 프로젝트 Start Context 기반 bootstrap 흐름 추가 |
| 2026-07-10 | bootstrap 실행 runbook 문서 참조 추가 |

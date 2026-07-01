# AI Agent Ops

작성일: 2026-06-29  
상태: Draft v1  
범위: Codex 기준 AI Agent 운영 가이드북

## 1. 목적

이 디렉토리는 AI Agent 운영 가이드북이다.

`.ai/`는 `ai-agent-ops` 저장소로 별도 관리하며, 적용 대상 프로젝트 저장소에는 커밋하지 않는다. 프로젝트별 Agent 작업 상태와 Agent 간 협업 기록은 `.ai_project/`에 둔다.

## 2. 먼저 읽을 문서

Agent는 아래 순서로 문서를 확인한다.

1. 처음 적용하거나 흐름을 익히는 중이면 `.ai/tutorial.md`
2. `.ai/workflow.md`
3. `.ai/document_governance.md`
4. `.ai/project_workspace.md`
5. `.ai/agent_registry.md`
6. `.ai/capabilities.md`
7. `.ai/commit_policy.md`
8. `.ai/task_queue.md`
9. 자기 역할에 맞는 `.ai/agents/*.md`
10. 작업 유형에 맞는 `.ai/workflows/*.md`
11. 프로젝트가 초기화되어 있으면 `.ai_project/current_context.md`와 `.ai_project/tasks/` 문서

## 3. 기본 운영

기본 실행 Agent는 아래 3개다.

- PM Agent
- Development Agent
- QA Agent

AI Ops Agent는 제품 Task 실행 라인 밖에서 운영 프로세스를 점검하는 독립 Agent로 선택 활성화할 수 있다.

- AI Ops Agent

이 구성은 고정 상한이 아니라 시작점이다. 운영 중 반복 부담이나 독립 검토 필요성이 생기면 PM Agent가 새 실행 Agent 추가와 capability 위임을 제안한다. 운영 프로세스 충돌이나 역할 경계 문제는 AI Ops Agent가 별도로 점검한다.

## 4. 저장소 원칙

- `.ai/`: `ai-agent-ops` 템플릿 저장소
- `.ai_project/`: 적용 대상 프로젝트의 Agent 협업 문서
- 적용 대상 프로젝트는 `.ai/`를 `.gitignore`로 제외한다.
- 적용 대상 프로젝트는 기본적으로 `.ai_project/`를 저장소에 포함한다.
- 단, 초기 마이그레이션이나 운영 실험 단계에서는 사용자 결정으로 `.ai_project/`를 로컬 전용으로 둘 수 있다.

## 5. 프로젝트 초기화와 운영 마이그레이션

AI Ops Agent는 사용자가 명시적으로 요청한 경우에만 `.ai_project/` 초기화 또는 운영 마이그레이션을 주도한다.

새 프로젝트 또는 기존 프로젝트에 AI Agent 운영 체계를 도입할 때는 아래 workflow를 따른다.

```text
.ai/workflows/ops_migration.md
```

PM Agent는 제품/일정 영향과 source of truth 최종 판단을 담당하고, 첫 제품 Task는 운영 마이그레이션 이후 `.ai_project/tasks/`에 `proposed` 상태로 등록한다.

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

## 6. Codex 적용

Codex 프로젝트에 적용할 선택 템플릿은 아래 위치에 있다.

```text
.ai/templates/tool_adapters/codex/AGENTS.md
```

## 7. 변경 제한

`.ai/` 운영 문서는 사용자 승인 없이 수정하지 않는다. 변경 절차는 `.ai/document_governance.md`를 따른다.

## 8. 변경 이력

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

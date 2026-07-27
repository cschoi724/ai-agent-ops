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
| `handoff.schema.json` | handoff metadata/message | Role 간 인계 필수 정보 |
| `agent_registry.schema.json` | `.ai_project/agent_registry.md` front matter | Agent, Role, capability 매핑 |
| `operating_model.schema.json` | `.ai_project/operating_model.md` front matter | 프로젝트 운영 모드, workflow, board, ownership 선택값 |

## 단계별 적용

1단계에서는 schema와 template front matter만 추가한다.

2단계에서 `aiops validate`가 이 schema를 실제 검사에 사용한다.

3단계 이후 `aiops task transition`, `aiops handoff validate`가 같은 schema를 상태 전이 guardrail로 사용한다.

## 호환성 원칙

- 기존 Markdown 본문은 유지한다.
- Fast Track은 최소 필드만 요구한다.
- Guided Full은 team, branch/PR, handoff, verification 정보를 더 엄격하게 요구할 수 있다.
- 사용자 커스텀 문서는 migration 단계에서 자동 수정 가능 항목과 사용자 결정 필요 항목으로 분리한다.

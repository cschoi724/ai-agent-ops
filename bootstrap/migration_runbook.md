# Migration Runbook

이 문서는 AI Ops Agent가 기존 프로젝트를 현재 AI Agent Ops core 기준으로 점검하고 갱신할 때 따르는 실행 흐름이다.

## 1. Trigger

사용자가 아래처럼 요청하면 Migration Discovery Phase로 시작한다.

```text
AI Ops migration 진행해줘.
AI Ops migration 점검해줘.
AI Ops v0.6.2 기준으로 기존 프로젝트 마이그레이션해줘.
```

## 2. Discovery Phase

파일을 수정하지 않는다.

먼저 아래 명령으로 현재 상태를 확인한다.

```bash
aiops migrate --target .
```

필요하면 Markdown 계획을 출력한다.

```bash
aiops migrate --target . --plan
```

확인 항목:

- `.ai/` 존재 여부와 설치 방식
- `.ai/VERSION`
- `.ai_project/` 존재 여부
- `.ai_project/operating_model.md`의 `core_version`
- `.ai_project` mode
- Task directory 구조
- `.ai_knowledge/` 존재 여부
- `AGENTS.md` / `CLAUDE.md` adapter drift

## 3. Plan

Agent는 사용자에게 아래 내용을 요약한다.

- 현재 core version
- 프로젝트 기록 core version
- migration 필요 여부
- 자동 적용 가능 항목
- 사용자 결정 필요 항목
- 자동 변경하지 않을 항목
- 예상 영향 범위
- 승인 후 실행할 다음 명령

사용자에게 보여주는 계획은 아래 세 범위를 분리한다.

| 범위 | 의미 | 처리 |
|---|---|---|
| `safe_auto_fix` | 운영 파일/디렉토리 중 자동 보강해도 제품 동작에 영향이 없는 항목 | 승인 후 `migrate --apply` |
| `needs_user_decision` | adapter 문구, schema 채택처럼 기존 결정과 충돌할 수 있는 항목 | 사용자 확인 후 별도 작업 |
| `manual_only` | 제품 코드, 제품 문서, source of truth, Task 상태, branch/PR, commit/push/deploy | 자동 변경 금지 |

승인 질문은 구체적인 파일 범위를 포함해야 한다.

```text
위 Migration Plan 기준으로 아래 파일/디렉토리만 생성 또는 수정해도 될까요?

- .ai_project/operating_model.md
- .ai_project/ops_migration_plan.md
- .ai_project/ops_decisions.md
- .ai_project/ops_issues.md
- .ai_project/tasks/
- .ai_knowledge/
```

## 4. Apply Phase

사용자가 승인한 뒤에만 실행한다.

```bash
aiops migrate --target . --apply
```

초기 자동 적용 범위:

- core version record 추가 또는 갱신
- task directory 생성
- `ops_migration_plan.md` 생성 또는 기록 추가
- `ops_decisions.md` migration 기록 추가
- `ops_issues.md` 생성
- `.ai_knowledge/` minimal 생성

초기 버전에서는 아래 항목을 자동 적용하지 않는다.

- Task metadata 자동 보강
- `AGENTS.md` / `CLAUDE.md` 갱신
- source of truth 재지정
- branch/PR 전략 변경
- 제품 코드 또는 제품 문서 수정
- Git branch, commit, push, PR, merge, deploy

## 5. Verify

`aiops migrate --apply`는 Apply 후 migration-safe verification을 직접 실행한다.

```bash
aiops migrate --target . --apply
```

이 검증은 `.ai/`, `.ai/VERSION`, `.ai_project/operating_model.md`, core version 기록, task directory, migration 기록 문서, `.ai_knowledge/` lint를 확인한다.

`AGENTS.md`와 `CLAUDE.md` adapter drift는 실패가 아니라 `needs_user_decision`으로 보고한다.

검증 실패 시 제품 작업으로 넘어가지 않는다. Agent는 실패 원인, 수정된 운영 파일, 남은 사용자 결정 항목을 보고한다.

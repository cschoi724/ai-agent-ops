# AI Ops Migration Flow Plan

작성일: 2026-07-21  
상태: Temporary working plan  
삭제 기준: migration flow가 정책, runbook, CLI, 테스트, 문서에 반영되면 삭제한다.

## 1. 목표

기존 운영 프로젝트가 새 AI Agent Ops core 버전으로 업데이트되었을 때, 사용자가 절차를 직접 조합하지 않아도 Agent와 CLI가 체계적으로 마이그레이션을 도와주게 한다.

목표 UX:

```text
사용자:
AI Ops migration 진행해줘.

Agent:
1. 현재 상태와 영향 범위를 스캔한다.
2. 수정 전에는 파일을 건드리지 않는다.
3. 자동 적용 가능한 항목과 사용자 결정이 필요한 항목을 분리한다.
4. Migration Plan과 Apply 범위를 제안한다.
5. 사용자가 승인하면 안전 범위만 자동 적용한다.
6. doctor / validate / knowledge lint로 검증한다.
7. 결과와 남은 수동 확인 항목을 보고한다.
```

## 2. 핵심 원칙

- Migration Discovery Phase에서는 파일을 수정하지 않는다.
- Apply Phase는 사용자가 Migration Plan과 파일 수정 범위를 승인한 뒤에만 시작한다.
- 자동 적용은 `.ai_project/`, `.ai_knowledge/`, adapter drift 후보에 한정한다.
- 제품 코드, 제품 문서, source of truth, Task 상태, Role/Agent 매핑, branch/PR 전략은 임의 변경하지 않는다.
- migration은 release / schema / ownership 변경과 같은 순차 gate로 취급한다.
- 적용 후 검증 결과를 보고하고, 남은 위험은 `.ai_project/ops_issues.md` 또는 migration report에 남긴다.

## 3. 사용자 트리거

Agent 트리거:

```text
AI Ops migration 진행해줘.
AI Ops migration 점검해줘.
AI Ops v0.6.2 기준으로 기존 프로젝트 마이그레이션해줘.
```

CLI 후보:

```bash
aiops migrate --target DIR
aiops migrate --target DIR --plan
aiops migrate --target DIR --apply
```

기본 `aiops migrate`는 check only다. 파일을 수정하지 않는다.

## 4. Migration Flow

### Step 1. Detect

확인 항목:

- `.ai/` 존재 여부
- `.ai/VERSION`
- `.ai_project/operating_model.md`의 `core_version`
- `.ai_project` mode: `fast_track` / `guided_full` / `unknown`
- `AGENTS.md`, `CLAUDE.md` adapter drift
- `.ai_knowledge/` 존재 여부
- Task directory 구조

### Step 2. Audit

자동 실행 후보:

```bash
aiops doctor --strict
aiops knowledge lint
aiops validate task FILE
```

Audit 결과는 아래로 분류한다.

```text
blocking:
- doctor strict 실패
- 필수 .ai_project 문서 누락
- guided_full 필수 문서 누락

safe_auto_fix:
- core_version 기록 추가 또는 갱신
- tasks/active, backlog, archive 디렉토리 생성
- ops_migration_plan.md 생성
- ops_issues.md 생성
- ops_decisions.md에 migration 기록 추가
- .ai_knowledge minimal 생성

needs_user_decision:
- .ai_knowledge 생성 여부
- AGENTS.md / CLAUDE.md 최신 template 갱신 여부
- Task metadata placeholder 자동 보강 여부
- source_of_truth 재지정 여부

manual_only:
- 제품 코드 수정
- 제품 Docs 수정
- Task 상태 변경
- Role / Agent 매핑 변경
- branch / PR 전략 확정
- commit / push / deploy
```

### Step 3. Plan

Migration Plan 출력 예:

```text
Migration Plan

Current core: 0.6.2
Project recorded core: 0.6.1
Status: migration_needed

Impact:
- Agent가 읽는 .ai core는 v0.6.2 기준입니다.
- .ai_project는 v0.6.1 기준으로 기록되어 있습니다.
- Task metadata strict 검증이 강화되었습니다.
- .ai_knowledge를 선택적으로 추가할 수 있습니다.

Auto Apply:
- operating_model.md core_version 갱신
- tasks/active, tasks/backlog, tasks/archive 생성
- ops_migration_plan.md 생성 또는 갱신
- ops_decisions.md migration 기록 추가
- .ai_knowledge minimal 생성

Needs Approval:
- AGENTS.md / CLAUDE.md 갱신
- Task metadata placeholder 보강

Will Not Touch:
- product code
- product Docs
- source_of_truth
- Task status
- Role / Agent mapping
- branch / PR strategy
- commit / push / deploy
```

### Step 4. Approve

승인 질문:

```text
위 Migration Plan 기준으로 아래 파일/디렉토리만 생성 또는 수정해도 될까요?

- .ai_project/operating_model.md
- .ai_project/ops_migration_plan.md
- .ai_project/ops_decisions.md
- .ai_project/ops_issues.md
- .ai_project/tasks/
- .ai_knowledge/
```

승인 전에는 파일을 수정하지 않는다.

### Step 5. Apply

초기 자동 적용 범위:

```text
core_version record
task directories
ops_migration_plan.md
ops_decisions.md migration entry
ops_issues.md if needed
.ai_knowledge minimal
```

초기 버전에서는 Task metadata 자동 보강과 adapter 갱신은 적용하지 않는다. Plan에 후보만 표시한다.

### Step 6. Verify

Apply 후 실행:

```bash
aiops doctor --strict
aiops knowledge lint
```

Task 파일이 있으면:

```bash
aiops validate task <task>
```

최종 결과:

```text
Migration Result

status: completed | completed_with_warnings | failed
applied:
warnings:
manual_followups:
verification:
```

## 5. CLI 설계

### `aiops migrate`

기본 check only.

```bash
aiops migrate --target DIR
```

출력:

- current core version
- recorded project core version
- migration status
- safe auto-fix 후보
- user decision 후보
- manual only 항목

### `aiops migrate --plan`

Markdown plan을 출력한다. 파일 수정 없음.

후보 옵션:

```bash
aiops migrate --target DIR --plan
aiops migrate --target DIR --plan --output .ai_project/ops_migration_plan.md
```

초기 버전에서는 `--output`도 쓰기 작업이므로 Agent 승인 후에만 사용한다.

### `aiops migrate --apply`

승인 후 Agent가 실행하는 모드.

```bash
aiops migrate --target DIR --apply
```

자동 적용 범위는 안전 항목만 허용한다.

명령 단독 사용자를 위한 `--yes`는 초기 버전에 넣지 않는다.

## 6. 문서 추가 계획

추가할 문서:

```text
policies/migration_policy.md
bootstrap/migration_runbook.md
templates/ai_project/ops_migration_plan.md 보강
```

README / QUICKSTART에는 긴 절차를 쓰지 않고 링크만 추가한다.

## 7. 테스트 계획

E2E 후보:

```text
tests/e2e_migrate_check_clean.sh
tests/e2e_migrate_version_mismatch.sh
tests/e2e_migrate_apply_safe_fixes.sh
tests/e2e_migrate_no_product_touch.sh
```

검증해야 할 것:

- check mode는 파일을 수정하지 않는다.
- version mismatch를 migration_needed로 분류한다.
- Fast Track optional 문서를 실패로 보지 않는다.
- apply는 허용된 파일/디렉토리만 생성 또는 수정한다.
- product code / Docs는 수정하지 않는다.
- apply 후 doctor와 knowledge lint가 통과한다.

## 8. 작업 순서

### Phase 1. Policy / Runbook

1. `policies/migration_policy.md` 추가
2. `bootstrap/migration_runbook.md` 추가
3. `policies/README.md`, `bootstrap/README.md` 링크 추가
4. `CHANGELOG.md` 다음 버전 섹션 후보 추가

### Phase 2. CLI Check / Plan

1. `aiops migrate --target DIR` 추가
2. migration status 판정
3. safe auto-fix / user decision / manual only 분류 출력
4. `--plan` 출력 추가
5. check/plan E2E 추가

### Phase 3. CLI Apply

1. `--apply` 추가
2. core_version record 추가/갱신
3. task directories 생성
4. ops_migration_plan.md 생성
5. ops_decisions.md migration 기록 추가
6. `.ai_knowledge` minimal 생성 옵션
7. apply E2E 추가

### Phase 4. Agent Adapter Integration

1. Codex `AGENTS.md`에 migration trigger 추가
2. Claude `CLAUDE.md`에 migration trigger 추가
3. 승인 전 파일 수정 금지 기준 명시
4. README / QUICKSTART에 짧은 migration 안내와 링크 추가

### Phase 5. Release

1. `VERSION` patch bump
2. `CHANGELOG.md` 정식 섹션 작성
3. `scripts/test.sh`
4. `aiops release-check --strict`
5. tag / Formula sha / Homebrew tap 갱신

## 9. 초기 범위에서 제외

- Task 상태 자동 전환
- Task metadata 자동 수정
- source of truth 자동 변경
- Role / Agent mapping 자동 변경
- AGENTS.md / CLAUDE.md 자동 overwrite
- Git commit / push / PR 자동 실행
- `aiops migrate --yes`
- 버전별 복잡한 data migration engine

## 10. 완료 기준

- 사용자는 `AI Ops migration 진행해줘` 한 문장으로 시작할 수 있다.
- Agent는 먼저 영향 범위와 Apply 범위를 설명한다.
- 승인 전에는 파일이 수정되지 않는다.
- 승인 후 안전 범위는 자동 적용된다.
- 적용 후 doctor / knowledge lint / task validate 결과가 보고된다.
- 기존 프로젝트의 update risk가 사용자에게 명확하게 보인다.

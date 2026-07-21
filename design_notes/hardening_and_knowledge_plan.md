# AI Ops Hardening And Knowledge Plan

작성일: 2026-07-21
상태: Temporary working plan
삭제 기준: 아래 Phase 작업이 완료되고 관련 내용이 정식 문서, 테스트, CLI에 반영되면 삭제한다.

## 1. 목표

AI Agent Ops를 문서 기반 운영 매뉴얼 수준에서 검증 가능한 AI Agent 운영 하네스로 강화한다.

동시에 LLM Wiki 개념을 `.ai_knowledge/` 계층으로 도입해, Agent가 프로젝트 지식을 빠르게 이해하고 축적할 수 있게 한다.

최종 구조:

```text
.ai/
  운영 헌법, Role, Workflow, Policy

.ai_project/
  프로젝트별 운영 상태, Task, Board, Reports, QA

.ai_knowledge/
  LLM Wiki 기반 프로젝트 지식 요약, 연결, 온보딩, 로그

Docs/ and code
  제품/기술 source of truth
```

## 2. 리뷰 반영 핵심 문제

우선순위가 높은 실제 결함:

- Fast Track은 `branch_pr_strategy.md`, `workflow_overrides.md`를 기본 생성하지 않는데 `doctor`는 두 파일을 필수로 검사한다.
- Task metadata 경고가 `doctor --strict` 실패로 반영되지 않을 수 있다.

구조적 개선 필요:

- seed / doctor / bootstrap / update E2E 테스트가 부족하다.
- CI가 없어 CLI와 템플릿 회귀를 자동 차단하지 못한다.
- Task는 Markdown 계약이라 기계 검증이 약하다.
- Homebrew link mode에서 여러 프로젝트가 core 업데이트 영향을 동시에 받을 수 있다.
- Agent 온보딩에 필요한 문서가 많고 중복이 생기기 쉽다.

## 3. Phase Plan

### Phase 1. Doctor And Validation Hardening

목표: 현재 배포된 CLI의 진단 신뢰도를 먼저 올린다.

작업:

1. `doctor`가 `.ai_project` mode를 인식하게 한다.
2. Fast Track에서는 `branch_pr_strategy.md`, `workflow_overrides.md`, `ops_migration_plan.md`를 optional로 처리한다.
3. Guided Full에서는 상세 문서를 계속 필수로 검사한다.
4. Task metadata 경고를 `warnings`에 반영해 `--strict`가 실패하게 한다.
5. doctor 출력에 mode와 optional 문서 처리 결과를 표시한다.

완료 기준:

- Fast Track 정상 구성은 `doctor --strict` 통과.
- Guided Full 누락 구성은 `doctor --strict` 실패.
- 잘못된 Task metadata는 `doctor --strict` 실패.

### Phase 2. E2E Tests And CI

목표: CLI와 템플릿 회귀를 자동으로 잡는다.

작업:

1. `tests/e2e_seed_doctor.sh`
2. `tests/e2e_fast_track_doctor.sh`
3. `tests/e2e_invalid_task_strict.sh`
4. `scripts/test.sh`
5. `.github/workflows/ci.yml`

완료 기준:

- shell syntax check 통과.
- `bin/aiops release-check --strict` 통과.
- seed / doctor / Fast Track / invalid task E2E 테스트 통과.

### Phase 3. Task Validation v1

목표: Task Markdown을 느슨한 문서에서 검증 가능한 계약으로 발전시킨다.

작업:

1. Task 필수 필드 정의.
2. 상태별 필수 필드 정의.
3. `aiops validate task` 추가.
4. `aiops validate project` 후보 검토.

초기 필수 필드 후보:

```text
id
status
workflow
target_role
required_capabilities
allowed_paths
source_of_truth
report_to
```

상태별 후보:

```text
approved -> allowed_paths, source_of_truth, report_to required
verification_ready -> qa_to required
blocked -> blocker, next_decision required
```

### Phase 4. Core Version Pinning Policy

목표: Homebrew 업데이트와 프로젝트별 운영 안정성의 균형을 잡는다.

작업:

1. `policies/versioning_policy.md` 추가.
2. `.ai_project`에 적용 당시 core version 기록 기준 추가.
3. doctor가 `.ai/VERSION`과 프로젝트 기록 버전 차이를 경고.
4. 중요한 프로젝트에는 `seed --mode copy` 또는 future pin mode를 안내.

완료 기준:

- link mode의 업데이트 리스크가 문서와 doctor에 명확히 드러난다.

### Phase 5. AI Knowledge / LLM Wiki Model

목표: 프로젝트 지식 축적 계층을 운영 하네스에 추가한다.

작업:

1. `models/knowledge_model.md`
2. `policies/knowledge_policy.md`
3. `templates/ai_knowledge/README.md`
4. `templates/ai_knowledge/index.md`
5. `templates/ai_knowledge/log.md`
6. `templates/ai_knowledge/project_brief.md`
7. `templates/ai_knowledge/concepts/_template.md`
8. `templates/ai_knowledge/decisions/_template.md`
9. `templates/ai_knowledge/open_questions/_template.md`

핵심 원칙:

```text
Docs/code = source of truth
.ai_project = operational state
.ai_knowledge = synthesized knowledge
```

`.ai_knowledge`는 source of truth가 아니라 Agent 온보딩과 이해를 돕는 지도다.

### Phase 6. Bootstrap Knowledge Option

목표: 프로젝트 구성 시 Knowledge 계층을 선택할 수 있게 한다.

작업:

1. Fast Track 기본값: 최소 Knowledge 생성 후보.
2. Guided Full 선택지: none / minimal / full.
3. 외부 운영 폴더 사용 시 `.ai_knowledge`도 외부 배치 가능하도록 정책화.

질문 후보:

```text
프로젝트 지식 Wiki를 만들까요?

1. 만들지 않음
2. 최소 Wiki: index, log, project_brief
3. 상세 Wiki: concepts, decisions, architecture, open_questions 포함
```

### Phase 7. Knowledge CLI v0

목표: Wiki 계층을 자동화 가능한 형태로 준비한다.

작업:

1. `aiops knowledge init`
2. `aiops knowledge lint`
3. `aiops knowledge status`

후속 후보:

- `aiops knowledge ingest <file>`
- `aiops knowledge query`

### Phase 8. Documentation Diet

목표: 사용자와 Agent가 매번 읽어야 하는 문서를 줄인다.

작업:

1. `bootstrap_runbook.md`를 핵심 흐름과 상세 appendix로 분리.
2. README는 5분 시작과 포지셔닝 중심 유지.
3. QUICKSTART는 튜토리얼 중심 유지.
4. 상태/Role 설명은 canonical 문서 하나로 수렴.
5. Agent 온보딩은 `.ai_knowledge/index.md`와 `.ai_project/current_context.md` 중심으로 정리.

## 4. Immediate Work Order

현재 브랜치에서 바로 진행할 순서:

1. `fix: doctor strict 검증 정확도 개선`
2. `test: aiops seed와 doctor e2e 테스트 추가`
3. `ci: 기본 검증 워크플로우 추가`
4. `docs: core version pinning 정책 추가`
5. `docs: AI Knowledge 모델과 정책 추가`
6. `feat: knowledge init/lint/status 초안 추가`

## 5. 작업 원칙

- 이 문서는 임시 작업 계획이다.
- 실제 반영된 내용은 정식 문서, CLI, 테스트, CI로 옮긴다.
- 작업 완료 후 이 문서는 삭제한다.
- 각 Phase는 가능하면 독립 커밋으로 나눈다.
- 검증 없는 구조 추가보다 CLI/테스트 신뢰도 개선을 우선한다.

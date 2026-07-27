# Repository Diet Plan

작성일: 2026-07-27
상태: Draft
용도: 저장소 다이어트 작업 계획

이 문서는 AI Ops 저장소의 문서량과 중복을 줄이기 위한 임시 작업 계획이다. 다이어트 완료 후 삭제한다.

## 1. 목표

AI Ops를 처음 쓰는 사용자는 짧은 문서와 CLI만 보고 시작할 수 있어야 한다.

Agent는 실행 중 필요한 최소 runbook과 schema만 읽으면 되어야 한다.

운영자가 세부 정책을 고칠 때만 긴 reference를 보면 된다.

## 2. 현재 문제

현재 문서 구조는 개념 설계가 잘 남아 있지만, 실제 사용자와 Agent 입장에서는 읽어야 할 문서가 많다.

대표적인 대용량 문서:

| 파일 | 대략 줄 수 | 문제 |
|---|---:|---|
| `bootstrap/bootstrap_reference.md` | 1500+ | 질문, 선택지, 예시가 한 파일에 집중 |
| 삭제된 legacy bootstrap policy | 760+ | `bootstrap_reference.md`와 역할이 겹침 |
| `policies/branch_pr_policy.md` | 400+ | 일반 정책과 프로젝트 선택지가 섞임 |
| `runtime/task_queue.md` | 400+ | 상태/큐/Role 라우팅 설명이 많음 |
| `models/team_model.md` | 440+ | 예시와 정책이 섞임 |
| `models/role_model.md` | 380+ | 핵심 Role 기준과 상세 설명이 섞임 |

이미 schema로 옮긴 영역도 있지만, 선택지와 정책 설명은 아직 Markdown reference에 많이 남아 있다.

## 3. 다이어트 원칙

### 3.1 지우는 기준

아래 파일은 삭제 후보로 본다.

- 완료된 작업 계획 문서
- OS 또는 에디터 부산물
- 다른 문서에 흡수된 중복 설명
- CLI나 adapter가 더 이상 참조하지 않는 레거시 문서

### 3.2 schema로 옮기는 기준

아래 정보는 Markdown 설명보다 schema 또는 structured data가 우선이다.

- 선택 가능한 옵션 목록
- 상태값
- 상태 전이
- Role / capability 매핑
- bootstrap 질문 후보
- workflow별 gate와 required fields
- runtime export 계약

### 3.3 Markdown으로 남기는 기준

아래 정보는 Markdown으로 남긴다.

- 헌법과 운영 철학
- 사람이 이해해야 하는 책임 경계
- Agent가 실행 중 읽는 짧은 runbook
- migration, install, release 같은 절차 문서
- 상세 reference 중 아직 schema로 옮기지 않은 설명

## 4. 목표 구조

```text
README.md                 # 짧은 소개
QUICKSTART.md             # 첫 실행 절차

core/                     # 헌법
schemas/                  # 기계 판독 규격
runtime/                  # 실행 중 필요한 짧은 runtime 기준
bootstrap/                # 짧은 runbook + 압축된 reference
models/                   # 핵심 모델 요약
policies/                 # 유지해야 하는 정책 요약
templates/                # 실제 생성되는 템플릿
adapters/                 # 외부 runtime export 계약
docs/                     # 설치/배포 등 사용자 문서
tests/                    # E2E 검증
```

원칙은 “실행 문서는 짧게, 상세 선택지는 schema로, 예시는 template로” 둔다.

## 5. 단계별 작업

## Phase 1. 즉시 정리

목표: 명백한 불필요 파일 제거.

작업:

- `.DS_Store` 제거
- `design_notes/control_plane_improvement_plan.md` 삭제
- 필요하면 `design_notes/repository_diet_plan.md`만 임시 유지

완료 기준:

- `find . -name .DS_Store` 결과 없음
- 완료된 계획 문서가 release package에 포함되지 않음
- `scripts/test.sh` 통과
- `aiops release-check --strict --allow-pending-release` 통과

## Phase 2. Bootstrap 문서 압축

목표: `bootstrap_reference.md`와 legacy bootstrap policy 중복 제거.

작업:

- `bootstrap/bootstrap_runbook.md`는 실행용 짧은 문서로 유지
- `bootstrap/bootstrap_reference.md`는 상세 reference 하나로 통합
- legacy bootstrap policy의 고유 내용만 reference 또는 schema 후보로 이전
- adapter와 template의 참조 경로 갱신

검토 기준:

- AI Ops bootstrap 시작 시 Agent가 먼저 읽는 문서는 `bootstrap_runbook.md`
- 세부 선택지가 필요할 때만 `bootstrap_reference.md`
- legacy bootstrap policy 삭제 여부는 참조 경로 전환 후 결정

완료 기준:

- bootstrap 문서 총량 30% 이상 감소
- Codex/Claude adapter의 bootstrap 지시가 깨지지 않음
- bootstrap 관련 E2E 또는 release-check 통과

## Phase 3. Bootstrap Options Schema화

목표: 질문/선택지/기본값을 Markdown에서 schema 또는 structured data로 이동.

추가 후보:

```text
schemas/bootstrap_options.schema.json
runtime/bootstrap_options.json
```

담을 항목:

- start_context 후보
- readiness_level 후보
- operating_mode 후보
- team_pattern 후보
- workflow_policy 후보
- ownership_model 후보
- coordination 후보
- board_model 후보
- branch_pr 후보
- knowledge_mode 후보

완료 기준:

- Markdown reference는 “설명”만 담당
- 실제 선택 후보는 structured file이 담당
- `aiops bootstrap-guide` 또는 향후 bootstrap helper가 같은 옵션을 읽을 수 있는 구조가 됨

## Phase 4. Model / Policy 압축

목표: 핵심 모델과 정책 문서를 요약 중심으로 줄이고, 중복 설명을 제거.

우선순위:

1. `models/team_model.md`
2. `models/role_model.md`
3. `policies/board_model.md`
4. `policies/coordination_policy.md`
5. `policies/ownership_model.md`
6. `policies/branch_pr_policy.md`

처리 방식:

- 상태값/옵션 목록은 schema 또는 runtime data로 이전
- iOS 같은 긴 예시는 별도 example로 이동하거나 삭제
- 각 문서는 목적, 원칙, 선택 기준, 변경 기준만 남김

완료 기준:

- 각 model/policy 문서는 150~220줄 안쪽을 목표로 함
- `core/constitution.md`와 중복되는 설명 제거
- adapter가 읽어야 할 필수 문서가 줄어듦

## Phase 5. Template 다이어트

목표: 실제 생성 결과가 무겁지 않게 template를 정리.

검토 대상:

- `templates/project_docs/*`
- `templates/ai_project/guided_full/*`
- `templates/tasks/task.md`
- `templates/tasks/handoff_message.md`
- `templates/reports/*`
- `templates/qa/*`

결정 기준:

- bootstrap이 기본으로 생성하지 않는 project docs는 optional template로 유지하거나 축소
- Task template는 schema front matter와 최소 본문 중심으로 축소
- QA/report template는 Role handoff에 필요한 필드만 남김

완료 기준:

- Fast Track 생성 결과가 가볍게 유지됨
- Guided Full은 선택 시에만 상세 문서 생성
- `aiops validate`, `task`, `handoff` 테스트 통과

## Phase 6. Release Package 검토

목표: Homebrew 설치 패키지에 꼭 필요한 파일만 포함.

검토 항목:

- Formula install 대상
- `release-check` required file 목록
- docs와 design_notes 포함 여부
- templates 중 실제 CLI가 쓰는 파일

원칙:

- `design_notes/`는 release package에 포함하지 않는다.
- tests는 개발 저장소에는 유지하지만 Homebrew package 포함 필요성은 별도 검토한다.
- schema, runtime, templates, adapters는 현재 기능에 필요하므로 유지한다.

완료 기준:

- Formula install scope가 명확함
- release-check가 새 구조를 검증함
- Homebrew 설치 후 `aiops doctor`, `validate`, `migrate`, `export runtime`이 동작함

## 6. 삭제 후보 분류

### 바로 삭제 후보

| 파일 | 이유 |
|---|---|
| `.DS_Store` | OS 부산물 |
| `templates/.DS_Store` | OS 부산물 |
| `templates/ai_project/.DS_Store` | OS 부산물 |
| `design_notes/control_plane_improvement_plan.md` | 완료된 임시 개선 계획 |

### 승인 후 삭제 후보

| 파일 | 선행 조건 |
|---|---|
| legacy bootstrap policy | 고유 내용을 `bootstrap_reference.md` 또는 schema로 이전 |
| `design_notes/repository_diet_plan.md` | 다이어트 작업 완료 |

### 유지 후보

| 영역 | 이유 |
|---|---|
| `schemas/` | CLI/CI 검증 기준 |
| `runtime/` | Agent 실행 기준 |
| `templates/tool_adapters/` | Codex/Claude seed 결과 |
| `templates/ai_project/` | bootstrap 생성 결과 |
| `adapters/` | runtime export 계약 |
| `tests/` | release safety |

## 7. 작업 순서 요약

1. OS 부산물과 완료된 계획서 제거
2. bootstrap 문서 중복 제거
3. bootstrap 선택지를 schema/structured data로 이동
4. model/policy 문서 요약
5. template 본문 축소
6. Formula/release-check package 범위 재확인
7. 전체 테스트와 release-check
8. 다이어트 계획 문서 삭제

## 8. 주의사항

- 문서 삭제 전 반드시 `rg`로 참조 경로를 확인한다.
- adapter 문서가 참조하는 파일은 먼저 참조를 바꾼다.
- schema로 옮긴 항목은 CLI나 테스트에서 읽을 수 있는지 확인한다.
- 단순 줄 수 감소보다 “초기 사용자와 Agent가 읽는 문서 수 감소”를 우선한다.

## 9. 실행 가능한 작업 단위

아래 단위대로 진행한다. 각 단위는 별도 커밋을 권장한다.

## Step 1. Cleanup Baseline

목표:

- 기능 영향 없는 파일부터 제거한다.

수정 범위:

```text
.DS_Store
templates/.DS_Store
templates/ai_project/.DS_Store
design_notes/control_plane_improvement_plan.md
```

작업:

1. 위 파일들이 실제로 존재하는지 확인한다.
2. `.DS_Store` 3개를 삭제한다.
3. 완료된 `control_plane_improvement_plan.md`를 삭제한다.
4. `design_notes/repository_diet_plan.md`는 작업 중 유지한다.

검증:

```bash
find . -name .DS_Store
sh scripts/test.sh
bin/aiops release-check --strict --allow-pending-release
```

커밋 메시지:

```text
chore: 저장소 임시 파일 정리
```

완료 판단:

- `.DS_Store`가 더 이상 검색되지 않는다.
- 완료된 개선 계획 문서가 삭제된다.
- 테스트와 release-check가 통과한다.

## Step 2. Bootstrap Reference Audit

목표:

- `bootstrap_reference.md`와 legacy bootstrap policy 중 어느 내용이 중복이고 어느 내용이 고유한지 표로 분리한다.

수정 범위:

```text
design_notes/repository_diet_plan.md
```

작업:

1. 두 파일의 heading 목록을 비교한다.
2. 중복 항목을 표시한다.
3. legacy bootstrap policy에서 반드시 보존할 고유 항목을 표시한다.
4. 삭제 전에 옮겨야 할 내용을 결정한다.

검증:

```bash
rg -n "legacy bootstrap policy|bootstrap_reference" .
```

커밋 메시지:

```text
docs: bootstrap 문서 다이어트 감사 기록
```

완료 판단:

- 어떤 내용을 남기고 옮길지 결정 가능한 audit table이 생긴다.
- 아직 실제 bootstrap 문서는 삭제하지 않는다.

## Step 2 Audit Result

작성일: 2026-07-27

대상:

```text
bootstrap/bootstrap_reference.md
legacy bootstrap policy
```

현재 직접 참조:

| 참조 위치 | 현재 참조 | 판단 |
|---|---|---|
| `bootstrap/bootstrap_reference.md` | legacy bootstrap policy | Step 4에서 자기완결 reference로 바꾸기 |
| `bootstrap/README.md` | legacy bootstrap policy | Step 4에서 삭제 또는 `bootstrap_reference.md`로 교체 |
| `bootstrap/install_runbook.md` | legacy bootstrap policy | 설치 preflight 기준. Step 4에서 `bootstrap_reference.md` 또는 `bootstrap_runbook.md`로 교체 |
| `templates/ai_project/guided_full/source_of_truth.md` | legacy bootstrap policy | source reference를 `bootstrap_reference.md`로 교체 |
| `workflows/ops_migration.md` | legacy bootstrap policy | 운영 구성 선택 기준을 `bootstrap_reference.md` 또는 structured data로 교체 |
| `templates/tool_adapters/codex/AGENTS.md` | `bootstrap_reference.md` | 유지 |
| `templates/tool_adapters/claude/CLAUDE.md` | `bootstrap_reference.md` | 유지 |
| `bootstrap/bootstrap_runbook.md` | `bootstrap_reference.md` | 유지 |

중복/고유 분류:

| 영역 | legacy bootstrap policy | `bootstrap_reference.md` | 판정 | 다음 처리 |
|---|---|---|---|---|
| 목적/원칙 | 1~2장 | 1~3장 | 중복 | `bootstrap_reference.md`의 실행 원칙으로 통합 |
| 구성 산출물 | 3장 | 2장, 22장 | 일부 고유 | 생성 대상과 template source만 `bootstrap_reference.md` 22장에 병합 |
| Bootstrap 단계 | 4장 | 6장, 8~24장 | 중복 | `bootstrap_reference.md` phase 구조 유지 |
| Bootstrap Mode | 4.1장 | 4.1장, 7장, 26.0장 | 중복 | structured data 후보. 설명은 `bootstrap_reference.md` 유지 |
| Start Context | 5장 | 8장, 25장, 26.1장 | 중복 | 후보 목록은 `runtime/bootstrap_options.json`으로 이동 |
| Project Scan | 6장 | 9장 | 중복 | `bootstrap_reference.md` 유지 |
| Readiness | 7장 | 10장, 26.2장 | 중복 | 후보 목록은 structured data로 이동 |
| Operating Mode | 8장 | 11장, 26.3장 | 중복 | 후보 목록은 structured data로 이동 |
| Team 구성 | 9장 | 12장, 26.3장 | 중복 | 선택 후보는 structured data, 설명은 reference 유지 |
| Role / Agent 매핑 | 10장 | 13장, 26.4장 | 중복 | Role 후보는 기존 `models/role_model.md`와 structured data에 연결 |
| Workflow / State | 11장 | 14장, 26.4장 | 중복 | 상태값은 `schemas/workflow.schema.json` / runtime data 우선 |
| Ownership / Coordination | 12장 | 15장, 26.5장 | 중복 | 옵션 후보는 structured data로 이동 |
| Board | 13장 | 16장, 26.6장 | 중복 | 옵션 후보는 structured data로 이동 |
| Branch / PR | 14장 | 17장, 26.7장 | 중복 | 자세한 정책은 `policies/branch_pr_policy.md`, 옵션은 structured data |
| Source of Truth | 15장 | 18장, 26.6장 | 중복 | `bootstrap_reference.md` 유지 |
| 적용 범위 승인 | 16장 | 21장 | 중복 | `bootstrap_reference.md` 유지 |
| 문서 생성 | 17장 | 22장 | 중복 + 일부 고유 | Fast Track/Guided Full 생성 후보를 `bootstrap_reference.md` 하나로 정리 |
| 질문 세트 | 18장 | 26장 | 중복 | `bootstrap_reference.md` 26장 유지 |
| 선택값 기록 규칙 | 19장 | 일부 20~22장 | 고유 | `bootstrap_reference.md`에 `Decision Recording Rules`로 이전 |
| 완료 기준 | 20장 | 28장 | 중복 + 일부 고유 | `bootstrap_reference.md` 28장에 병합 |
| 금지사항 | 21장 | 27장 | 중복 | `bootstrap_reference.md` 유지 |

보존해야 할 고유 내용:

| 내용 | 현재 위치 | 이전 대상 |
|---|---|---|
| `.ai_project/operating_model.md`가 프로젝트별 선택값 인덱스라는 설명 | legacy policy 3장, 19장 | `bootstrap_reference.md` 2장 또는 20장 |
| Fast Track / Guided Full 생성 산출물 구분 | legacy policy 3장, 17장 | `bootstrap_reference.md` 22장 |
| Team별 `.ai_project/teams/<team_id>/` 확장 후보 | legacy policy 3장 | `bootstrap_reference.md` 22장 |
| 선택값 기록 위치 표 | legacy policy 19장 | `bootstrap_reference.md` 신규 `Decision Recording Rules` |
| Bootstrap 완료 기준 중 active Team, branch/PR 또는 Git 비사용 정책 기록 기준 | legacy policy 20장 | `bootstrap_reference.md` 28장 |

삭제 전 필요한 참조 교체:

```text
bootstrap/README.md
bootstrap/install_runbook.md
templates/ai_project/guided_full/source_of_truth.md
workflows/ops_migration.md
bootstrap/bootstrap_reference.md
```

Step 4 예상 결론:

- `bootstrap/bootstrap_runbook.md`: 유지. 실행용 짧은 문서.
- `bootstrap/bootstrap_reference.md`: 유지. 상세 reference이자 legacy policy 고유 내용 흡수 대상.
- legacy bootstrap policy: Step 4에서 삭제 후보.
- `runtime/bootstrap_options.json`: Step 3에서 선택 후보를 구조화한 뒤 reference가 이 파일을 참조하도록 전환.

## Step 3. Bootstrap Options Structured Data

목표:

- bootstrap 선택지를 Markdown 본문에서 분리해 structured data로 만들 준비를 한다.

수정 범위:

```text
schemas/bootstrap_options.schema.json
runtime/bootstrap_options.json
schemas/README.md
bin/aiops
tests/e2e_bootstrap_options_schema.sh
```

작업:

1. `bootstrap_options.schema.json`을 추가한다.
2. `runtime/bootstrap_options.json`에 실제 선택 후보를 넣는다.
3. start_context, readiness_level, operating_mode, team_pattern, workflow_policy, ownership_model, coordination, board_model, branch_pr, knowledge_mode를 포함한다.
4. `scripts/test.sh`의 schema JSON syntax check가 새 schema를 자동 확인하는지 확인한다.
5. 필요하면 `aiops bootstrap-options` 같은 조회 명령은 후속으로 둔다. 이 단계에서는 data와 schema 우선.

검증:

```bash
ruby -rjson -e 'JSON.parse(File.read("schemas/bootstrap_options.schema.json")); JSON.parse(File.read("runtime/bootstrap_options.json"))'
sh scripts/test.sh
```

커밋 메시지:

```text
feat: bootstrap options structured data 추가
```

완료 판단:

- bootstrap 선택 후보가 Markdown이 아니라 JSON에서도 확인 가능하다.
- 기존 bootstrap 동작은 깨지지 않는다.

## Step 4. Bootstrap Document Consolidation

목표:

- bootstrap 실행 문서를 짧게 유지하고, 상세 reference를 하나로 통합한다.

수정 범위:

```text
bootstrap/bootstrap_runbook.md
bootstrap/bootstrap_reference.md
legacy bootstrap policy
templates/tool_adapters/codex/AGENTS.md
templates/tool_adapters/claude/CLAUDE.md
templates/ai_project/guided_full/source_of_truth.md
bootstrap/README.md
bin/aiops
```

작업:

1. `bootstrap_runbook.md`는 실행 순서 중심으로 유지한다.
2. legacy bootstrap policy의 고유 내용을 `bootstrap_reference.md` 또는 `runtime/bootstrap_options.json`으로 옮긴다.
3. 모든 참조 경로를 `bootstrap_reference.md` 기준으로 갱신한다.
4. legacy bootstrap policy를 삭제한다.
5. `release-check` required file 목록에서 삭제된 파일이 있으면 갱신한다.

검증:

```bash
rg -n "<removed bootstrap policy filename>" .
sh scripts/test.sh
bin/aiops release-check --strict --allow-pending-release
```

커밋 메시지:

```text
docs: bootstrap reference 통합
```

완료 판단:

- 삭제된 bootstrap policy 파일명의 직접 참조가 남지 않는다.
- bootstrap 관련 문서 총량이 줄어든다.
- adapter 지시가 여전히 명확하다.

## Step 5. Model Policy Slim Pass

목표:

- 가장 긴 model/policy 문서를 한 번에 모두 지우지 않고, 우선순위대로 줄인다.

수정 범위:

```text
models/team_model.md
models/role_model.md
policies/board_model.md
policies/coordination_policy.md
policies/ownership_model.md
policies/branch_pr_policy.md
```

작업 순서:

1. `models/team_model.md`
2. `models/role_model.md`
3. `policies/board_model.md`
4. `policies/coordination_policy.md`
5. `policies/ownership_model.md`
6. `policies/branch_pr_policy.md`

각 파일 처리 방식:

1. 목적과 핵심 원칙은 유지한다.
2. 길고 구체적인 예시는 삭제하거나 별도 example 후보로 표시한다.
3. schema 또는 runtime data와 중복되는 상태값/옵션 나열은 줄인다.
4. 파일당 150~220줄을 목표로 한다.

검증:

```bash
wc -l models/team_model.md models/role_model.md policies/board_model.md policies/coordination_policy.md policies/ownership_model.md policies/branch_pr_policy.md
sh scripts/test.sh
bin/aiops release-check --strict --allow-pending-release
```

커밋 메시지:

```text
docs: model policy reference 압축
```

완료 판단:

- 각 문서가 짧아졌지만 참조 경로는 유지된다.
- 헌법/런타임 문서와 충돌하는 설명이 줄어든다.

## Step 6. Template Slim Pass

목표:

- 실제 생성되는 템플릿을 가볍게 한다.

수정 범위:

```text
templates/tasks/task.md
templates/tasks/handoff_message.md
templates/reports/task_report.md
templates/qa/qa_report.md
templates/qa/rework_request.md
templates/ai_project/guided_full/*.md
templates/project_docs/*.md
tests/
```

작업:

1. Task template는 front matter와 필수 실행 지시만 유지한다.
2. report/qa template는 검증과 인계 필드 중심으로 축소한다.
3. `templates/project_docs/*`는 optional template로 유지할지 삭제할지 결정한다.
4. Guided Full template는 필요한 경우에만 생성되는 상세 템플릿으로 유지하되 중복 본문을 줄인다.

검증:

```bash
sh scripts/test.sh
bin/aiops release-check --strict --allow-pending-release
```

커밋 메시지:

```text
docs: generated templates 경량화
```

완료 판단:

- Fast Track 결과가 더 가볍다.
- Task/handoff/validate 테스트가 통과한다.

## Step 7. Release Package Scope

목표:

- 배포 패키지에 포함되는 파일 범위를 명확히 한다.

수정 범위:

```text
Formula/ai-agent-ops.rb
bin/aiops
docs/distribution.md
CHANGELOG.md
```

작업:

1. `design_notes/`를 Formula 설치 대상에서 제외하는 원칙을 확인한다.
2. tests 포함 여부를 결정한다.
3. `release-check` required file 목록을 실제 배포 필수 파일 기준으로 조정한다.
4. Homebrew 설치 후 필요한 명령이 모두 동작하는지 확인한다.

검증:

```bash
bin/aiops release-check --strict --allow-pending-release
sh scripts/test.sh
```

커밋 메시지:

```text
chore: release package scope 정리
```

완료 판단:

- Formula 설치 범위와 release-check 기준이 일치한다.
- 작업 계획 문서나 design note가 배포 필수 파일로 취급되지 않는다.

## Step 8. Final Diet Cleanup

목표:

- 다이어트 작업 계획 문서를 삭제하고 최종 상태만 남긴다.

수정 범위:

```text
design_notes/repository_diet_plan.md
CHANGELOG.md
README.md
```

작업:

1. 다이어트 완료 결과를 CHANGELOG에 요약한다.
2. 필요하면 README의 상세 문서 링크를 갱신한다.
3. `design_notes/repository_diet_plan.md`를 삭제한다.

검증:

```bash
find . -name .DS_Store
rg -n "repository_diet_plan|control_plane_improvement_plan|<removed bootstrap policy filename>" .
sh scripts/test.sh
bin/aiops release-check --strict --allow-pending-release
```

커밋 메시지:

```text
chore: repository diet 계획 문서 정리
```

완료 판단:

- 임시 계획 문서가 남지 않는다.
- README/QUICKSTART/CLI만으로 시작 경로가 명확하다.
- release-check warnings가 0이다.

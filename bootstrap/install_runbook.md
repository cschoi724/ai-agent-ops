# Install Runbook

작성일: 2026-07-10  
상태: Draft vNext  
범위: 실제 프로젝트에 `.ai/` 운영체계 템플릿을 설치하는 실행 절차

## 1. 목적

이 문서는 AI Ops Agent가 실제 프로젝트 루트에 `ai-agent-ops` 운영체계 템플릿을 `.ai/`로 설치하는 절차를 정의한다.

Install은 `.ai/`를 준비하는 단계다. Bootstrap은 `.ai_project/`에 프로젝트별 운영 구성을 만드는 단계다. 두 단계는 연결될 수 있지만 같은 단계가 아니다.

```text
Install
  - 공통 운영체계 템플릿을 프로젝트에 배치한다.
  - 출력: .ai/

Bootstrap
  - 프로젝트별 운영 구성을 선택하고 기록한다.
  - 출력: .ai_project/
```

## 2. Seed Trigger

### 2.1 Cold Start

대상 프로젝트에 아직 `.ai/`가 없고 Codex 세션이 ai-agent-ops 원본 경로를 모르면 install runbook을 찾을 수 없다.

이 경우 최초 1회는 `cold_start_prompt.md`의 문장을 사용한다.

```text
AI Ops 시드 구성해줘.
ai-agent-ops 원본 경로는 ../ai-agent-ops-org 이야.
먼저 그 경로의 bootstrap/install_runbook.md를 읽고 Install Discovery만 진행해줘.
아직 파일은 만들거나 수정하지 말고, .ai/ 설치 방식과 적용 범위만 제안해줘.
```

`.ai/` 설치가 끝난 뒤에는 bootstrap을 별도로 시작한다.

```text
AI Ops bootstrap 시작해줘.
```

사용자가 아래 문장을 말하면 AI Ops Agent는 `.ai/` 시드 구성 요청으로 해석한다.

```text
AI Ops 시드 구성해줘.
```

동등한 표현:

```text
AI Ops 템플릿 구성해줘.
.ai 구성해줘.
ai-agent-ops를 이 프로젝트에 시드해줘.
```

Trigger를 받으면 AI Ops Agent는 아래 기본 계약으로 시작한다.

```text
role: AI Ops Agent
mode: Install Discovery
write_permission: no
goal: .ai/ 설치 가능 여부 확인 -> 설치 방식 제안 -> 승인 후 .ai/ 구성
```

첫 응답:

```text
AI Ops 시드 구성을 시작합니다.
먼저 파일은 수정하지 않고 현재 프로젝트와 ai-agent-ops 원본 위치를 확인한 뒤 `.ai/` 설치 방식을 제안하겠습니다.
```

## 3. 핵심 원칙

- Install Discovery에서는 파일을 수정하지 않는다.
- 사용자 승인 전에는 `.ai/`를 생성하지 않는다.
- Install은 `.ai_project/`를 생성하지 않는다.
- Install은 제품 Task, board, branch 전략을 생성하지 않는다.
- Install 완료 후에는 bootstrap 명령을 제안만 한다.
- Bootstrap Apply는 별도 승인으로 진행한다.
- 기존 `.ai/`가 있으면 덮어쓰지 않고 상태를 먼저 보고한다.
- 기존 프로젝트 문서, 코드, Git 설정은 install 단계에서 수정하지 않는다.

## 4. Preflight 확인

AI Ops Agent는 아래 항목을 확인한다.

```text
target_project_path:
is_empty_directory:
git_repository:
existing_ai_dir:
existing_ai_project_dir:
source_template_path:
install_method_candidates:
```

확인할 경로 후보:

```text
./.ai
../ai-agent-ops
../ai-agent-ops-org
../.ai
환경변수 AI_AGENT_OPS_HOME
사용자가 명시한 경로
```

원본 템플릿으로 판단되는 신호:

- `core/constitution.md`가 있다.
- `models/role_model.md`가 있다.
- `bootstrap/project_bootstrap_policy.md`가 있다.
- `bootstrap/bootstrap_runbook.md`가 있다.
- `templates/ai_project/`가 있다.

## 5. 설치 방식

선택 후보:

| 방식 | 설명 | 권장 상황 |
|---|---|---|
| `copy` | 원본 템플릿을 프로젝트의 `.ai/`로 복사 | 기본값, 가장 단순 |
| `symlink` | `.ai/`를 원본 경로에 링크 | 로컬 실험, 원본 변경 즉시 반영 필요 |
| `git_submodule` | 원본 저장소를 submodule로 연결 | 장기 프로젝트, 버전 고정 필요 |
| `local_reference_only` | 설치하지 않고 원본 경로만 참조 | Discovery만 해볼 때 |

초기 기본값:

```text
copy
```

## 6. Install Discovery 출력

파일을 쓰기 전 아래 형식으로 제안한다.

```text
Install Discovery Result

Target Project:
Project State:
Existing .ai:
Existing .ai_project:
Template Source:
Recommended Install Method:
Reason:

Files or directories to create:
- .ai/
- AGENTS.md

Files not touched:
- .ai_project/
- project source files
- project docs
- git config

Next after install:
- AI Ops bootstrap 시작 가능
```

## 7. 승인 게이트

Apply 전에 명시 승인을 받는다.

```text
위 기준으로 이 프로젝트에 `.ai/`를 설치해도 될까요?
이번 시드 구성은 `.ai/`와 `AGENTS.md`만 생성하고 `.ai_project/`는 만들지 않습니다.
```

승인 전 금지:

- `.ai/` 생성
- `AGENTS.md` 생성
- `.ai_project/` 생성
- 프로젝트 코드 수정
- 기존 문서 수정
- Git commit / push

## 8. Apply

승인 후 선택한 설치 방식에 따라 진행한다.

### 8.1 `copy`

원본 템플릿의 운영 문서를 대상 프로젝트의 `.ai/`로 복사한다.

복사 대상:

```text
core/
models/
policies/
runtime/
bootstrap/
agents/
workflows/
templates/
README.md
VERSION
CHANGELOG.md
```

복사하지 않는 항목:

```text
.git/
.ai_project/
design_notes/
개발 중 임시 파일
```

그리고 Codex 진입 지침을 프로젝트 루트에 생성한다.

```text
source: .ai/templates/tool_adapters/codex/AGENTS.md
target: AGENTS.md
```

기존 `AGENTS.md`가 있으면 덮어쓰지 않는다. 이 경우 AI Ops Agent는 병합안을 제안하고 사용자 승인을 받은 뒤에만 수정한다.

### 8.2 `symlink`

대상 프로젝트의 `.ai`를 원본 템플릿 경로로 연결한다.

주의:

- 원본 변경이 모든 연결 프로젝트에 즉시 영향을 준다.
- 장기 프로젝트 기본값으로는 권장하지 않는다.

### 8.3 `git_submodule`

대상 프로젝트의 `.ai`를 submodule로 추가한다.

주의:

- Git 원격 저장소와 submodule 정책이 먼저 필요하다.
- 초기 로컬 실험 기본값으로는 사용하지 않는다.

### 8.4 `local_reference_only`

파일을 설치하지 않고 이번 세션에서만 원본 경로를 참조한다.

주의:

- 다음 세션에서 다시 경로를 알려줘야 할 수 있다.
- `.ai/bootstrap/bootstrap_runbook.md`를 프로젝트 내부 기준으로 사용할 수 없다.

## 9. Post-Install Validation

설치 후 아래를 확인한다.

```text
.ai/README.md
.ai/core/constitution.md
.ai/bootstrap/project_bootstrap_policy.md
.ai/bootstrap/bootstrap_runbook.md
.ai/bootstrap/install_runbook.md
.ai/templates/ai_project/
AGENTS.md
```

출력:

```text
Install Result

installed: yes / no
method:
target:
source:
created:
skipped:
warnings:
next_recommended_command:
```

다음 추천 명령:

```text
AI Ops bootstrap 시작해줘.
```

Bootstrap은 별도 요청으로 시작한다.

## 10. 빈 디렉토리 처리

대상 프로젝트가 빈 디렉토리여도 install은 가능하다.

단, 빈 디렉토리에서는 bootstrap 결과를 확정하지 않는다. 먼저 사용자가 아래 중 하나를 선택해야 한다.

```text
1. 새 프로젝트를 백지에서 탐색한다.
2. 요구사항이 있는 신규 프로젝트로 시작한다.
3. 일단 AI 운영체계만 설치한다.
4. 다른 실제 프로젝트 경로를 지정한다.
```

빈 디렉토리에서 시드 구성 요청을 받은 경우 기본 추천은 `.ai/`만 설치하는 것이다. `.ai_project/` 생성은 사용자가 별도로 `AI Ops bootstrap 시작해줘.`를 요청한 뒤 진행한다.

## 11. 금지사항

- 시드 구성 요청만으로 `.ai_project/`를 생성하지 않는다.
- 시드 구성 요청만으로 `Release Role` 또는 release 폴더를 만들지 않는다.
- 시드 구성 요청만으로 `task_board.md`, `branch_pr_strategy.md`를 만들지 않는다.
- 빈 디렉토리를 바로 `ops_setup_only` 프로젝트로 확정하지 않는다.
- 원본 템플릿 경로가 불명확하면 추측으로 복사하지 않는다.

## 12. 완료 기준

Install은 아래 조건을 만족하면 완료로 본다.

- 대상 프로젝트가 확인되어 있다.
- 원본 템플릿 경로가 확인되어 있다.
- 설치 방식이 선택되어 있다.
- 사용자 승인을 받은 뒤 `.ai/`가 생성되어 있다.
- 사용자 승인을 받은 뒤 `AGENTS.md`가 생성되어 있거나, 기존 `AGENTS.md` 병합안이 제안되어 있다.
- `.ai/bootstrap/bootstrap_runbook.md`와 `.ai/bootstrap/install_runbook.md`가 존재한다.
- `.ai_project/`는 별도 bootstrap 승인 전까지 생성하지 않았다.
- 다음 명령으로 `AI Ops bootstrap 시작해줘.`를 제안했다.

## 13. 변경 이력

| 날짜 | 변경 내용 |
|---|---|
| 2026-07-10 | `.ai/` 설치와 `.ai_project/` bootstrap을 분리하는 install runbook 초안 작성 |
| 2026-07-10 | install과 bootstrap을 별도 명령으로 분리 |

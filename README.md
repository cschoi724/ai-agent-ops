# AI Agent Ops

AI Agent Ops is an **AI Agent Operating Harness**.

Codex, Claude 같은 AI Agent가 프로젝트 안에서 역할, 절차, 검증, 인계, 상태 관리를 지키며 협업하도록 만드는 운영 하네스다.

AI Agent Ops는 Codex 전용 플러그인이나 Claude 전용 프롬프트 팩이 아니다. 여러 Agent 환경에 프로젝트 지침을 심고, 프로젝트별 운영 상태와 지식 계층을 일관된 방식으로 관리한다.

License: MIT

## What It Provides

- `.ai/`: 공통 운영 헌법, Role, Workflow, Policy, Template
- `.ai_project/`: 프로젝트별 운영 상태, Task, Board, Report, QA
- `.ai_knowledge/`: 선택 가능한 LLM Wiki 기반 Agent 온보딩 지식 계층
- `aiops`: seed, doctor, migrate, validate, knowledge, update, release-check CLI
- Codex / Claude adapter templates

## Install

```bash
brew tap cschoi724/tap
brew trust cschoi724/tap
brew install ai-agent-ops
aiops version
```

자세한 설치 방식은 [docs/installation.md](docs/installation.md)를 확인한다.

## 5-Minute Start

AI Ops를 적용할 프로젝트로 이동한다.

```bash
cd /path/to/YourProject
```

Codex와 Claude를 모두 준비하려면:

```bash
aiops seed --adapter both
aiops doctor --strict
aiops bootstrap-guide
```

그 다음 새 Codex 또는 Claude 세션에서 말한다.

```text
AI Ops bootstrap 시작해줘.
```

Bootstrap은 Discovery Phase에서 파일을 수정하지 않는다. Agent가 질문을 하나씩 하고 Decision Stack을 쌓은 뒤, 최종 Operating Model Draft와 Apply 범위를 제안한다. 승인 후에만 `.ai_project/`와 선택 시 `.ai_knowledge/`를 생성한다.

초보자용 전체 절차는 [QUICKSTART.md](QUICKSTART.md)를 확인한다.

## Main Commands

| Command | Purpose |
|---|---|
| `aiops seed --adapter codex` | `.ai`와 `AGENTS.md` 구성 |
| `aiops seed --adapter claude` | `.ai`와 `CLAUDE.md` 구성 |
| `aiops seed --adapter both` | Codex / Claude 둘 다 구성 |
| `aiops doctor --strict` | AI Ops 구성 strict 점검 |
| `aiops migrate --plan` | 기존 프로젝트 운영모델 갱신 계획 확인 |
| `aiops migrate --apply` | 승인된 안전 범위만 운영모델 마이그레이션 적용 |
| `aiops bootstrap-guide` | 현재 상태에 맞는 다음 Agent 입력 안내 |
| `aiops validate task FILE` | Task metadata 검증 |
| `aiops knowledge init --mode minimal` | `.ai_knowledge/` 최소 workspace 생성 |
| `aiops knowledge lint` | Knowledge workspace 점검 |
| `aiops update --check` | core 업데이트 가능 여부 확인 |
| `aiops release-check --strict` | 배포 전 필수 문서와 Formula 상태 점검 |

## Project Layout

적용 대상 프로젝트의 기본 구조:

```text
YourProject/
  .ai/            # AI Agent Ops core 또는 symlink
  AGENTS.md       # Codex adapter
  CLAUDE.md       # Claude adapter
  .ai_project/    # 프로젝트별 운영 상태
  .ai_knowledge/  # 선택: Agent 온보딩용 LLM Wiki
```

역할:

| Path | Role |
|---|---|
| `.ai/` | 운영 헌법과 공통 규칙 |
| `.ai_project/` | 실제 프로젝트 운영 상태와 Task |
| `.ai_knowledge/` | source of truth가 아닌 지식 요약/탐색 지도 |
| 프로젝트 `Docs/`와 코드 | 제품/기술 source of truth |

## Core Safety Rules

- `.ai/` core는 적용 대상 프로젝트에서 임의 수정하지 않는다.
- `.ai_project/`는 프로젝트별 상태만 기록한다.
- `.ai_knowledge/`는 source of truth가 아니다.
- 승인 없는 코드 수정, commit, push, PR, merge, 배포를 하지 않는다.
- Execution Role은 승인된 Task 밖 구현을 하지 않는다.
- Verification Role은 자기 작업을 검증하지 않는다.
- AI Ops Agent는 제품 Task 실행 라인 밖에서 운영모델을 점검한다.

## Documentation

처음 읽을 문서:

1. [QUICKSTART.md](QUICKSTART.md)
2. [docs/installation.md](docs/installation.md)
3. [bootstrap/bootstrap_runbook.md](bootstrap/bootstrap_runbook.md)
4. [core/constitution.md](core/constitution.md)

상세 문서:

- [CHANGELOG.md](CHANGELOG.md): 버전별 패치노트
- [docs/distribution.md](docs/distribution.md): 배포와 Homebrew 기준
- [bootstrap/bootstrap_reference.md](bootstrap/bootstrap_reference.md): bootstrap 상세 질문과 선택지
- [bootstrap/migration_runbook.md](bootstrap/migration_runbook.md): 기존 프로젝트 운영모델 갱신 절차
- [models/role_model.md](models/role_model.md): Role 책임 경계
- [models/knowledge_model.md](models/knowledge_model.md): `.ai_knowledge/` 모델
- [runtime/workflow.md](runtime/workflow.md): workflow 상태 모델
- [runtime/task_queue.md](runtime/task_queue.md): Task Queue 기준
- [policies/versioning_policy.md](policies/versioning_policy.md): core version 기록과 update risk
- [policies/migration_policy.md](policies/migration_policy.md): migration 적용 범위와 금지 범위
- [policies/session_orchestration_policy.md](policies/session_orchestration_policy.md): Agent 세션 분리와 보조 위임 기준

## Status

Current version: `0.6.4`

Homebrew release: `v0.6.4`

AI Agent Ops는 현재 베타 하네스다. 운영 철학과 문서 모델에 더해 CLI 검증, E2E 테스트, CI, Knowledge workspace가 추가되었지만, Git 권한이나 배포 권한 같은 물리적 통제는 프로젝트 환경에서 별도로 유지해야 한다.

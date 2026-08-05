# AI Agent Ops

AI Agent Ops is an **AI Agent Operating Harness**.

Codex, Claude 같은 AI Agent가 프로젝트 안에서 역할, 상태, 승인, 검증, 인계를 남기며 팀처럼 일하도록 만드는 운영 하네스다.

AI Agent Ops는 특정 Agent 전용 프롬프트 팩이 아니다. 프로젝트에 공통 운영 코어를 연결하고, 실제 프로젝트별 상태는 `.ai_project/`에 남긴다.

License: MIT

## Why

AI Agent에게 바로 구현을 맡기면 범위, 책임, 검증, 인계가 흐려지기 쉽다.

AI Agent Ops는 아래 흐름을 강제 가능한 형태로 가까이 가져간다.

```text
seed -> bootstrap -> task -> execution -> verification -> completion
```

## Install

```bash
brew tap cschoi724/tap
brew trust cschoi724/tap
brew install ai-agent-ops
aiops version
```

다른 설치 방식은 [docs/installation.md](docs/installation.md)를 확인한다.

## Quick Start

AI Ops를 적용할 프로젝트로 이동한다.

```bash
cd /path/to/YourProject
aiops seed --adapter both
aiops doctor --strict
aiops bootstrap-guide
```

그 다음 Codex 또는 Claude 새 세션에서 말한다.

```text
AI Ops bootstrap 시작해줘.
```

처음 사용한다면 전체 절차는 [QUICKSTART.md](QUICKSTART.md)를 따라가면 된다.

## What Gets Added

```text
YourProject/
  .ai/            # AI Ops core symlink 또는 copy
  AGENTS.md       # Codex adapter
  CLAUDE.md       # Claude adapter
  .ai_project/    # 프로젝트별 운영 상태
  .ai_knowledge/  # 선택: Agent 온보딩용 지식 계층
```

`.ai/`는 공통 운영 코어다. 프로젝트별 결정, Task, 진행 상태는 `.ai_project/`에 기록한다.

## Core Commands

| Command | Purpose |
|---|---|
| `aiops seed --adapter both` | 프로젝트에 AI Ops core와 Agent adapter 연결 |
| `aiops doctor --strict` | 설치와 운영 구성을 엄격 점검 |
| `aiops project inspect` | 현재 프로젝트 운영 상태를 읽기 전용으로 요약 |
| `aiops project context --role ROLE` | Role Session이 따라야 할 현재 실행 계약 출력 |
| `aiops bootstrap-guide` | 현재 상태에 맞는 다음 Agent 입력 안내 |
| `aiops session-guide` | 운영 구성 이후 열 Role Session 선택 |
| `aiops role prompt ROLE` | Codex/Claude 공통 Role Session 첫 문구 생성 |
| `aiops migrate --plan` | 기존 운영 프로젝트 업데이트 영향 확인 |
| `aiops migrate --apply` | 승인된 안전 범위만 마이그레이션 |
| `aiops validate --strict` | `.ai_project/` schema 검증 |
| `aiops validate workflow-catalog` | workflow catalog와 checkpoint 정책 검증 |
| `aiops task create --title TITLE` | Task 생성 |
| `aiops status-ref` | 공용 상태 기준 ref 확인 |
| `aiops sync-status` | canonical ref fetch/SHA 기록 |
| `aiops task status TASK_ID --source canonical` | 최신 공용 ref 기준 Task 상태 확인 |
| `aiops worktree doctor` | 다중 worktree 상태 진단 |
| `aiops task transition TASK_ID --to STATUS --role ROLE` | 상태 전이 |
| `aiops handoff create TASK_ID --from ROLE --to ROLE --next-action TEXT` | Role 인계 |
| `aiops knowledge init --mode minimal` | `.ai_knowledge/` 생성 |
| `aiops ci init` | 프로젝트용 GitHub Actions 생성 |
| `aiops export runtime` | 외부 runtime adapter용 JSON export |

전체 명령은 `aiops help`를 확인한다.

## Safety Rules

- `.ai/`는 일반 사용자가 직접 수정하지 않는다.
- 프로젝트별 운영 상태는 `.ai_project/`에 남긴다.
- 승인 없는 코드 수정, commit, push, PR, merge, 배포를 하지 않는다.
- Execution Role은 승인된 Task 밖 구현을 하지 않는다.
- Verification Role은 자기 작업을 검증하지 않는다.
- AI Ops Agent는 제품 구현 대신 운영모델을 점검한다.
- 여러 worktree를 쓰는 프로젝트에서는 현재 폴더의 `.ai_project/`를 최신 공용 상태로 가정하지 않고 `canonical_status_ref`를 확인한다.

## More Docs

- [QUICKSTART.md](QUICKSTART.md): 처음 실행 절차
- [docs/installation.md](docs/installation.md): 설치 방식
- [docs/distribution.md](docs/distribution.md): 배포와 Homebrew 기준
- [docs/project_state.md](docs/project_state.md): 프로젝트 상태 조회와 정규화 기준
- [docs/shared_status.md](docs/shared_status.md): 다중 Agent/worktree 상태 동기화
- [bootstrap/bootstrap_runbook.md](bootstrap/bootstrap_runbook.md): bootstrap 실행 흐름
- [bootstrap/migration_runbook.md](bootstrap/migration_runbook.md): 기존 프로젝트 마이그레이션
- [core/constitution.md](core/constitution.md): 운영 헌법
- [models/role_model.md](models/role_model.md): Role 책임
- [runtime/bootstrap_options.json](runtime/bootstrap_options.json): bootstrap 선택 후보 catalog
- [runtime/workflow.md](runtime/workflow.md): 상태 모델
- [runtime/task_queue.md](runtime/task_queue.md): Task 운영 기준
- [runtime/role_handoff.md](runtime/role_handoff.md): Role 인계 기준
- [adapters/README.md](adapters/README.md): 외부 runtime adapter 계약
- [CHANGELOG.md](CHANGELOG.md): 변경 이력

## Status

Current release is tracked in [VERSION](VERSION) and [CHANGELOG.md](CHANGELOG.md).
Installed version can be checked with `aiops version`.

AI Agent Ops는 베타 하네스다. CLI 검증과 CI는 강화되어 있지만, Git 권한이나 배포 권한 같은 물리적 통제는 각 프로젝트 환경에서 별도로 유지해야 한다.

# Quick Start

AI Agent Ops를 처음 쓰는 사용자를 위한 최소 절차다.

## 0. 흐름

```text
install -> seed -> doctor -> bootstrap-guide -> Agent bootstrap -> session-guide -> role prompt
```

| 단계 | 하는 일 | 파일 수정 |
|---|---|---|
| install | `aiops` 명령 설치 | 없음 |
| seed | 프로젝트에 AI Ops 연결 | `.ai`, `AGENTS.md`, `CLAUDE.md` 생성 가능 |
| doctor | 설치 상태 점검 | 없음 |
| bootstrap-guide | 다음 입력 문구 확인 | 없음 |
| Agent bootstrap | 대화로 운영 모델 구성 | 최종 승인 후 `.ai_project/` 생성 |
| session-guide | 어떤 Role 세션을 열지 확인 | 없음 |
| role prompt | 다음 Agent 첫 문구 생성 | 없음 |

## 1. Install

```bash
brew tap cschoi724/tap
brew trust cschoi724/tap
brew install ai-agent-ops
aiops version
```

`aiops version`이 버전을 출력하면 설치는 끝이다.

## 2. Seed

AI Ops를 적용할 프로젝트로 이동한다.

```bash
cd /path/to/YourProject
```

Codex와 Claude를 둘 다 준비한다.

```bash
aiops seed --adapter both
```

생성 결과:

```text
.ai
AGENTS.md
CLAUDE.md
```

Codex만 쓰면 `--adapter codex`, Claude만 쓰면 `--adapter claude`를 사용한다.

## 3. Check

```bash
aiops doctor --strict
```

문제가 없으면 다음으로 넘어간다.

경고가 나오면 `aiops bootstrap-guide`를 실행하기 전에 경고 내용을 먼저 확인한다.

## 4. Bootstrap Guide

```bash
aiops bootstrap-guide
```

이 명령은 현재 폴더 상태를 보고 다음에 Agent에게 입력할 말을 알려준다.

## 5. Start Bootstrap

Codex 또는 Claude 새 세션을 열고 말한다.

```text
AI Ops bootstrap 시작해줘.
```

Agent가 질문을 하나씩 한다. 답변은 Decision Stack에 쌓이고, 마지막에 Operating Model Draft와 적용 범위를 제안한다.

중요한 원칙:

- Discovery 중에는 파일을 수정하지 않는다.
- `.ai_project/`는 최종 Draft 승인 후에만 생성한다.
- 잘 모르겠으면 빠른 시작 방향으로 진행하면 된다.

## 6. After Bootstrap

운영 구성이 끝나면 bootstrap을 다시 시작하지 않는다. 먼저 어떤 Role 세션이 필요한지 확인한다.

```bash
aiops session-guide
```

자주 쓰는 선택 기준:

| 하고 싶은 일 | 열 세션 |
|---|---|
| 제품 방향이나 요구사항 정리 | Direction Role |
| Task 후보, 우선순위, 담당 정리 | Lead Role |
| 승인된 Task 구현 | Execution Role |
| 구현 결과 독립 검증 | Verification Role |
| 완료 처리와 잔여 리스크 판단 | Completion Role |
| 운영모델, 마이그레이션, 정책 점검 | Ops Governance Role |

세션 첫 문구는 직접 쓰기보다 CLI로 만든다.

제품 방향:

```bash
aiops role prompt direction
```

Task 정리:

```bash
aiops role prompt lead
```

구현:

```bash
aiops role prompt execution --task TASK_ID
```

검증:

```bash
aiops role prompt verification --task TASK_ID
```

명령 출력의 `ROLE SESSION PROMPT` 블록을 새 Codex 또는 Claude 세션 첫 메시지로 사용한다.

## 7. Useful Commands

```bash
aiops validate --strict
aiops migrate --plan
aiops knowledge init --mode minimal
aiops ci init
```

기존 프로젝트의 AI Ops 버전 반영이 필요하면 먼저 계획만 확인한다.

```bash
aiops migrate --plan
```

출력된 영향 범위를 보고 승인한 뒤에만 적용한다.

```bash
aiops migrate --apply
```

## Troubleshooting

| 증상 | 해결 |
|---|---|
| `zsh: command not found: tap` | `tap`이 아니라 `brew tap cschoi724/tap`을 입력한다 |
| tap 신뢰 경고 | `brew trust cschoi724/tap` 실행 |
| `aiops` 명령 없음 | Homebrew 설치 후 새 터미널을 열거나 PATH 확인 |
| `.ai_project/`가 없음 | 정상이다. bootstrap 승인 후 생성된다 |
| Agent가 일반 답변만 함 | 새 세션에서 `AI Ops bootstrap 시작해줘.`를 다시 입력 |
| bootstrap이 이미 끝난 프로젝트에서 또 bootstrap을 묻는지 헷갈림 | `aiops bootstrap-guide` 후 `aiops session-guide`를 사용한다 |
| 다음 Agent에게 뭐라고 넘길지 모르겠음 | `aiops handoff create TASK_ID --from ROLE --to ROLE --next-action TEXT` 사용 |

## Next Docs

- 설치 상세: [docs/installation.md](docs/installation.md)
- Bootstrap 상세: [bootstrap/bootstrap_runbook.md](bootstrap/bootstrap_runbook.md)
- 기존 프로젝트 마이그레이션: [bootstrap/migration_runbook.md](bootstrap/migration_runbook.md)
- Role 책임: [models/role_model.md](models/role_model.md)
- Role 인계: [runtime/role_handoff.md](runtime/role_handoff.md)

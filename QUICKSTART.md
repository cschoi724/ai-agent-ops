# Quick Start: 5분 시작

이 문서는 AI Agent Ops를 처음 사용하는 사람이 기존 프로젝트나 빈 폴더에 운영체계를 붙이는 최소 절차다. 어려운 운영 개념은 나중에 봐도 된다.

## 전체 흐름

```text
install -> seed -> doctor -> bootstrap-guide -> bootstrap
```

역할:

| 단계 | 하는 일 | 파일 수정 |
|---|---|---|
| install | `aiops` 명령 설치 | 대상 프로젝트 수정 없음 |
| seed | 대상 프로젝트에 Agent 진입 지침 연결 | `.ai`, `AGENTS.md`, `CLAUDE.md` 생성 가능 |
| doctor | 구성이 맞는지 점검 | 없음 |
| bootstrap-guide | 다음 Agent 입력 문구 확인 | 없음 |
| bootstrap | 대화로 운영 모델 결정 | 최종 승인 후 `.ai_project/` 생성 |

## 1. Install

Homebrew로 설치한다.

```bash
brew tap cschoi724/tap
brew trust cschoi724/tap
brew install ai-agent-ops
aiops version
```

`brew tap`은 설치 저장소를 등록한다. `brew trust`는 외부 tap Formula 실행을 허용한다. `brew install`은 `aiops` 전역 명령을 설치한다.

정상 설치 확인:

```bash
aiops version
```

## 2. Seed

AI Ops를 적용할 프로젝트 폴더로 이동한다.

```bash
cd /path/to/YourProject
```

어떤 Agent를 쓸지 고른다.

Codex만 쓸 때:

```bash
aiops seed --adapter codex
```

Claude만 쓸 때:

```bash
aiops seed --adapter claude
```

둘 다 쓸 때:

```bash
aiops seed --adapter both
```

처음이면 `both`를 추천한다. Codex와 Claude 중 어느 쪽으로 시작해도 같은 운영 규칙을 읽게 된다.

생성되는 것:

```text
.ai -> /path/to/ai-agent-ops
AGENTS.md   # codex 또는 both
CLAUDE.md   # claude 또는 both
```

Seed 단계에서는 `.ai_project/`를 만들지 않는다.

## 3. Doctor Check

구성이 맞는지 확인한다.

```bash
aiops doctor
```

경고까지 실패로 처리하려면:

```bash
aiops doctor --strict
```

처음 검증할 때는 `--strict`를 추천한다. 경고까지 실패로 처리하므로 빠진 항목을 찾기 쉽다.

## 4. Bootstrap Guide

다음 단계 안내를 CLI로 확인할 수 있다.

```bash
aiops bootstrap-guide
```

이 명령은 지금 프로젝트가 어떤 상태인지 보고, Agent에게 어떤 말을 하면 되는지 알려준다.

## 5. Bootstrap With Agent

Codex 또는 Claude 세션을 새로 열고 말한다.

```text
AI Ops bootstrap 시작해줘.
```

Agent가 먼저 시작 방식을 물어본다.

처음 쓰거나 복잡한 설정을 피하고 싶으면 `빠른 시작`을 선택한다.

```text
빠른 시작
```

빠른 시작은 쉬운 질문 몇 개만으로 아래 안전 기본값을 제안한다.

```text
한 개 Team
단일 작업 흐름
Release Role 비활성
Git/PR은 필요할 때 결정
```

세부 설정을 직접 고르고 싶으면 `세부 설정`을 선택한다.

```text
세부 설정
```

Agent는 바로 파일을 만들지 않는다. 먼저 질문을 하나씩 하고, 답변을 Decision Stack에 쌓은 뒤 최종 Operating Model Draft를 제안한다.

승인 전에는 `.ai_project/`를 생성하거나 수정하지 않는 것이 기본 원칙이다.

## 6. First Agent Session

Bootstrap이 끝나면 실제 작업은 Role을 붙여 시작한다.

기획이나 제품 방향을 잡을 때:

```text
너는 PM Agent / Direction Role이야.
현재 .ai_project를 읽고 제품 방향 정리를 시작해줘.
```

Task를 정리하고 담당자를 나눌 때:

```text
너는 Lead Agent / Lead Role이야.
현재 board를 읽고 다음 Task 후보와 담당 Role을 정리해줘.
```

구현할 때:

```text
너는 Development Agent / Execution Role이야.
승인된 Task를 확인하고 진행해줘.
```

검증할 때:

```text
너는 QA Agent / Verification Role이야.
검증 대기 Task를 검증해줘.
```

## Update

로컬 git checkout으로 설치했다면 업데이트 가능 여부를 확인할 수 있다.

```bash
aiops update --check
```

실제 업데이트는 core에 local changes가 없을 때만 진행한다.

```bash
aiops update
```

Homebrew로 설치했다면 일반적인 업데이트는 Homebrew가 맡는다.

```bash
brew update
brew upgrade ai-agent-ops
```

## 문제가 생기면

| 증상 | 확인할 것 |
|---|---|
| `zsh: command not found: tap` | `tap`이 아니라 `brew tap cschoi724/tap`을 입력해야 한다 |
| tap이 신뢰되지 않았다고 나옴 | `brew trust cschoi724/tap` 실행 |
| 이미 설치됐다고 나옴 | `aiops version`으로 버전 확인 또는 `brew reinstall ai-agent-ops` |
| `.ai_project/`가 없음 | 정상이다. bootstrap 최종 승인 후 생성된다 |
| Agent가 일반 프로젝트처럼 답함 | `aiops bootstrap-guide` 결과를 확인하고 새 세션에서 `AI Ops bootstrap 시작해줘.` 입력 |

## 핵심 규칙

- `.ai/`는 운영체계 코어다. 프로젝트에서 직접 수정하지 않는다.
- 프로젝트별 설정과 상태는 `.ai_project/`에 기록한다.
- Role 밖 작업을 하지 않는다.
- 승인 없는 코드 수정, commit, push, 배포를 하지 않는다.
- AI Ops Agent는 제품 Task를 직접 수행하지 않는다.

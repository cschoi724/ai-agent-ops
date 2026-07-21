# Installation

작성일: 2026-07-10  
상태: Draft vNext

## 1. 목표

AI Agent Ops는 최종적으로 패키지 매니저로 설치할 수 있는 운영체계 코어를 목표로 한다.

처음 사용하는 사람은 `QUICKSTART.md`의 5분 시작 흐름을 먼저 따른다. 이 문서는 설치 방식과 디렉토리 구조를 더 자세히 설명하는 레퍼런스다.

초기 구조:

```text
ai-agent-ops/
  bin/aiops
  core/
  models/
  policies/
  runtime/
  bootstrap/
  templates/
```

대상 프로젝트:

```text
YourProject/
  .ai -> /path/to/ai-agent-ops
  AGENTS.md or CLAUDE.md
  .ai_project/
```

## 2. Homebrew 설치

권장 설치 방식은 Homebrew tap이다.

```bash
brew tap cschoi724/tap
brew trust cschoi724/tap
brew install ai-agent-ops
aiops version
```

Homebrew 6에서는 외부 tap Formula 실행 전에 trust가 필요할 수 있다.

명령별 의미:

| 명령 | 의미 |
|---|---|
| `brew tap cschoi724/tap` | AI Agent Ops Formula가 있는 tap 등록 |
| `brew trust cschoi724/tap` | 외부 tap Formula 실행 허용 |
| `brew install ai-agent-ops` | `aiops` 전역 명령 설치 |
| `aiops version` | 설치된 CLI 버전 확인 |

## 3. 로컬 checkout 설치

저장소의 CLI를 직접 실행할 수도 있다.

```bash
/path/to/ai-agent-ops/bin/aiops seed --adapter codex
```

전역 명령처럼 쓰고 싶으면 PATH 안에 symlink를 둔다.

```bash
mkdir -p ~/.local/bin
ln -s /path/to/ai-agent-ops/bin/aiops ~/.local/bin/aiops
aiops version
```

자세한 배포와 전역 등록 기준은 `docs/distribution.md`를 따른다.

## 4. Seed Mode

Codex:

```bash
aiops seed --adapter codex
```

Claude:

```bash
aiops seed --adapter claude
```

Codex와 Claude:

```bash
aiops seed --adapter both
```

기본값은 link다.

```bash
aiops seed --mode link
```

결과:

```text
.ai -> /path/to/ai-agent-ops
```

복사본이 필요하면 copy를 사용한다.

```bash
aiops seed --mode copy
```

## 5. Doctor

```bash
aiops doctor
```

확인 항목:

- `.ai` 존재 여부
- `.ai`가 symlink인지 또는 프로젝트 로컬 복사본인지
- 핵심 runbook 존재 여부
- `AGENTS.md` 또는 `CLAUDE.md` 존재 여부
- `.ai_project/` 존재 여부
- `.ai_project` 필수 문서 존재 여부
- Adapter 진입 지침이 템플릿과 다른지 여부
- verification 대기 Task의 QA 보고서 상태
- core version

경고까지 실패로 처리하려면 strict 모드를 사용한다.

```bash
aiops doctor --strict
```

## 6. Bootstrap Guide

seed와 doctor가 끝난 뒤 다음 Agent 세션에서 무엇을 입력해야 하는지 확인한다.

```bash
aiops bootstrap-guide
```

이 명령은 파일을 수정하지 않는다. `.ai/`, adapter 파일, `.ai_project/` 존재 여부를 확인하고 다음 단계 문구를 안내한다.

일반적인 첫 설치 흐름은 아래 순서다.

```bash
aiops seed --adapter both
aiops doctor --strict
aiops bootstrap-guide
```

그 다음 새 Agent 세션에서 말한다.

```text
AI Ops bootstrap 시작해줘.
```

bootstrap은 Discovery와 Decision Stack 확인을 먼저 진행하고, 최종 Operating Model Draft 승인 후에만 `.ai_project/`를 만든다.

## 7. Update

로컬 git checkout 기반 core는 CLI로 갱신할 수 있다.

```bash
aiops update --check
aiops update
```

`aiops update`는 core에 local changes가 있으면 중단한다. Homebrew 또는 복사 설치는 직접 수정하지 않고 갱신 방법만 안내한다.

업데이트 후 대상 프로젝트에서 확인한다.

```bash
aiops doctor --target /path/to/YourProject --strict
```

## 8. Homebrew 설치 구조

설치:

```bash
brew tap cschoi724/tap
brew trust cschoi724/tap
brew install ai-agent-ops
cd YourProject
aiops seed --adapter codex
```

설치 후 구조:

```text
/opt/homebrew/bin/aiops
/opt/homebrew/opt/ai-agent-ops/libexec/
YourProject/.ai -> /opt/homebrew/opt/ai-agent-ops/libexec
```

## 9. Read-only Core 방향

`.ai/`는 운영체계 코어다. 프로젝트별 설정과 상태는 `.ai_project/`에 둔다.

강한 보호가 필요하면 core를 프로젝트 밖 경로에 설치하고 `.ai`를 symlink로 연결한다.

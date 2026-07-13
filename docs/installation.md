# Installation

작성일: 2026-07-10  
상태: Draft vNext

## 1. 목표

AI Agent Ops는 최종적으로 패키지 매니저로 설치할 수 있는 운영체계 코어를 목표로 한다.

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

## 2. 현재 설치 방식

저장소의 CLI를 직접 실행한다.

```bash
/path/to/ai-agent-ops/bin/aiops seed --adapter codex
```

Claude:

```bash
/path/to/ai-agent-ops/bin/aiops seed --adapter claude
```

Codex와 Claude:

```bash
/path/to/ai-agent-ops/bin/aiops seed --adapter both
```

## 3. Seed Mode

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

## 4. Doctor

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

## 5. Bootstrap Guide

seed와 doctor가 끝난 뒤 다음 Agent 세션에서 무엇을 입력해야 하는지 확인한다.

```bash
aiops bootstrap-guide
```

이 명령은 파일을 수정하지 않는다. `.ai/`, adapter 파일, `.ai_project/` 존재 여부를 확인하고 다음 단계 문구를 안내한다.

## 6. Homebrew 목표 구조

향후 목표:

```bash
brew install cschoi724/tap/ai-agent-ops
cd YourProject
aiops seed --adapter codex
```

설치 후 구조:

```text
/opt/homebrew/bin/aiops
/opt/homebrew/share/ai-agent-ops/
YourProject/.ai -> /opt/homebrew/share/ai-agent-ops
```

## 7. Read-only Core 방향

`.ai/`는 운영체계 코어다. 프로젝트별 설정과 상태는 `.ai_project/`에 둔다.

강한 보호가 필요하면 core를 프로젝트 밖 경로에 설치하고 `.ai`를 symlink로 연결한다.

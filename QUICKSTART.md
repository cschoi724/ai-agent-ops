# Quick Start

이 문서는 AI Agent Ops를 처음 사용하는 사람이 프로젝트에 운영체계를 구성하는 최소 절차다.

## 1. 설치

Homebrew로 설치한다.

```bash
brew tap cschoi724/tap
brew trust cschoi724/tap
brew install ai-agent-ops
aiops version
```

Homebrew를 쓰지 않으면 저장소를 로컬에 두고 직접 실행할 수 있다.

```text
ai-agent-ops/
```

대상 프로젝트로 이동한다.

```text
cd YourProject
```

## 2. Seed

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

생성되는 것:

```text
.ai -> /path/to/ai-agent-ops
AGENTS.md   # codex 또는 both
CLAUDE.md   # claude 또는 both
```

Seed 단계에서는 `.ai_project/`를 만들지 않는다.

## 3. Doctor

구성이 맞는지 확인한다.

```bash
aiops doctor
```

경고까지 실패로 처리하려면:

```bash
aiops doctor --strict
```

## 4. Bootstrap

다음 단계 안내를 CLI로 확인할 수 있다.

```bash
aiops bootstrap-guide
```

Agent 세션을 열고 말한다.

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

## 5. Update

로컬 git checkout으로 설치했다면 업데이트 가능 여부를 확인할 수 있다.

```bash
aiops update --check
```

실제 업데이트는 core에 local changes가 없을 때만 진행한다.

```bash
aiops update
```

## 6. Role별 작업

Bootstrap 이후에는 Role을 부여해서 작업한다.

```text
너는 PM Agent / Lead Role이야.
다음 Task 후보를 정리해줘.
```

```text
너는 Development Agent / Execution Role이야.
승인된 Task를 확인하고 진행해줘.
```

```text
너는 QA Agent / Verification Role이야.
검증 대기 Task를 검증해줘.
```

## 7. 핵심 규칙

- `.ai/`는 운영체계 코어다. 프로젝트에서 직접 수정하지 않는다.
- 프로젝트별 설정과 상태는 `.ai_project/`에 기록한다.
- Role 밖 작업을 하지 않는다.
- 승인 없는 코드 수정, commit, push, 배포를 하지 않는다.
- AI Ops Agent는 제품 Task를 직접 수행하지 않는다.

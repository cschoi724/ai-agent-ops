# Quick Start

이 문서는 AI Agent Ops를 처음 사용하는 사람이 프로젝트에 운영체계를 구성하는 최소 절차다.

## 1. 준비

현재 저장소를 로컬에 둔다.

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
/path/to/ai-agent-ops/bin/aiops seed --adapter codex
```

Claude만 쓸 때:

```bash
/path/to/ai-agent-ops/bin/aiops seed --adapter claude
```

둘 다 쓸 때:

```bash
/path/to/ai-agent-ops/bin/aiops seed --adapter both
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
/path/to/ai-agent-ops/bin/aiops doctor
```

경고까지 실패로 처리하려면:

```bash
/path/to/ai-agent-ops/bin/aiops doctor --strict
```

## 4. Bootstrap

Agent 세션을 열고 말한다.

```text
AI Ops bootstrap 시작해줘.
```

Agent는 바로 파일을 만들지 않는다. 먼저 질문을 하나씩 하고, 답변을 Decision Stack에 쌓은 뒤 최종 Operating Model Draft를 제안한다.

## 5. Role별 작업

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

## 6. 핵심 규칙

- `.ai/`는 운영체계 코어다. 프로젝트에서 직접 수정하지 않는다.
- 프로젝트별 설정과 상태는 `.ai_project/`에 기록한다.
- Role 밖 작업을 하지 않는다.
- 승인 없는 코드 수정, commit, push, 배포를 하지 않는다.
- AI Ops Agent는 제품 Task를 직접 수행하지 않는다.

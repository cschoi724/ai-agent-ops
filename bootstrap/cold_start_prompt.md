# Cold Start Prompt

작성일: 2026-07-10  
상태: Draft vNext  
범위: `.ai/`가 아직 없는 프로젝트에서 AI Ops를 처음 시작하는 최소 프롬프트

## 1. 목적

이 문서는 대상 프로젝트에 아직 `.ai/`가 없고 Codex가 AI Ops 지침을 모르는 상태에서, 최초 1회만 사용할 시작 문장을 정의한다.

`.ai/`가 설치된 뒤에는 아래 문장만 사용한다.

```text
AI Ops bootstrap 시작해줘.
```

## 2. 왜 필요한가

빈 프로젝트 또는 아직 AI Ops가 설치되지 않은 프로젝트에는 아래 문서가 없다.

```text
.ai/bootstrap/install_runbook.md
.ai/bootstrap/bootstrap_runbook.md
AGENTS.md
```

따라서 새 Codex 세션은 install runbook의 위치를 알 수 없다. 최초 1회는 ai-agent-ops 원본 경로를 알려줘야 한다.

## 3. 기본 Cold Start 문장

대상 프로젝트 루트에서 아래처럼 말한다.

```text
AI Ops 시드 구성해줘.
ai-agent-ops 원본 경로는 ../ai-agent-ops-org 이야.
먼저 그 경로의 bootstrap/install_runbook.md를 읽고 Install Discovery만 진행해줘.
아직 파일은 만들거나 수정하지 말고, .ai/ 설치 방식과 적용 범위만 제안해줘.
```

원본 경로가 다른 경우 `../ai-agent-ops-org`만 실제 경로로 바꾼다.

예:

```text
AI Ops 시드 구성해줘.
ai-agent-ops 원본 경로는 /Users/annyeongjelly/Desktop/Projects/Dev/ai-agent-ops-org 이야.
먼저 그 경로의 bootstrap/install_runbook.md를 읽고 Install Discovery만 진행해줘.
아직 파일은 만들거나 수정하지 말고, .ai/ 설치 방식과 적용 범위만 제안해줘.
```

## 4. 기대 응답

정상적인 세션은 아래처럼 반응해야 한다.

```text
AI Ops 시드 구성을 Install Discovery로 시작합니다.
먼저 파일은 수정하지 않고 현재 프로젝트와 ai-agent-ops 원본 위치를 확인한 뒤 `.ai/` 설치 방식을 제안하겠습니다.
```

그리고 아래 항목을 제안해야 한다.

```text
Target Project:
Template Source:
Existing .ai:
Existing .ai_project:
Recommended Install Method:
Files or directories to create:
Files not touched:
Next after install:
```

## 5. 승인 후 흐름

사용자가 `.ai/` 설치를 승인하면 AI Ops Agent는 `.ai/`만 생성한다.

설치 후 아래처럼 물어야 한다.

```text
`.ai/` 설치가 완료되었습니다.
다음 단계는 `AI Ops bootstrap 시작해줘.`입니다.
```

Bootstrap은 별도 요청으로 시작한다. 이 단계에서도 파일을 수정하지 않고 Operating Model Draft까지만 제안한다.

## 6. 설치 이후부터

대상 프로젝트에 `.ai/`가 설치된 뒤에는 더 이상 cold start 문장이 필요 없다.

이후 세션에서는 아래 한 줄만 사용한다.

```text
AI Ops bootstrap 시작해줘.
```

## 7. 금지사항

- Cold Start 단계에서 `.ai_project/`를 만들지 않는다.
- Cold Start 단계에서 제품 Task를 만들지 않는다.
- Cold Start 단계에서 Git commit, push, PR을 만들지 않는다.
- 원본 경로가 확인되지 않으면 추측으로 설치하지 않는다.

## 8. 변경 이력

| 날짜 | 변경 내용 |
|---|---|
| 2026-07-10 | `.ai/`가 없는 프로젝트 최초 1회용 cold start prompt 추가 |

# AI Agent Ops

AI Agent Operating Harness

작성일: 2026-07-10  
상태: Draft vNext  
범위: 프로젝트별 AI Agent 운영 하네스

## What Is This

AI Agent Ops는 Codex, Claude 같은 AI Agent가 프로젝트 안에서 역할, 절차, 검증, 인계를 지키며 협업하도록 만드는 AI 에이전트 운영 하네스다.

이 저장소는 특정 제품의 코드가 아니라, 여러 프로젝트에 적용할 수 있는 운영 코어와 CLI를 제공한다. 역할, 권한, 작업 상태, 검증, 인계, 프로젝트별 운영 상태를 문서와 명령어로 관리한다.

AI Agent Ops는 Codex 전용 플러그인이나 Claude 전용 프롬프트 팩이 아니다. 여러 Agent 환경에 프로젝트 지침을 심고, 프로젝트별 운영 상태를 일관된 방식으로 관리하는 도구 중립적인 operating harness다.

핵심 목표는 아래와 같다.

- AI Agent가 Role 밖 행동을 하지 않게 한다.
- 제품 방향, Task, 검증, 완료 판단을 한 흐름으로 관리한다.
- `.ai/` 공통 운영 규칙과 `.ai_project/` 프로젝트별 운영 상태를 분리한다.
- 초보자도 질문에 답하면서 프로젝트 운영체계를 구성할 수 있게 한다.
- 핵심 헌법, Role 경계, 승인 규칙을 쉽게 깨지 않게 한다.

License: MIT

## Core Idea

적용 대상 프로젝트에서는 아래 구조를 사용한다.

```text
YourProject/
  .ai/           # AI Agent Ops 공통 운영체계 템플릿
  AGENTS.md      # Codex가 읽는 프로젝트 진입 지침
  .ai_project/   # 이 프로젝트의 실제 운영 상태와 Task
  ...
```

역할 분리:

| 위치 | 역할 |
|---|---|
| `.ai/` | 헌법, 모델, 정책, workflow, 템플릿 |
| `AGENTS.md` | Codex 세션이 읽는 현재 프로젝트 지침 |
| `.ai_project/` | 프로젝트별 운영 모델, Agent 매핑, Task, 보고서 |

## 5-Minute Start

처음 쓰는 경우에는 아래 순서만 따르면 된다.

### 1. Install

```bash
brew tap cschoi724/tap
brew trust cschoi724/tap
brew install ai-agent-ops
aiops version
```

`brew trust cschoi724/tap`은 외부 tap Formula 실행을 허용하는 Homebrew 안전 절차다.

### 2. Seed Target Project

AI Ops를 적용할 프로젝트 폴더로 이동한다.

```bash
cd /path/to/YourProject
```

Codex만 쓰면:

```bash
aiops seed --adapter codex
```

Claude만 쓰면:

```bash
aiops seed --adapter claude
```

둘 다 쓰거나 아직 정하지 못했으면:

```bash
aiops seed --adapter both
```

승인 후 생성되는 것:

```text
.ai -> /path/to/ai-agent-ops
AGENTS.md or CLAUDE.md
```

이 단계에서는 `.ai_project/`를 만들지 않는다. `.ai/`는 공통 운영체계 코어를 가리키고, `AGENTS.md`와 `CLAUDE.md`는 각 Agent 세션의 진입 지침이다.

### 3. Check

```bash
aiops doctor --strict
```

문제가 있으면 메시지에 나온 항목만 먼저 고치면 된다. 일반적인 확인만 필요하면 `aiops doctor`를 사용할 수 있다.

### 4. Open Bootstrap Guide

```bash
aiops bootstrap-guide
```

이 명령은 파일을 수정하지 않고, 현재 프로젝트가 다음에 무엇을 해야 하는지 알려준다.

### 5. Start Bootstrap With Agent

새 Codex 또는 Claude 세션을 열고 아래 한 줄을 말한다.

```text
AI Ops bootstrap 시작해줘.
```

Agent는 먼저 Discovery를 진행하고, 파일을 수정하지 않은 상태에서 시작 방식을 물어본다.

처음 쓰거나 쉽게 시작하고 싶으면 `빠른 시작`을 선택한다. Fast Track은 한 개 Team, 단일 작업 흐름, Release Role 비활성, Git/PR 보류 같은 안전 기본값으로 시작한다. 필요한 경우 나중에 Team, Role, Workflow, Branch 전략을 확장한다.

세부 설정을 직접 비교하면서 고르고 싶으면 `세부 설정`을 선택한다.

Bootstrap은 바로 전체 결과를 만들지 않는다. Codex는 질문을 하나씩 하고, 사용자의 답변을 Decision Stack에 쌓은 뒤, 충분한 결정값이 모이면 최종 Operating Model Draft를 제안한다.

승인 후 생성되는 것:

```text
.ai_project/
  operating_model.md
  agent_registry.md
  source_of_truth.md
  task_board.md
  branch_pr_strategy.md
  workflow_overrides.md
  ops_decisions.md
  ops_issues.md
  tasks/
  reports/
  qa/
```

## After Bootstrap

Bootstrap 이후에는 세션마다 Role을 부여해서 진행한다.

예:

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

## Safe Defaults

AI Agent Ops는 아래 기본 안전 규칙을 가진다.

- `.ai/` 운영 문서는 적용 대상 프로젝트에서 임의 수정하지 않는다.
- `.ai_project/`는 프로젝트별 상태만 기록한다.
- 제품 Task는 운영 구성이 확정된 뒤에만 만든다.
- Role 밖 행동은 하지 않는다.
- 승인 없는 코드 수정, Git commit, push, PR, merge, 배포는 하지 않는다.
- Execution Role은 승인된 Task 밖 구현을 하지 않는다.
- Verification Role은 자기 작업을 검증하지 않는다.
- Release Role은 실제 배포 책임이 생기기 전까지 비활성이다.
- AI Ops Agent는 제품 Task 실행 라인 밖에서 운영모델을 점검한다.

## Main Triggers

| Trigger | 의미 |
|---|---|
| `aiops seed --adapter codex` | 프로젝트에 `.ai`와 `AGENTS.md`를 구성 |
| `aiops seed --adapter claude` | 프로젝트에 `.ai`와 `CLAUDE.md`를 구성 |
| `aiops doctor` | 프로젝트의 AI Ops 구성 상태를 점검 |
| `aiops bootstrap-guide` | 현재 AI Ops 구성 상태별 다음 단계 안내 |
| `aiops update --check` | 현재 core 업데이트 방식과 버전 확인 |
| `aiops update` | git checkout 기반 core를 fast-forward 업데이트 |
| `aiops release-check --strict` | 초기 배포 전 VERSION, Formula, 문서, license 상태 점검 |
| `AI Ops bootstrap 시작해줘.` | `.ai_project/` 운영 구성을 대화형으로 시작하고 빠른 시작/세부 설정을 선택 |
| `AI Ops bootstrap 재검토해줘.` | 기존 `.ai_project/` 결정을 Decision Stack 기준으로 재검토 |

`AI Ops install`이라는 표현은 Codex의 skill installer와 혼동될 수 있어 사용하지 않는다.

## Operating Model

vNext 운영 단위는 Agent 이름이 아니라 조직 구조와 Role이다.

기본 구조:

```text
AI Agent Ops Organization
  Development Division
    Product Team
  AI Ops Division
```

기본 Role:

| Role | 책임 |
|---|---|
| Direction Role | 목적, 우선순위, 승인, 제품 방향 |
| Lead Role | 범위 조율, ownership, dependency, Task 준비 |
| Execution Role | 승인된 Task 실행 |
| Verification Role | 독립 검증, 리스크, rework 판단 |
| Completion Role | 완료 확정, 잔여 리스크 수용 |
| Ops Governance Role | 운영모델 점검, 충돌/모호성 기록 |
| Release Role | 배포와 운영 인계, 필요 시 활성화 |

## Important Documents

처음 이해할 때는 아래 순서로 읽는다.

1. `core/constitution.md`
2. `QUICKSTART.md`
3. `docs/installation.md`
4. `docs/distribution.md`
5. `bootstrap/install_runbook.md`
6. `bootstrap/bootstrap_runbook.md`
7. `models/role_model.md`
8. `models/team_model.md`
9. `runtime/workflow.md`
10. `runtime/task_queue.md`
11. `policies/branch_pr_policy.md`
12. `templates/tool_adapters/codex/AGENTS.md`
13. `templates/tool_adapters/claude/CLAUDE.md`

## Directory Structure

| 디렉토리 | 역할 |
|---|---|
| `core/` | 최상위 원칙과 헌법 |
| `models/` | Organization, Team, Role, Capability, Agent 모델 |
| `policies/` | ownership, coordination, board, Git, 문서 보호 정책 |
| `runtime/` | workflow와 task queue 실행 규칙 |
| `bootstrap/` | 시드 구성과 프로젝트 운영체계 초기 구성 절차 |
| `agents/` | 기본 bootstrap Agent 참고 문서 |
| `workflows/` | Task 유형별 workflow |
| `templates/` | `.ai_project`와 프로젝트 문서 템플릿 |
| `bin/` | 로컬 CLI |
| `docs/` | 설치와 사용 문서 |

## Current Status

이 저장소는 vNext Draft 상태다. 현재 목표는 실제 프로젝트에 적용 가능한 문서 기반 AI Agent 운영체계를 안정화하는 것이다.

자동화 스크립트는 아직 핵심이 아니다. 먼저 사람이 이해하고, Agent가 문서를 읽고, 질문에 답하면서 안전하게 운영 구성을 만들 수 있는 흐름을 우선한다.

## Version

현재 템플릿 버전:

```text
VERSION
```

변경 이력:

```text
CHANGELOG.md
```

# AI Ops Control Plane 개선 계획

상태: 임시 계획 문서
작성일: 2026-07-27
처리 원칙: 개선 작업이 완료되면 삭제한다.

## 목표

AI Ops는 LangGraph, AutoGen, Claude Code, Codex 같은 실행 런타임과 경쟁하는 또 하나의 무거운 Agent Runtime이 아니다.

AI Ops의 방향은 다음과 같다.

> AI Ops는 여러 AI 코딩 도구가 같은 역할, 상태, 승인, 검증, 인계, 마이그레이션, 지식 관리 규칙을 따르게 만드는 repo-native Agent Operations Control Plane이다.

즉, 외부 프레임워크들의 장점은 흡수하되 AI Ops의 강점인 단순함, 도구 독립성, 프로젝트 단위 운영 통제력을 유지한다.

## 전략 요약

이번 개선의 핵심은 기능을 많이 추가하는 것이 아니라, 다음 세 가지를 동시에 만족시키는 것이다.

1. 외부 프레임워크의 검증된 장점을 흡수한다.
2. AI Ops의 기존 강점을 약화시키지 않는다.
3. 현재 약점을 CLI, schema, CI, migration으로 보완한다.

## 전략 매핑

| 구분 | 흡수하거나 살릴 내용 | AI Ops 적용 방식 | 관련 개선 단계 |
| --- | --- | --- | --- |
| LangGraph식 상태 관리 | Workflow 상태를 문서가 아니라 기계가 읽는 state schema로 관리 | Task/Workflow/Handoff schema와 상태 전이 검증 추가 | 1, 2, 3 |
| AutoGen/CrewAI식 역할 협업 | Lead, Execution, Verification 같은 Role 간 위임과 인계 규칙 강화 | Role별 책임, Handoff 계약, Agent Registry 검증 강화 | 1, 4, 5 |
| Claude Code Subagent식 세션 분리 | 한 세션 안의 보조 에이전트와 독립 Role Session 구분 | role_session, orchestration_session, delegated_worker 운용 가이드와 prompt 생성 | 5 |
| OpenAI Agents SDK식 handoff/guardrail | 다음 Role에게 넘기는 입력/출력 계약과 guardrail 명확화 | handoff 필수 필드, transition guardrail, 완료 전 검증 조건 추가 | 3, 4 |
| Continue/Aider식 repo-native 규칙 | 복잡한 설명보다 프로젝트 안에서 바로 읽히는 짧은 규칙 유지 | Adapter 문서 축소, README/Quickstart 단순화, 세부 문서 링크화 | 10 |
| LLM Wiki식 지식 관리 | 긴 문서 전체를 매번 읽지 않고 필요한 지식만 찾아 사용 | `.ai_project/knowledge/`와 context pack을 Task/source of truth에 연결 | 6 |
| AI Ops 기존 강점 | 특정 도구에 종속되지 않고 저장소 안에 운영 상태를 남김 | `.ai/`와 `.ai_project/` 분리 유지, adapter는 얇게 유지 | 전체 |
| AI Ops 기존 강점 | AI가 알아서 처리하지 않고 승인, 검증, 인계를 남김 | 승인 경계, verification, handoff, task transition 기록 강화 | 3, 4, 7 |
| AI Ops 약점 보완 | 문서 기반 약속이 많음 | schema, validate, task transition, handoff validate, CI로 검증 | 1, 2, 3, 4, 8 |
| AI Ops 약점 보완 | 기존 프로젝트 업데이트가 수동적일 수 있음 | migration plan/apply/verify 흐름을 새 schema와 knowledge 구조까지 확장 | 7 |

## 유지해야 할 강점

1. 도구 독립성
   - Codex, Claude, Cursor, Continue 등 특정 도구 하나에 종속되지 않는다.
   - 프로젝트 안의 운영 규칙을 기준으로 여러 에이전트를 같은 방식으로 움직이게 한다.
   - 개선 중에도 특정 runtime dependency를 필수로 추가하지 않는다.

2. Repo-native 운영 상태
   - `.ai/`는 공통 운영 헌법과 템플릿을 담는다.
   - `.ai_project/`는 실제 프로젝트별 운영 설정과 현재 상태를 담는다.
   - 운영 상태가 저장소 안에 남기 때문에 추적, 검토, 마이그레이션이 가능하다.
   - schema와 CLI가 추가되어도 최종 상태는 사람이 열람 가능한 파일로 남긴다.

3. 사람이 이해할 수 있는 운영 흐름
   - Role, Task, Status, Approval, Verification, Handoff가 문서와 CLI 출력으로 보인다.
   - 복잡한 agent graph보다 사용자가 현재 상황을 이해하기 쉽다.
   - 자동화가 늘어나도 "왜 막혔는지", "다음 Role은 무엇인지"를 CLI가 설명해야 한다.

4. 안전한 적용 방식
   - Discovery 후 Apply.
   - 승인 전 파일 수정 금지.
   - 마이그레이션 전 영향 범위 확인.
   - 자동 수정 가능 항목과 사용자 결정 필요 항목을 분리한다.

5. 작은 프로젝트와 큰 프로젝트를 모두 수용
   - Fast Track은 가볍게 시작한다.
   - Guided Full은 팀/역할/검증/인계를 더 엄격하게 운영한다.
   - schema와 validate도 운영 모드별 엄격도 차이를 가져야 한다.

## 보강해야 할 약점

1. 문서 기반 약속이 많다
   - 현재 일부 규칙은 에이전트가 문서를 읽고 따라야만 작동한다.
   - 중요한 규칙은 CLI와 CI에서 검증 가능해야 한다.
   - 보완 수단: schema, `aiops validate`, `aiops task transition`, `aiops handoff validate`, CI.

2. Task와 Workflow 계약이 약하다
   - Markdown 템플릿은 사람이 읽기 좋지만 상태 전이, 필수 필드, 인계 조건 검증에는 한계가 있다.
   - 기계가 읽을 수 있는 schema가 필요하다.
   - 보완 수단: Markdown + YAML front matter + JSON Schema.

3. Role Session 운용이 아직 손에 잡히지 않는다
   - 정책은 있지만 실제로 Lead, Execution, Verification, Completion 세션을 어떻게 시작하고 인계할지 더 명확해야 한다.
   - 보완 수단: `aiops session-guide`, `aiops role prompt`, adapter별 시작 문구.

4. 프로젝트 지식이 커지면 context 부담이 커진다
   - 모든 문서를 에이전트가 매번 읽게 하면 비효율적이다.
   - LLM Wiki처럼 필요한 지식만 찾고 불러오는 구조가 필요하다.
   - 보완 수단: knowledge index, context pack, source of truth 연결.

5. 강력한 런타임과의 연결 준비가 부족하다
   - LangGraph나 OpenAI Agents SDK 같은 런타임과 바로 통합할 필요는 없지만, 나중에 연결할 수 있는 export 구조는 준비할 수 있다.
   - 보완 수단: task/state/handoff export format.

6. 문서가 많아질수록 초보자에게 어렵다
   - README와 Quickstart는 짧아야 한다.
   - 세부 정책은 링크로 분리해야 한다.
   - 보완 수단: README 축소, Quickstart 단순화, 고급 문서 링크화.

7. 기존 프로젝트 업데이트와 마이그레이션이 더 체계적이어야 한다
   - 사용자가 직접 변경 절차를 하나씩 따라 하기보다, 영향 범위와 자동 수정 가능 항목을 먼저 확인받고 적용하는 흐름이 필요하다.
   - 보완 수단: `aiops migrate`가 schema, handoff, role session, knowledge 구조 변경까지 plan/apply/verify로 처리.

## 외부 프레임워크에서 흡수할 점

### LangGraph

흡수할 점:
- 명시적 상태 모델
- checkpoint/resume 개념
- 상태 전이 추적

AI Ops 적용 방향:
- 실행 엔진은 만들지 않는다.
- 대신 Task, Workflow, Handoff 상태를 schema로 정의한다.
- 상태 전이 기록과 재개 가능한 인계 기록을 강화한다.

### AutoGen / CrewAI

흡수할 점:
- 역할 기반 agent 협업
- 위임과 협력 패턴

AI Ops 적용 방향:
- Role Session과 Delegated Worker 구분을 강화한다.
- `.ai_project/agent_registry.md`에서 어떤 에이전트가 어떤 Role을 맡는지 명확히 한다.
- 모든 Role을 반드시 독립 자동 에이전트로 만들지는 않는다.

### OpenAI Agents SDK

흡수할 점:
- Handoff
- Guardrail
- Session
- Tool boundary

AI Ops 적용 방향:
- Role 간 인계 계약을 구조화한다.
- 인계 전 필수 필드를 CLI로 검증한다.
- 완료 전 검증, 승인, blocker 상태를 guardrail처럼 검사한다.

### Claude Code Subagents

흡수할 점:
- 한 세션 안에서 보조 agent를 활용하는 방식

AI Ops 적용 방향:
- `role_session`, `orchestration_session`, `delegated_worker`를 구분한다.
- delegated worker는 보조 작업자일 뿐, Verification이나 Completion 책임을 대체하지 않는다.
- Role별 세션 시작 문구와 위임 문구를 표준화한다.

### Continue / Aider

흡수할 점:
- 저장소 안의 단순한 규칙 파일
- 짧고 읽기 쉬운 agent instruction

AI Ops 적용 방향:
- AGENTS.md와 CLAUDE.md는 짧게 유지한다.
- 긴 정책은 링크로 분리한다.
- 사용자는 복잡한 문서를 다 읽지 않아도 `seed`, `bootstrap`, `validate`, `migrate` 흐름을 따라갈 수 있어야 한다.

### LLM Wiki

흡수할 점:
- 전체 문서를 prompt에 넣는 대신 지식을 색인화하고 필요한 것만 가져오는 방식

AI Ops 적용 방향:
- `.ai_project/knowledge/`를 프로젝트 지식 계층으로 강화한다.
- project brief, decisions, architecture, open questions, context packs를 구분한다.
- 에이전트는 작업에 필요한 context pack만 읽도록 유도한다.

## 개선 원칙

1. Schema-first, Markdown-second
   - 검증 기준은 machine-readable schema가 맡는다.
   - Markdown은 사람이 읽고 수정하기 쉬운 표현 계층으로 둔다.

2. 중요한 규칙은 CLI로 검증
   - Task 상태 전이, Handoff, Lock, Approval, Verification은 `aiops`가 확인할 수 있어야 한다.

3. 승인 경계는 유지
   - 자동화는 준비와 검증을 돕는다.
   - 파일 수정, migration apply, 완료 처리, 배포는 명시적 승인 경계를 유지한다.

4. 작게 시작하고 필요할 때 엄격해진다
   - Fast Track은 최소 구조를 유지한다.
   - Guided Full은 협업과 검증을 더 강하게 적용한다.

5. Tool Adapter는 얇게 유지
   - Codex/Claude adapter는 운영모델을 중복 설명하지 않는다.
   - 핵심 규칙으로 안내하고 세부 정책은 링크로 연결한다.

6. Runtime 연동은 선택 사항
   - AI Ops 자체가 runtime이 되지는 않는다.
   - 다만 향후 LangGraph/OpenAI Agents SDK 등에 넘길 수 있는 task/state/handoff export 구조는 준비한다.

## 개선 단위와 작업 순서

### 1단계: 운영 Schema 기반 만들기

목표:
- 문서로만 존재하던 핵심 운영 계약을 기계가 읽을 수 있게 만든다.

작업:
- `schemas/task.schema.json` 추가
- `schemas/workflow.schema.json` 추가
- `schemas/handoff.schema.json` 추가
- `schemas/agent_registry.schema.json` 추가
- `schemas/operating_model.schema.json` 추가
- Markdown은 사람이 보는 문서이고, schema가 검증 기준이라는 원칙 문서화

완료 기준:
- Task, Workflow, Handoff, Agent Registry의 필수 필드와 허용 값이 schema로 정의된다.
- 기존 테스트가 깨지지 않는다.

### 2단계: `aiops validate` 강화

목표:
- 운영 문서를 실제로 검사할 수 있게 한다.

작업:
- `aiops validate`가 schema를 기준으로 `.ai_project/`를 검사하도록 개선
- Fast Track과 Guided Full의 필수 필드 차이를 반영
- 잘못된 Task 상태, 누락된 role, 잘못된 handoff 필드를 오류로 표시

완료 기준:
- 정상 프로젝트는 통과한다.
- 깨진 task/front matter/handoff는 `--strict`에서 실패한다.
- Fast Track은 불필요하게 무겁게 실패하지 않는다.

### 3단계: Task 상태 전이 명령 추가

목표:
- 상태 변경을 에이전트의 임의 수정이 아니라 CLI 검증 흐름으로 만든다.

작업:
- `aiops task create`
- `aiops task status`
- `aiops task transition`
- `aiops task lock`
- `aiops task unlock`

검증할 규칙:
- 허용되지 않은 상태 전이는 실패
- lock이 있는 task는 다른 role/session이 임의 변경 불가
- blocker가 있으면 completion 불가
- verification이 필요한 workflow에서는 검증 없이 done 불가

완료 기준:
- valid transition, invalid transition, lock conflict, blocked completion에 대한 E2E 테스트가 통과한다.

### 4단계: Handoff 명령과 인계 계약 강화

목표:
- Role 간 인계를 표준화하고 누락 없이 전달되게 한다.

작업:
- `aiops handoff create`
- `aiops handoff validate`
- Handoff 템플릿 보강
- 다음 인계 흐름 검증:
  - Lead to Execution
  - Execution to Verification
  - Verification to Completion
  - Rework to Lead
  - Blocked to Lead

필수 인계 정보:
- task id
- from role
- to role
- current status
- allowed paths
- source of truth
- 변경 요약
- 검증 결과 또는 검증 요청
- blockers/open questions
- 다음 role이 해야 할 일

완료 기준:
- 필수 인계 정보가 없으면 validate 실패
- Handoff 메시지만 봐도 다음 agent가 작업을 이어갈 수 있다.

### 5단계: Role Session 운용 제품화

목표:
- 사용자가 실제로 Lead, Execution, Verification 세션을 나눠 운영하기 쉽게 만든다.

작업:
- `aiops session-guide`
- `aiops role prompt lead`
- `aiops role prompt execution`
- `aiops role prompt verification`
- `aiops role prompt completion`
- Codex/Claude 모두 같은 방식으로 Role Session을 시작할 수 있게 adapter 문구 정리

명확히 할 규칙:
- orchestration session은 조율 담당
- role session은 특정 Role 책임 담당
- delegated worker는 좁은 보조 작업 담당
- delegated worker가 독립 Verification/Completion을 대체하지 않음

완료 기준:
- 새 세션을 열 때 어떤 문구를 넣어야 하는지 CLI가 생성해준다.
- 역할 분리 테스트 프로젝트에서 handoff 흐름이 자연스럽게 이어진다.

### 6단계: Knowledge / LLM Wiki 계층 강화

목표:
- 큰 프로젝트에서도 필요한 지식만 읽고 작업할 수 있게 한다.

작업:
- `.ai_project/knowledge/index.md`
- `.ai_project/knowledge/project_brief.md`
- `.ai_project/knowledge/decisions/`
- `.ai_project/knowledge/architecture/`
- `.ai_project/knowledge/open_questions/`
- `.ai_project/knowledge/context_packs/`
- `aiops knowledge init`
- `aiops knowledge validate`
- `aiops knowledge pack <topic>`

완료 기준:
- 프로젝트 지식이 무작정 AGENTS.md나 CLAUDE.md에 쌓이지 않는다.
- 작업별로 필요한 context pack을 찾을 수 있다.
- open question이 구현 전에 드러난다.

### 7단계: 마이그레이션 자동화 강화

목표:
- 기존 AI Ops 프로젝트가 새 schema, handoff, role session, knowledge 구조로 안전하게 따라올 수 있게 한다.

작업:
- `aiops migrate --plan`이 다음 항목을 점검하도록 확장:
  - core version 차이
  - schema 도입 필요 여부
  - Task front matter 보강 필요 여부
  - handoff 템플릿/필드 보강 필요 여부
  - role session adapter 문구 갱신 필요 여부
  - knowledge index/context pack 도입 필요 여부
- `aiops migrate --apply`가 자동 수정 가능한 항목만 수정
- 사용자 결정이 필요한 항목은 `needs_user_decision`으로 분리
- `aiops migrate --verify`가 적용 후 `doctor`, `validate`, schema 검증을 실행

완료 기준:
- 기존 프로젝트에 대해 변경 영향 범위가 먼저 출력된다.
- 승인 후 자동 수정 가능한 항목만 적용된다.
- 사용자 커스텀 AGENTS.md/CLAUDE.md는 덮어쓰지 않고 결정 필요 항목으로 남긴다.
- 마이그레이션 후 `aiops validate --strict`가 통과하거나 남은 이슈가 명확히 보고된다.

### 8단계: CI / Release 안전장치 강화

목표:
- AI Ops 자체와 AI Ops가 설치된 프로젝트가 자동 검증을 받을 수 있게 한다.

작업:
- GitHub Actions 템플릿 추가
- `aiops ci init`
- `aiops release-check --strict` 확장
- 다음 검증 포함:
  - `aiops doctor --strict`
  - `aiops validate`
  - schema validation
  - shell test
  - migration dry-run

완료 기준:
- AI Ops 저장소 자체 CI가 통과한다.
- seed된 샘플 프로젝트에서도 CI 템플릿이 동작한다.

### 9단계: Runtime Adapter 준비

목표:
- LangGraph/OpenAI Agents SDK 같은 강한 런타임과 나중에 연결할 수 있는 구조를 만든다.

작업:
- `adapters/langgraph/README.md`
- `adapters/openai_agents/README.md`
- export format 초안 작성:
  - task graph
  - role assignment
  - state transitions
  - handoff events
  - approval checkpoints

범위 제한:
- 아직 실제 runtime engine을 만들지 않는다.
- 외부 dependency를 추가하지 않는다.

완료 기준:
- AI Ops task/state/handoff를 외부 runtime으로 넘길 수 있는 개념 구조가 생긴다.

### 10단계: README / Quickstart 단순화

목표:
- 처음 쓰는 사람이 어려운 정책 문서를 읽지 않아도 시작할 수 있게 한다.

작업:
- README는 다음만 짧게 유지:
  - AI Ops가 무엇인지
  - 왜 쓰는지
  - 설치
  - seed
  - bootstrap
  - migrate
  - validate
- 긴 설명은 별도 문서 링크로 분리
- Quickstart는 하나의 깔끔한 첫 실행 흐름으로 재작성

완료 기준:
- 초보자가 README만 보고 설치와 첫 bootstrap을 시작할 수 있다.
- 고급 정책은 필요한 사람만 들어가서 본다.

## 추천 실행 순서 요약

1. 운영 schema를 만든다.
2. `aiops validate`에 schema 검증을 연결한다.
3. Task 생성/상태 전이/lock 명령을 추가한다.
4. Handoff 생성/검증 명령을 추가한다.
5. Role Session 시작 문구와 세션 운용 가이드를 제품화한다.
6. Knowledge / LLM Wiki 계층을 강화한다.
7. 기존 프로젝트 마이그레이션 자동화를 강화한다.
8. CI와 release-check를 강화한다.
9. Runtime adapter export 구조를 준비한다.
10. README와 Quickstart를 단순화한다.

## 운영자 결정이 필요한 지점

1. Schema 형식
   - 추천: JSON Schema

2. Task 파일 형식
   - 추천: Markdown + 필수 YAML front matter

3. Workflow 엄격도
   - 추천: Fast Track은 가볍게, Guided Full은 handoff/verification을 엄격하게

4. Knowledge 위치
   - 추천: 프로젝트별 지식은 `.ai_project/knowledge/`, 공통 운영 규칙은 `.ai/`

5. CI 적용 방식
   - 추천: `aiops ci init`으로 선택 적용, 설치 시 강제하지 않음

## 성공 기준

개선이 완료되었다고 볼 수 있는 기준:

- 핵심 운영 상태를 문서 약속이 아니라 CLI/schema로 검증할 수 있다.
- 에이전트가 Task를 만들고 상태를 바꿀 때 허용된 흐름을 따른다.
- Role 간 인계가 구조화되어 누락 없이 전달된다.
- Fast Track은 여전히 가볍다.
- Guided Full은 실제 다중 에이전트 협업에 더 안전하다.
- 프로젝트 지식은 색인화되고 필요한 만큼만 불러올 수 있다.
- README는 짧고, 세부 정책은 링크로 분리된다.
- 기존 Homebrew 설치, migration, validate 흐름은 깨지지 않는다.

## 삭제 규칙

이 문서는 임시 작업 계획서다.

개선 작업이 완료되거나 영구 roadmap/release 문서로 전환되면 이 파일은 삭제한다.

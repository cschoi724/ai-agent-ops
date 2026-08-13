# Agent Operations Efficiency Improvement Plan

상태: 1차 완료 / 2차 완료 / 3차 구현 보완 완료·독립 재검증 대기
대상: Role Session, Task 상태 전이, 보고, 검증, Git 정리, 모델 추천
기준 버전: v0.14.0
작성일: 2026-08-13

## 1. 목적

이 계획은 AI Agent 운영의 정확성을 유지하면서 실제 작업 외 절차에 드는 시간과 비용을 줄이는 것을 목표로 한다.

핵심 문제는 규칙이 전혀 없는 것이 아니다. Role, workflow, handoff, report, branch 정책이 여러 문서에 존재하지만 Agent가 매번 이를 직접 조합해야 하며, 같은 정보를 여러 위치에 반복해서 기록한다. 그 결과 상태 전이와 검증이 실제 구현보다 오래 걸리고, 보내는 쪽과 받는 쪽의 준비 상태가 맞지 않는 경우가 생긴다.

개선 목표는 다음과 같다.

1. 완료된 Task의 불필요한 branch와 worktree를 안전하게 정리한다.
2. 한 Agent가 여러 Role을 맡을 때 하나의 Agent 정체성과 복수 책임을 함께 인식한다.
3. 상태 전이 전에 보내는 쪽과 받는 쪽의 준비도를 함께 검증한다.
4. Role Session 유지용 모델과 실제 Task 수행용 모델을 구분해 추천한다.
5. 상태 전이와 결과 보고에 짧고 일관된 필수 양식을 제공한다.
6. Task 위험도에 따라 절차와 검증 강도를 조절해 운영 속도를 높인다.

## 2. 현재 상태와 공백

| 영역 | 현재 존재하는 기준 | 운영 공백 |
|---|---|---|
| Branch 정리 | `delete_branch_after_merge: true`, `done` 이후 정리 가능 | merge, local/remote branch, worktree 정리를 실제로 수행하는 통합 절차가 없음 |
| 다중 Role | 한 Agent가 여러 Role을 맡을 수 있음 | Agent가 자신의 복수 Role을 하나의 정체성으로 인식하는 세션 계약이 없음 |
| 상태 전이 | workflow, handoff, 상태별 담당 Role 정의 | 송신 준비도와 수신 준비도를 한 번에 검사하지 않음 |
| 모델 선택 | Role과 capability 정의 | 상시 세션과 Task별 모델 추천 기준 및 provider mapping이 없음 |
| 결과 보고 | Task Report, QA Report, Handoff template | 채팅과 상태 전이에 사용할 짧은 공통 receipt가 없음 |
| 운영 속도 | fast track과 lightweight CI 논의 | Task 위험도에 따라 실제 절차를 줄이는 실행 profile이 없음 |

## 3. 설계 원칙

- 기존 상태를 더 늘리기보다 전이 검증과 자동화를 강화한다.
- Agent 정체성과 현재 행동 Role을 분리한다.
- 같은 정보를 Task, report, handoff, 최종 응답에 반복 입력하지 않는다.
- 하나의 구조화된 transition receipt에서 사람용 요약과 machine JSON을 함께 생성한다.
- 낮은 위험 Task에는 낮은 운영 비용을, 높은 위험 Task에는 독립 검증과 상세 근거를 적용한다.
- 안전 검사는 생략하지 않고 변경 범위와 위험도에 맞게 축소한다.
- 삭제, push, merge와 같은 외부 변경은 프로젝트 정책과 사용자 승인 범위를 유지한다.
- 기존 `project dashboard`, snapshot, Task metadata의 machine contract를 불필요하게 변경하지 않는다.
- 새 정책 문서를 계속 추가하지 않는다. 구현 시 기존 workflow, session orchestration, branch policy와 template을 갱신하고 중복 내용을 제거한다.
- 사용자용 출력은 짧고 이해하기 쉽게, Agent/자동화용 출력은 구조화된 원본 계약으로 제공한다.

## 4. 목표 Lifecycle

```text
Task 승인
  -> 시작: 현재 Agent와 보유 Role, 행동 Role, 권장 모델 확인
  -> 실행: 위험도에 맞는 검증 수행
  -> 전이: 송신·수신 준비도 동시 검사와 compact receipt 생성
  -> 수락: 다음 Agent가 변경된 조건만 확인
  -> 검증/완료: profile에 따라 독립 검증 또는 단축 흐름 적용
  -> 종료: merge와 canonical 반영 확인 후 branch/worktree 정리
```

사용자가 기억해야 할 lifecycle 명령 후보는 다음 세 개로 제한한다.

```sh
aiops task advance T-001
aiops task accept T-001
aiops task close T-001
```

세부 검사와 machine contract 명령은 Agent/자동화 계층에 유지한다.

## 5. Branch 종료 자동화

### 5.1 목표

완료된 Task가 local branch, remote branch, 불필요한 worktree를 남기지 않도록 Task 완료 절차와 Git 정리를 연결한다.

### 5.2 후보 명령

```sh
aiops task close T-001
aiops task close T-001 --check
aiops task close T-001 --json
```

`--check`는 삭제 없이 정리 가능 여부만 보여준다. 실제 삭제는 프로젝트의 승인 정책을 따른다.

### 5.3 내부 동작

1. Task workflow와 완료 조건 확인
2. PR merge 또는 동등한 canonical 반영 확인
3. canonical branch에 Task 결과가 포함됐는지 확인
4. Task branch의 미병합 commit 확인
5. 현재 checkout branch와 연결 worktree 확인
6. dirty worktree와 lock owner 확인
7. 안전한 local/remote task branch 삭제
8. 사용하지 않는 worktree 정리 및 prune
9. Task `done`, board, archive 정합성 확인
10. branch cleanup 결과를 transition receipt로 보고

### 5.4 자동 삭제 금지 조건

- 미병합 commit 존재
- 현재 checkout된 branch
- 다른 worktree에서 사용 중
- dirty worktree 존재
- 보호 branch 또는 canonical branch
- Task와 branch 소유 관계가 불명확
- 다른 active Task가 같은 branch를 참조
- push/delete 권한이 승인되지 않음

이 경우 `close`는 Task를 임의로 완료하거나 branch를 강제 삭제하지 않고 복구 가능한 안내를 반환한다.

## 6. 다중 Role Agent 계약

### 6.1 목표

한 Agent가 여러 Role을 맡을 때 Role마다 다른 Agent인 것처럼 행동하지 않고, 하나의 Agent가 복수 책임을 보유한다는 사실을 명시적으로 인식한다.

개념 모델:

```yaml
agent: Development Lead Agent
assigned_roles:
  - Lead Role
  - Completion Role
active_role: Completion Role
```

세션 안내 예시:

```text
나는 Development Lead Agent다.
이 프로젝트에서 Lead Role과 Completion Role을 함께 맡는다.
현재 Task에서는 Completion Role 권한으로 행동한다.
```

### 6.2 핵심 규칙

- Agent 정체성은 하나다.
- `assigned_roles`는 해당 Agent가 수행할 수 있는 전체 책임 집합이다.
- `active_role`은 현재 Task 상태에서 실제로 행사하는 책임이다.
- 상태 전이 기록에는 `active_role`을 남긴다.
- 허용된 Role 사이의 이동은 같은 세션에서 계속할 수 있다.
- 같은 Agent가 Role을 바꿔도 다른 Agent가 수행한 것처럼 보고하지 않는다.
- Role 경계는 유지하지만 불필요한 세션 재시작을 강제하지 않는다.

### 6.3 독립 분리가 필요한 조합

다음 조합은 기본적으로 같은 Agent 또는 같은 세션의 연속 수행을 허용하지 않는다.

- Execution Role과 Verification Role
- 구현 책임과 보안·개인정보 독립 검증
- 배포 실행 책임과 최종 Release 승인
- 변경 작성자와 독립 감사 책임

프로젝트 설정 후보:

```yaml
multi_role_mode: continuous
role_separation_required:
  - [Execution Role, Verification Role]
  - [Release Role, Release Approval Role]
```

기존 Agent registry의 Role 배열을 우선 재사용하고, 새 필드는 실제 machine contract 필요성이 확인될 때만 추가한다.

## 7. 양방향 상태 전이 준비도

### 7.1 목표

상태를 보내는 쪽만 완료했다고 판단하거나, 받는 쪽이 필요한 정보 없이 Task를 받는 문제를 전이 전에 차단한다.

### 7.2 후보 명령

```sh
aiops task advance T-001
aiops task advance T-001 --check
aiops task accept T-001
```

`advance`는 현재 workflow에서 허용되는 다음 상태와 담당자를 계산한다. `accept`는 전이 이후 변경된 조건만 다시 확인한다.

### 7.3 송신 준비도

- 현재 Agent와 `active_role`이 전이 권한을 가짐
- 현재 상태에서 다음 상태로 이동 가능
- 작업 결과 또는 검증 결과 존재
- 필수 검증과 생략 사유 기록
- 변경 파일이 `allowed_paths` 안에 있음
- lock, branch, worktree 상태 정상
- source of truth와 결과가 충돌하지 않음
- 남은 위험과 blocker가 구분되어 있음

### 7.4 수신 준비도

- 다음 `target_agent` 또는 `target_role`이 등록됨
- 다음 Agent가 필요한 Role과 capability를 보유함
- 다음 상태가 해당 Role에 의해 처리 가능함
- 필요한 source of truth, report, QA 경로가 존재함
- 선행 dependency가 충족됨
- canonical status가 허용 범위 안에서 최신임
- 다음 행동이 한 문장으로 명확함

### 7.5 전이 원자성

아래 값은 하나의 전이 작업으로 처리한다.

- Task status
- target Agent와 target Role
- lock 해제 또는 이전
- handoff metadata
- transition receipt
- 필요한 board projection

중간 실패가 발생하면 일부 파일만 전이된 상태를 남기지 않는다. 적용 전 검증, 임시 파일, atomic rename 또는 동등한 안전한 저장 방식을 사용한다.

새로운 `waiting_for_receiver` 같은 상태는 추가하지 않는다. 준비 여부는 status가 아니라 readiness projection으로 계산한다.

## 8. Compact Transition Receipt

### 8.1 사용자용 기본 양식

```text
Task: T-001
상태: in_progress -> verification_ready
처리: iOS Agent / Execution Role
다음: iOS QA Agent / Verification Role
결과: 구현 및 자체 검증 완료
근거: task report, 테스트 12개 통과
위험: 없음
다음 작업: 독립 검증
```

필수 정보:

- Task ID
- 이전 상태와 새 상태
- 처리 Agent와 행동 Role
- 다음 Agent와 Role
- 결과
- 검증 근거 또는 생략 사유
- 위험 또는 blocker
- 다음 행동

### 8.2 Machine 출력

```json
{
  "schema": "aiops.transition_receipt.v1",
  "task_id": "T-001",
  "transition": {
    "from": "in_progress",
    "to": "verification_ready"
  },
  "actor": {
    "agent": "iOS Agent",
    "role": "Execution Role"
  },
  "next": {
    "agent": "iOS QA Agent",
    "role": "Verification Role",
    "action": "독립 검증"
  },
  "result": "ready",
  "summary": "구현 및 자체 검증 완료",
  "evidence": [".ai_project/reports/T-20260813-001-task-report.md"],
  "risks": [],
  "blockers": []
}
```

Task report, QA report, handoff와 최종 채팅 보고는 이 receipt를 공통 입력으로 사용한다. 일반 Task에서는 compact receipt를 기본으로 하고, 감사·보안·배포·복잡한 재작업처럼 상세 근거가 필요한 경우에만 전체 보고서를 생성한다.

`aiops.transition_receipt.v1`은 검증 근거가 하나 이상 있거나 `validation_skip_reason`이 있어야 한다. `next.agent` 또는 `next.role` 중 하나 이상과 한 문장의 `next.action`도 필수다.

## 9. 위험도 기반 운영 Profile

### 9.1 목표

모든 Task에 동일한 세션 수, 보고량, 테스트 범위를 적용하지 않는다. Task 변경 범위, 가역성, 사용자 영향, 데이터 위험을 바탕으로 운영 profile을 추천한다.

### 9.2 Light

대상:

- 문구와 단순 문서 수정
- 운영 metadata와 local cache 정리
- 상태-only 변경
- 안전 조건이 확인된 branch cleanup
- 쉽게 되돌릴 수 있고 공유 계약을 바꾸지 않는 변경

기본 흐름:

```text
Execution -> self-check -> Completion
```

규칙:

- 별도 Verification 생략 가능
- Lead와 Completion 겸임 가능
- 변경 경로에 해당하는 검사만 실행
- compact receipt만 필수
- 독립성 또는 외부 승인 요구가 있으면 Standard로 승격

### 9.3 Standard

대상:

- 일반 제품 코드 변경
- 기능 구현과 제한된 리팩터링
- 사용자 화면과 API 동작 변경

기본 흐름:

```text
Execution -> independent Verification -> Completion
```

규칙:

- Execution과 Verification 분리
- 작업 중 관련 테스트, PR 전 전체 필요 테스트 실행
- compact receipt와 검증 결과 기록
- 상태 전이와 handoff를 `advance`로 통합

### 9.4 Strict

대상:

- 보안, 개인정보, 결제
- 데이터 migration과 삭제
- 공용 schema, workflow, policy
- 배포, release, rollback
- 다중 프로젝트 또는 큰 구조 변경

기본 흐름:

```text
Scope Review -> Execution -> Independent Verification -> Completion Review -> Release Gate
```

규칙:

- 독립 Role Session 필수
- 전체 회귀 검사와 상세 근거 필요
- 잔여 위험의 명시적 수용 필요
- branch/PR/release gate 생략 금지

### 9.5 자동 추천과 수동 override

Task 시작 시 다음 형태로 추천한다.

```text
운영 프로필: Standard
근거: 제품 코드 변경, 단일 플랫폼, 데이터 migration 없음
필수 단계: Execution -> Verification -> Completion
생략 가능: 별도 Lead 재검토
```

최종 profile은 Task metadata, workflow override 또는 사용자 결정으로 확정한다. 자동 추천은 보수적으로 상향할 수 있지만 근거 없이 낮은 profile로 낮추지 않는다.

## 10. Model Advisor

### 10.1 목표

Role Session을 계속 유지할 모델, 실제 Task를 처리할 모델, 독립 검증 모델을 구분하고 현재 실행 환경에서 사용할 수 있는 **실제 모델과 effort**를 추천한다.

사용자에게 `fast`, `balanced`, `deep` 같은 추상 profile만 보여주지 않는다. 이 값은 내부 판단 기준으로만 사용하고 최종 출력에는 Codex 또는 Claude Code에서 선택할 실제 모델, effort, 추천 이유, fallback을 표시한다.

모델과 계정별 가용성은 계속 바뀔 수 있으므로 특정 모델명을 영구 정책으로 고정하지 않는다. core에는 provider adapter와 추천 규칙을 두고 실제 후보는 local model catalog, provider alias, 조직 allowlist와 project override를 기준으로 실행 시점에 해석한다.

### 10.2 모델 Profile

| Profile | 용도 |
|---|---|
| `fast` | 상태 확인, 검색, 단순 문서·metadata 수정, 반복 작업 |
| `balanced` | 일반 Role Session, Task 조율, 보통 수준 구현 |
| `deep` | 복잡한 설계, 대규모 구현, 어려운 장애 분석 |
| `independent_review` | 독립 검증, 보안, 회귀, 계약 검토 |
| `vision` | UI screenshot, 디자인 비교, 시각 QA |

### 10.3 현재 실제 모델 추천 기준

아래 표는 2026-08-13 공식 model guidance를 기준으로 한 초기 추천값이다. 실제 실행 시에는 Agent 도구의 사용 가능 모델과 조직 allowlist를 먼저 확인한다.

| 작업 | Codex 추천 | Claude Code 추천 |
|---|---|---|
| 상태 확인, 단순 문서, 반복 작업 | `gpt-5.6-luna`, effort `low` | `haiku`, effort `low` |
| 일반 Role Session과 조율 | `gpt-5.6-terra`, effort `medium` | `sonnet`, effort `medium` |
| 일반 코드 구현 | `gpt-5.3-codex`, effort `high` | `sonnet`, effort `high` |
| 복잡한 설계, migration, 장애 분석 | `gpt-5.6-sol`, effort `high` 또는 `xhigh` | `opus` 또는 `opusplan`, effort `xhigh` |
| 가장 어렵고 장시간인 자율 작업 | `gpt-5.6-sol`, effort `xhigh` | 사용 가능하면 `fable`, effort `high` 또는 `xhigh` |
| 독립 코드·계약 검증 | `gpt-5.6-sol` 또는 `gpt-5.3-codex`, effort `xhigh` | `opus`, effort `xhigh` |
| UI 구현과 시각 QA | `gpt-5.6-sol`, effort `high` | `sonnet` 또는 `opus`, effort `high` |

Codex 기준:

- `gpt-5.6-sol`은 복잡한 전문 작업과 품질 우선 판단에 사용한다.
- `gpt-5.6-terra`는 일반 세션의 성능과 비용 균형에 사용한다.
- `gpt-5.6-luna`는 단순하고 반복적인 고빈도 작업에 사용한다.
- `gpt-5.3-codex`는 agentic coding과 repository 도구 사용이 중심인 구현에 사용한다.
- 지원 effort는 모델마다 다르므로 local model catalog가 허용하는 범위에서 선택한다.

Claude Code 기준:

- `haiku`는 빠른 단순 작업에 사용한다.
- `sonnet`은 일상적인 코딩과 일반 Role Session에 사용한다.
- `opus`는 복잡한 추론과 독립 검증에 사용한다.
- `opusplan`은 계획 단계에서 Opus, 실행 단계에서 Sonnet으로 자동 전환하는 경우에 사용한다.
- `fable`은 조직에서 사용할 수 있을 때 가장 어렵고 장시간인 작업에만 추천한다.
- alias가 실제로 가리키는 버전은 provider에 따라 다르므로 alias와 resolved model을 모두 기록한다.

공식 기준 문서:

- OpenAI Model Guidance: <https://developers.openai.com/api/docs/guides/latest-model>
- OpenAI GPT-5.3-Codex: <https://developers.openai.com/api/docs/models/gpt-5.3-codex>
- OpenAI Codex Configuration: <https://developers.openai.com/codex/config-reference>
- Claude Code Model Configuration: <https://code.claude.com/docs/en/model-config>

### 10.4 Role 기본 추천

| Role | 내부 기본 Profile | 실제 Task 조건 |
|---|---|---|
| Direction Role | `balanced` | 정책 충돌과 복잡한 의사결정은 `deep` |
| Lead Role | `balanced` | 복잡한 분해, ownership, architecture는 `deep` |
| Execution Role | `balanced` | 단순 반복은 `fast`, 복잡 구현은 `deep` |
| Verification Role | `independent_review` | UI 검증은 `vision` 병행 |
| Completion Role | `balanced` | 고위험 수용과 release 판단은 `deep` |
| Ops Governance Role | `balanced` | migration, schema, workflow 변경은 `deep` |

Task projection 후보:

```yaml
model_recommendation:
  provider: codex
  session: {model: gpt-5.6-terra, effort: medium}
  task: {model: gpt-5.6-sol, effort: high}
  verification: {model: gpt-5.6-sol, effort: xhigh}
  fallback: {model: gpt-5.3-codex, effort: high}
  reason: shared workflow contract and migration risk
```

표시 예시:

```text
권장 모델
- 실행 환경: Codex
- 세션 유지: gpt-5.6-terra / medium
- 이번 작업: gpt-5.6-sol / high
- 독립 검증: gpt-5.6-sol / xhigh
- 대체 모델: gpt-5.3-codex / high
- 이유: 공용 schema와 workflow 계약 변경
```

Claude Code에서는 같은 Task를 다음처럼 표시할 수 있다.

```text
권장 모델
- 실행 환경: Claude Code
- 세션 유지: sonnet / medium
- 이번 작업: opusplan / xhigh
- 독립 검증: opus / xhigh
- 대체 모델: sonnet / high
- 이유: 복잡한 계획과 공용 workflow 계약 변경
```

### 10.5 Provider-aware Resolver

추천 절차:

1. 현재 실행 환경이 Codex, Claude Code 또는 custom provider인지 감지
2. 현재 모델, local model catalog, 조직 allowlist와 project override 확인
3. Task의 Role, workflow, 운영 profile, 변경 경로와 위험 신호 분석
4. session, task, verification, delegated worker별 실제 모델과 effort 계산
5. 사용할 수 없는 모델은 명확히 표시하고 허용된 fallback 선택
6. 선택에 필요한 실행 방법과 새 세션 필요 여부 안내
7. 추천 시점의 alias와 resolved model을 transition receipt에 기록

추천 명령 후보:

```sh
aiops model recommend --role "Execution Role" --task T-001
aiops model recommend --role "Verification Role" --task T-001 --provider claude-code
aiops model recommend --role "Lead Role" --task T-001 --json
```

적용 안내 예시:

```text
Codex: codex --model gpt-5.3-codex --config model_reasoning_effort=high
Claude Code: claude --model sonnet --effort high
```

AI Ops는 현재 세션의 모델을 임의로 변경하지 않는다. 실행 환경이 안전한 model switch API를 제공하면 사용자 또는 orchestration policy가 허용한 범위에서만 전환하고, 그렇지 않으면 새 세션 시작 명령이나 model picker 선택값을 안내한다.

### 10.6 Alias, Pinning과 Provider Mapping

일상 사용은 provider가 관리하는 alias를 우선할 수 있다. 재현성과 규제 준수가 중요한 Strict Task는 exact model ID pinning을 허용한다.

```yaml
model_resolution:
  provider: claude_code
  requested: opus
  resolved: claude-opus-5
  effort: xhigh
  purpose: independent_verification
  source: provider_alias
  resolved_at: 2026-08-13T00:00:00Z
```

Codex는 local model catalog와 `model` / `model_reasoning_effort` 설정을 기준으로 확인한다. Claude Code는 alias, `availableModels`, provider별 model mapping과 effort 지원 범위를 기준으로 확인한다.

프로젝트 override는 공급자별로 분리한다.

```yaml
provider_model_map:
  codex:
    fast: {model: gpt-5.6-luna, effort: low}
    balanced: {model: gpt-5.6-terra, effort: medium}
    coding: {model: gpt-5.3-codex, effort: high}
    deep: {model: gpt-5.6-sol, effort: xhigh}
  claude_code:
    fast: {model: haiku, effort: low}
    balanced: {model: sonnet, effort: medium}
    coding: {model: sonnet, effort: high}
    deep: {model: opus, effort: xhigh}
```

가용 모델은 변경될 수 있으므로 project mapping과 provider catalog는 core release와 분리해 갱신할 수 있어야 한다. built-in 추천표에는 기준 날짜와 공식 출처를 기록한다.

보조 worker는 현재 Role Session의 모델을 무조건 상속하지 않는다. 단순 검색 worker에는 비용이 낮은 모델을, 복잡한 분석 worker에는 상위 모델을 추천할 수 있다. 최종 책임과 결과 검토는 원래 Role Session에 남으며 worker 모델이 주 세션보다 강하더라도 독립 Role Session을 대체하지 않는다.

## 11. 속도 최적화 세부 원칙

- 상태 전이마다 전체 `doctor`, health, strict validation을 반복하지 않는다.
- 변경된 Task와 관련 schema, 경로, workflow만 먼저 검사한다.
- canonical checkpoint에서만 전체 동기화와 공유 상태 검사를 수행한다.
- `in_progress`, 임시 lock 같은 local 상태는 불필요한 상태-only PR을 만들지 않는다.
- 상태-only 변경에는 제품 build/test CI를 실행하지 않는다.
- 제품 코드가 바뀐 경우에만 해당 제품 CI를 실행한다.
- Completion은 이미 통과한 검증을 다시 실행하지 않고 commit SHA, 결과 hash, evidence를 확인한다.
- 같은 Agent의 허용된 Role 이동은 새 세션과 전체 context 재로딩을 강제하지 않는다.
- 받는 Agent는 `accept` 시 전이 이후 달라진 조건만 검사한다.
- 상세 보고서는 Strict 또는 예외 상황에만 요구한다.
- 실행 중에는 관련 테스트, PR 또는 release gate에서 전체 테스트를 실행한다.

## 12. 차수별 구현 계획

### 1차. Unified Lifecycle Contract

구현 상태: 완료, 독립 검증 통과, PR #50으로 main 반영

목표:

- 다중 Role Agent 인식, 전이 readiness, compact receipt를 하나의 lifecycle 계약으로 확정한다.

구현 범위:

- `models/role_model.md`의 Agent identity / assigned roles / active role 정의
- `policies/session_orchestration_policy.md`의 continuous multi-role session 기준
- `runtime/workflow.md`의 송신·수신 readiness 기준
- `runtime/role_handoff.md`와 report template의 compact receipt 정렬
- 중복 필드와 상충 문구 목록 작성 및 제거
- 필요 시 `aiops.transition_receipt.v1` schema 초안

반영 결과:

- Agent registry의 기존 `roles` 배열을 `assigned_roles`로 해석하고 현재 행동 Role을 `active_role`로 분리했다.
- Lead+Completion은 같은 Agent가 연속 수행할 수 있고, Execution+Verification은 기본 독립 분리하도록 상충 문구를 정리했다.
- 송신·수신 readiness를 lifecycle 전이 전 확인 계약으로 추가했다.
- `aiops.transition_receipt.v1`, JSON template, `aiops validate transition-receipt FILE`을 추가했다.
- Task Report와 QA Report의 중복 `Next Handoff` 필드를 receipt 경로 참조로 축소했다.
- Task/Handoff의 장문 상태 요약은 compact receipt와 receiver start context로 분리했다.
- 기존 Task, `aiops.handoff.v1`, report, QA는 자동 변환하거나 새 필드를 필수화하지 않는다.
- Role prompt는 Task의 enabled `target_agent`를 우선하고, Role 후보가 여러 명이면 임의 선택하지 않으며, Agent/Role/Task ownership 충돌을 거부한다.
- 독립 재검증에서 High/Medium/Low 이슈 없음과 릴리즈 차단 없음 판정을 받았고 PR #50으로 `main`에 반영했다.

1차 결정:

- Receipt는 `.ai_project/reports/TASK_ID_FROM_to_TO_TIMESTAMP-transition-receipt.json` 형식의 전이별 불변 파일로 저장한다. Task는 최신 receipt를, handoff는 생성 당시 receipt를 가리킨다.
- 상세 Task/QA report는 Strict 또는 예외 상황에서 유지하고 일반 전이는 receipt를 기본으로 한다.
- 새 상태는 추가하지 않으며 atomic 전이 자동화는 2차 `task advance`에서 구현한다.

검증:

- Lead+Completion 겸임 Agent가 하나의 Agent로 표시됨
- 행동 기록에는 active Role이 남음
- Execution+Verification 조합은 기본 분리됨
- Task ID, status, actor, next owner가 없는 receipt 거부
- 기존 Task/Handoff 문서 migration 영향 보고
- 독립 검증 후 다음 차수 진행

### 2차. Transition Automation

구현 상태: 완료, 독립 검증 통과, PR #52로 main 반영

목표:

- 상태 전이와 handoff 생성을 한 명령으로 처리한다.

구현 범위:

- `aiops task advance TASK_ID`
- `--check`, `--json`
- 송신·수신 readiness projection
- 다음 status/Agent/Role 자동 계산
- Task, lock, handoff, board의 원자적 갱신
- `aiops task accept TASK_ID`
- compact receipt 렌더링

검증:

- 정상 Execution -> Verification -> Completion 흐름
- 수신 Agent 미등록, capability 부족, source 누락 거부
- stale canonical status와 dependency 미완료 처리
- 중간 쓰기 실패 시 원본 파일 보존
- transition 전후 machine contract와 status consistency
- 다른 worktree에서 동시 전이할 때 충돌 감지
- CookLog 실제 Task fixture dry run
- 독립 검증 후 다음 차수 진행

구현 결과 (2026-08-13):

- `task accept`를 담당자가 시작 상태로 진입하는 명령, `task advance`를 다음 Role 인계 또는 완료 확정 명령으로 분리했다.
- `--check`와 `aiops.task_transition_plan.v1` JSON은 실제 적용 전에 sender/receiver, dependency, source, allowed path, lock, canonical, evidence readiness와 예상 write set을 제공한다.
- Task의 실제 `target_agent`와 `target_role`을 actor 기준으로 사용하고, 다음 Agent는 enabled Role/capability와 Task team/domain 신호로 단일 후보일 때만 자동 선택한다. 모호하면 `--next-agent`를 요구한다.
- Task, lock, compact receipt, Role handoff, board projection은 임시 파일과 rollback을 사용하는 하나의 write bundle로 적용한다.
- Git common directory의 Task lock으로 서로 다른 worktree와 프로세스의 동시 전이를 차단한다.
- 기존 `task transition`과 기존 Task/Handoff/receipt schema는 호환 경로로 유지한다.
- 정상 Execution -> Verification -> Completion, readiness 거부, write rollback, worktree 동시성, stale canonical, CookLog 실제 승인 Task dry run을 검증했다.
- 독립 재검증에서 High/Medium/Low 이슈 없음과 릴리즈 차단 없음 판정을 받았고 PR #52, merge commit `509e4c8`로 `main`에 반영했다.

### 3차. Risk-based Workflow Profiles

구현 상태: 구현 보완 완료, 독립 재검증 대기

목표:

- Light, Standard, Strict profile로 절차와 검증 비용을 조절한다.

구현 범위:

- profile 추천 규칙과 근거 projection
- Task/workflow별 명시 override
- profile별 필수 Role, 검증, 보고, CI gate
- 변경 경로 기반 targeted validation
- state-only와 product-code CI 분리 기준
- dashboard와 `aiops task status`에 profile 표시

검증:

- 문서-only Task는 Light 추천
- 일반 코드 Task는 Standard 추천
- 보안, migration, schema, release Task는 Strict 추천
- 위험 신호가 있으면 낮은 profile로 자동 하향되지 않음
- Light에서 불필요한 독립 세션과 전체 CI가 생략됨
- Standard/Strict 독립 검증 계약 유지
- profile별 시간·명령 수 비교 기록
- 독립 검증 후 다음 차수 진행

구현 결과 (2026-08-13):

- `aiops task profile TASK_ID [--profile ...] [--json]`과 `aiops.task_risk_profile.v1` schema를 추가했다.
- Task scope와 `base_sha` 이후 Git 변경 경로를 state-only, docs-only, product-code, mixed로 분류하고 위험 신호별 최소 profile을 계산한다.
- Task `risk_profile`, workflow `default_profile`, CLI override를 지원하되 명시 override가 자동 최소값보다 낮으면 차단한다.
- profile별 필수 Role, 독립 검증 여부, report mode, CI scope, gate와 argv 기반 targeted validation 계획을 제공한다.
- Light lifecycle은 `in_progress -> completion_review`로 직접 연결하고 Standard/Strict는 독립 Verification 흐름을 유지한다.
- Task status, project snapshot, terminal/HTML dashboard 작업 표에 계산된 profile을 표시한다.
- 기존 Task는 새 metadata를 필수로 요구하지 않으며 자동 추천을 사용한다.
- 독립 검증에서 발견된 저수준 전이 Profile 우회와 base 없는 Task의 변경 누락을 차단했다. project context도 같은 Profile 조건을 사용하며 staged, unstaged, untracked 경로를 allowed-path guard에 포함한다.
- Snapshot/dashboard Profile 필드 타입을 schema로 검증하고, snapshot 한 번 안에서 저장소·untracked·base별 Git 조회 결과를 재사용한다.

### 4차. Safe Task Close and Branch Cleanup

목표:

- Task 완료, canonical 확인, branch/worktree 정리를 안전하게 자동화한다.

구현 범위:

- `aiops task close TASK_ID`
- merge와 canonical 포함 여부 확인
- local/remote branch 소유 관계 확인
- dirty/unmerged/protected/current branch guard
- worktree 사용 여부와 prune
- 프로젝트 승인 정책 연결
- cleanup receipt

검증:

- merge된 task branch local/remote 정리
- 미병합 commit, dirty worktree, current branch 삭제 거부
- 다른 Task가 공유하는 branch 삭제 거부
- branch 삭제 실패 시 Task 완료 상태를 잘못 확정하지 않음
- 반복 실행 idempotency
- GitHub 보호 규칙과 PR squash merge 처리
- 독립 검증 후 다음 차수 진행

### 5차. Model Advisor

목표:

- 실행 중인 Agent 도구와 Task 위험도에 맞는 session/task/verification 실제 모델, effort와 fallback을 추천한다.

구현 범위:

- `aiops model recommend --role ROLE --task TASK_ID`
- Codex, Claude Code와 custom provider adapter 감지
- local model catalog, alias, allowlist, provider mapping 확인
- provider-neutral 내부 profile과 실제 모델 resolver 분리
- Role, workflow profile, capability 기반 추천
- session/task/verification/delegated worker별 추천
- model ID 또는 alias, resolved model, effort, fallback과 추천 이유 표시
- Codex `model` / `model_reasoning_effort` 적용 안내
- Claude Code `--model` / `--effort`와 alias 적용 안내
- floating alias와 Strict Task exact pinning 지원
- `role prompt`, `task start`, `session-guide` 연결
- 공식 model catalog 기준 날짜와 갱신 경로
- provider/project override와 JSON contract

검증:

- 같은 Role에서도 단순/일반/복잡 Task의 실제 모델과 effort가 달라짐
- Codex에서 coding Task는 `gpt-5.3-codex`, 복잡한 판단은 가용한 `gpt-5.6` 계열 우선 추천
- Claude Code에서 단순 작업은 `haiku`, 일반 작업은 `sonnet`, 복잡한 계획은 `opus` 또는 `opusplan` 추천
- 장시간 작업의 `fable`은 실제 가용할 때만 추천
- Verification은 구현 세션과 구분된 실제 review 모델과 새 세션 필요 여부를 표시
- vision 필요 Task에 시각 입력 가능 모델과 capability 표시
- alias가 provider별 실제 모델로 다르게 해석되는 fixture 검증
- unsupported effort를 해당 모델의 지원 범위로 안전하게 조정
- 미등록 또는 사용할 수 없는 모델에서 명확한 fallback
- 사용자 override 우선
- JSON에는 provider, requested/resolved model, effort, purpose, source, reason과 fallback 제공
- 기본 추천표 기준 날짜와 공식 출처 확인
- 모델 catalog 갱신 없이 기존 Task/machine contract가 변하지 않음
- AI Ops가 사용자 허용 없이 현재 세션 모델을 변경하지 않음
- 독립 검증 후 계획 완료 판정

## 13. 공통 검증 게이트

각 차수는 최소 아래를 통과한다.

```sh
git diff --check
sh scripts/test.sh
bin/aiops release-check --strict --allow-pending-release
```

추가 공통 기준:

- 정상 흐름, 거부 흐름, 중간 실패 E2E
- 기존 project snapshot/dashboard JSON의 비의도 변경 없음
- 기존 프로젝트 migration plan 제공
- CookLog에서 실제 운영 시나리오 dry run
- target project의 기존 변경과 untracked 파일 보존
- 사용자용 compact 출력과 Agent용 JSON 의미 일치
- 각 큰 차수 완료 후 별도 Agent 독립 검증
- 독립 검증에서 Medium 이상 이슈가 있으면 다음 차수 진행 전 수정

## 14. 성공 지표

- 일반 상태 전이는 사용자 또는 Agent 명령 1회로 준비도 검사와 handoff까지 완료한다.
- 받는 Agent는 전체 준비 절차를 반복하지 않고 변경 조건만 확인한다.
- compact 보고에는 Task ID, 상태, 처리자, 다음 담당자, 근거, 위험, 다음 행동이 항상 포함된다.
- 완료된 전용 Task branch와 worktree가 안전 조건 충족 후 남지 않는다.
- 다중 Role Agent가 자신을 여러 Agent처럼 잘못 보고하지 않는다.
- Light Task는 Standard 대비 세션 수, 전체 검사 횟수, 보고량이 감소한다.
- Strict Task는 기존 독립 검증과 release 안전성을 유지한다.
- 모델 추천에는 provider별 실제 session/task/verification 모델, effort, fallback과 추천 이유가 포함된다.

구현 전 baseline과 각 차수 이후 아래 수치를 비교한다.

- Task 전이당 실행 명령 수
- Task 전이당 생성·수정 문서 수
- 중복 검증 실행 횟수
- 승인부터 verification ready까지 소요 시간
- verification ready 이후 수신 준비 실패 횟수
- merge 후 남은 task branch/worktree 수
- Light/Standard/Strict profile별 평균 처리 시간

## 15. 비범위

- 모델 공급자 계정과 결제 자동 설정
- 사용자 승인 없는 push, merge, deploy, remote branch 삭제
- 독립 검증이 필요한 Task의 검증 책임 통합
- 모든 기존 Task를 즉시 새 schema로 일괄 변환
- 운영 효율을 이유로 보안, 개인정보, 데이터 migration gate 제거
- Agent가 직접 판단한 profile로 사용자 정책을 우회하는 기능

## 16. 구현 전 결정할 항목

1. 같은 Agent가 연속 수행할 수 있는 Role 조합의 기본 allow/deny matrix - 1차 결정 완료
2. Light profile에서 Verification을 생략할 수 있는 정확한 조건
3. `advance`가 기본적으로 바로 적용할지, 사용자 승인 대상 전이만 확인할지
4. remote branch 삭제 승인을 Task 단위로 받을지 프로젝트 정책으로 위임할지
5. transition receipt를 Task 파일에 내장할지 별도 handoff 파일로 둘지 - 1차에서 별도 reports JSON으로 결정
6. 기존 report template을 유지할지 receipt 기반 상세 report 생성기로 전환할지 - 1차에서 상세 report 유지 + receipt 참조로 결정
7. built-in 실제 모델 추천표, provider adapter와 프로젝트 override의 우선순위
8. 상태-only 변경의 canonical publish와 CI 실행 기준
9. 일상 Task에서 floating alias를 사용할 범위와 Strict Task의 exact model pinning 기준
10. 현재 세션 model switch를 추천만 할지, 지원 adapter에서는 승인 후 자동화할지

## 17. 권장 다음 단계

Project Dashboard 1~9차는 v0.14.0으로 릴리스 및 Homebrew 배포가 완료됐고, 1차 `Unified Lifecycle Contract`와 2차 `Transition Automation`도 main 반영을 완료했다. 현재 3차 `Risk-based Workflow Profiles`의 독립 검증 지적사항을 보완하고 재검증을 준비한다.

이유:

- 현재 문제는 시각화 기능 부족보다 실제 Task 운영 시간과 반복 비용에 직접 영향을 준다.
- 1차에서 계약을 먼저 통합해야 이후 명령 자동화가 기존 문서 중복을 확대하지 않는다.
- 다중 Role과 상태 전이 준비도 기준이 확정되어야 위험도 profile과 branch cleanup을 안전하게 자동화할 수 있다.
- 모델 추천은 Task 위험도와 Role continuity 정보가 마련된 뒤 연결해야 일관된 추천이 가능하다.

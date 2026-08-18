# Agent Identity and Reference Integrity Improvement Plan

상태: 1~2차 완료 / 3~4차 미착수
대상: Agent Registry, Task ownership, lifecycle routing, migration, validation
작성일: 2026-08-18

## 1. 목적

이 계획은 Agent 표시 이름을 변경했을 때 기존 Task가 오래된 `target_agent` 값을 계속 참조해 상태 전이와 인계가 차단되는 문제를 해결한다.

현재 상태 전이 엔진은 등록되지 않은 Agent를 실행자로 사용하지 않도록 fail-closed로 동작한다. 따라서 잘못된 Agent에게 조용히 인계하는 결함은 아니지만, Registry 변경 시 참조 무결성을 사전에 검사하거나 관련 Task를 안전하게 마이그레이션하는 기능이 없다. 그 결과 Registry 변경은 완료된 것처럼 보이지만 실제 인계 시점에야 문제가 드러날 수 있다.

개선 목표는 다음과 같다.

1. Agent의 불변 식별자와 사용자에게 보이는 이름을 분리한다.
2. Registry 변경 시 영향을 받는 현재 운영 참조를 사전에 검사한다.
3. Agent 이름 변경을 dry-run, atomic apply, receipt가 있는 명령으로 제공한다.
4. 기존 이름 기반 프로젝트를 중단 없이 ID 기반 라우팅으로 마이그레이션한다.
5. 과거 Task, report, QA, handoff, receipt의 감사 기록은 소급 변경하지 않는다.
6. 이름 재사용과 alias 충돌로 다른 Agent에게 잘못 라우팅되는 상황을 차단한다.

## 2. 확인된 현재 공백

현재 정식 계약은 다음과 같다.

- Agent Registry는 `agent` 이름 문자열을 필수 값으로 사용한다.
- Task는 `target_agent` 문자열을 라우팅 참조로 사용한다.
- lifecycle은 `target_agent`와 Registry의 현재 이름이 일치하지 않으면 상태 전이를 차단한다.
- project relationship 검사는 미등록 `target_agent`를 보고하지만 현재는 report-only다.
- Agent 이름 변경, alias 등록, 참조 migration 전용 명령이 없다.
- 일부 내부 코드가 `id`를 fallback으로 읽지만 schema와 프로젝트 운영 계약에서 불변 ID로 보장되지 않는다.

대표 실패 흐름은 다음과 같다.

```text
1. Registry: Execution Agent -> Builder Agent
2. 기존 Task: target_agent: Execution Agent
3. project validation: 관계 경고만 보고
4. task advance/accept: actor is not registered
5. 사용자 또는 Agent가 Task 파일을 수동 수정해야 진행 가능
```

이 문제는 상태 전이 규칙 자체보다 Registry와 Task 사이의 참조 무결성 관리 문제로 분류한다.

## 3. 설계 원칙

- machine identity는 불변 ID를 사용한다.
- `agent` 또는 `display_name`은 사용자 표시 값이며 변경할 수 있다.
- 이름 변경은 Agent 교체가 아니다. 동일 ID를 유지하면 동일 Agent로 취급한다.
- Agent 교체는 rename과 분리된 명시적 reassignment 작업으로 처리한다.
- 기존 이름 기반 프로젝트는 한 번에 깨지지 않도록 점진적으로 마이그레이션한다.
- alias는 legacy 참조를 찾기 위한 호환 수단이며 최종 라우팅 기준이 아니다.
- active/backlog Task의 stale reference는 strict validation과 lifecycle에서 차단한다.
- archive Task와 과거 report, QA, handoff, receipt는 당시 이름을 보존한다.
- 자동 수정은 구조화된 metadata만 대상으로 한다. 일반 Markdown 본문의 문자열을 무차별 치환하지 않는다.
- rename과 migration은 `--check`가 기본 안전 경로이며 적용 결과를 구조화된 receipt로 남긴다.
- canonical 상태, dirty worktree, concurrent edit, alias 충돌이 있으면 fail-closed한다.

## 4. 목표 데이터 모델

### 4.1 Agent Registry

최종 목표 계약은 다음과 같다.

```yaml
schema: aiops.agent_registry.v2
project: Example Project
agents:
  - id: execution-agent
    agent: Builder Agent
    aliases:
      - Execution Agent
    status: enabled
    team: Development Team
    roles:
      - Execution Role
    capabilities:
      - implementation
```

필드 의미:

| 필드 | 의미 |
|---|---|
| `id` | 생성 후 변경하지 않는 machine identity |
| `agent` | 사용자 화면과 보고서에 표시하는 현재 이름 |
| `aliases` | 과거 이름을 식별하고 migration하는 호환 목록 |
| `status` | 현재 활성 상태 |
| `roles` | 수행 가능한 Role 집합 |
| `capabilities` | 수행 가능한 capability 집합 |

ID 규칙 후보:

- 프로젝트 안에서 유일해야 한다.
- 소문자 영문, 숫자, 하이픈을 기본 형식으로 사용한다.
- 표시 이름 변경 시에도 바뀌지 않는다.
- 삭제된 ID를 다른 Agent에 재사용하지 않는다.
- bootstrap 시 사람이 읽을 수 있는 안정적인 slug를 생성하되 충돌 시 명시적으로 해결한다.

### 4.2 Task ownership

호환 기간의 Task metadata는 다음과 같이 유지한다.

```yaml
target_agent_id: execution-agent
target_agent: Builder Agent
target_role: Execution Role
```

- `target_agent_id`가 canonical routing key다.
- `target_agent`는 사용자 표시와 기존 도구 호환을 위한 projection이다.
- 두 값이 함께 있으면 같은 Registry entry를 가리켜야 한다.
- ID가 없고 이름만 있으면 legacy reference로 판정하고 migration 대상에 포함한다.
- alias로만 해석되면 실행 가능 여부와 별개로 `migration_required`를 보고한다.

최종 강제 단계에서는 active/backlog Task에 `target_agent_id`를 필수로 요구한다. archive Task에는 이 규칙을 소급 적용하지 않는다.

### 4.3 이름과 정체성의 구분

아래 변경은 rename이다.

```text
id: execution-agent
Execution Agent -> Builder Agent
```

아래 변경은 reassignment다.

```text
target_agent_id: execution-agent -> ios-builder-agent
```

rename은 Agent의 역할, 이력, 현재 Task 소유권을 유지한다. reassignment는 소유권 변경이며 별도의 상태 전이 권한과 인계 근거가 필요하다.

## 5. 참조 해석 규칙

호환 기간의 resolver 우선순위는 다음과 같다.

1. `target_agent_id`와 Registry `id` 정확 일치
2. legacy `target_agent`와 현재 `agent` 이름 정확 일치
3. legacy `target_agent`와 단일 alias 정확 일치
4. 그 외에는 unresolved로 차단

추가 제약:

- 하나의 문자열이 둘 이상의 Agent ID, 현재 이름, alias에 일치하면 ambiguity 오류로 차단한다.
- 현재 이름은 다른 Agent의 ID 또는 alias와 충돌할 수 없다.
- 과거 이름을 새 Agent의 현재 이름으로 재사용하려면 기존 active/backlog 참조가 모두 ID로 마이그레이션됐는지 먼저 확인한다.
- alias 해석은 자동으로 다른 Agent를 선택하는 기능이 아니다. 반드시 같은 불변 ID에 연결된 과거 이름만 허용한다.
- lifecycle receipt에는 `agent_id`, 실행 시점의 `agent` 표시 이름, `role`을 함께 기록한다.

## 6. 사용자 명령 설계

### 6.1 Agent 참조 점검

```sh
aiops agent inspect --target /path/to/project
aiops agent inspect --target /path/to/project --json
```

표시 항목:

- 등록된 Agent ID와 현재 이름
- ID가 없는 Registry entry
- 이름만 참조하는 active/backlog Task
- 미등록 이름을 참조하는 Task
- alias로만 해석되는 Task
- 중복 ID, 이름, alias 충돌
- migration 가능 여부와 다음 명령

### 6.2 Agent 이름 변경

```sh
aiops agent rename execution-agent \
  --to "Builder Agent" \
  --target /path/to/project \
  --check

aiops agent rename execution-agent \
  --to "Builder Agent" \
  --target /path/to/project \
  --apply
```

`--check` 결과에는 다음을 포함한다.

- 대상 Agent ID
- 이전 이름과 새 이름
- 추가될 legacy alias
- 갱신할 active/backlog Task
- 표시 projection만 갱신할 현재 운영 metadata
- 수정하지 않을 역사 문서
- 충돌, canonical, worktree, lock 검사
- 적용 예정 파일과 validation 명령

`--apply`는 plan과 동일한 입력 상태에서만 실행한다. 검사 후 Registry나 Task가 바뀌었으면 다시 plan을 생성하도록 차단한다.

### 6.3 기존 프로젝트 ID migration

```sh
aiops agent migrate-identities --target /path/to/project --check
aiops agent migrate-identities --target /path/to/project --apply
```

동작:

1. 현재 Registry 이름에서 ID 후보 생성
2. ID 충돌과 기존 참조 검사
3. Registry에 ID 추가
4. active/backlog Task에 `target_agent_id` 추가
5. 현재 `target_agent` 표시 projection 동기화
6. strict validation과 lifecycle dry-run 수행
7. migration receipt 기록

자동 생성 ID가 애매하거나 이름 충돌이 있으면 임의 결정하지 않고 명시적 mapping을 요구한다.

## 7. Machine contract

새 schema 후보:

- `aiops.agent_identity_audit.v1`
- `aiops.agent_rename_plan.v1`
- `aiops.agent_rename_receipt.v1`
- `aiops.agent_identity_migration_plan.v1`
- `aiops.agent_identity_migration_receipt.v1`

rename plan 예시:

```json
{
  "schema": "aiops.agent_rename_plan.v1",
  "ready": true,
  "agent": {
    "id": "execution-agent",
    "from": "Execution Agent",
    "to": "Builder Agent"
  },
  "affected": {
    "active_tasks": ["T-20260818-001"],
    "backlog_tasks": [],
    "historical_references": 4
  },
  "writes": [
    ".ai_project/agent_registry.md",
    ".ai_project/tasks/active/T-20260818-001.md"
  ],
  "blockers": []
}
```

receipt에는 plan hash, 적용 전후 Agent identity, 실제 변경 파일, 검증 결과, migration actor를 기록한다. shell command 문자열은 저장하지 않고 필요한 경우 argv 배열만 허용한다.

## 8. 변경 범위 정책

### 갱신 대상

- `.ai_project/agent_registry.md`
- active/backlog Task의 구조화된 `target_agent_id`, `target_agent`
- 현재 상태를 나타내는 구조화된 board/context projection
- 향후 생성되는 lifecycle plan과 receipt의 Agent ID 필드

### 기본적으로 갱신하지 않는 대상

- archive Task
- 완료된 Task Report와 QA Report
- 과거 handoff와 transition receipt
- Git commit author와 PR 기록
- 일반 Markdown 본문에 등장하는 과거 Agent 이름

역사 문서는 당시 표시 이름을 보존한다. Dashboard가 과거 자료를 표시할 때는 저장된 이름을 그대로 보여주고 현재 이름으로 소급 치환하지 않는다.

## 9. 원자성 및 동시성

rename과 migration은 다음 순서로 처리한다.

1. 프로젝트와 canonical 상태 검사
2. Registry와 대상 파일 content hash 기록
3. Agent identity 전용 lock 획득
4. 전체 변경 결과를 메모리에서 구성
5. 모든 schema와 semantic validation 수행
6. 임시 파일에 기록
7. atomic rename으로 적용
8. 적용 후 project strict validation 수행
9. receipt 기록
10. lock 해제

중간 실패 시 파일 내용과 permission을 원래 상태로 복원한다. 일부 Task만 새 이름이나 ID를 가지는 상태를 남기지 않는다.

차단 조건:

- dirty한 대상 metadata 파일
- stale canonical status
- Registry 또는 Task hash 변경
- 다른 identity migration 진행 중
- 중복 ID, 이름, alias
- unresolved active/backlog reference
- Task가 다른 worktree에서 변경 중
- 기록할 receipt 경로가 안전하지 않음

## 10. 단계별 구현 계획

### 1차: 참조 감사와 strict validation

진행 상태: 구현 및 독립 검증 완료

구현:

- Registry와 active/backlog Task의 Agent 참조를 한 번에 검사하는 공용 resolver 추가
- 미등록 `target_agent`, duplicate name, ambiguous reference를 strict validation 실패로 승격
- archive와 역사 문서는 report-only로 분리
- `aiops agent inspect` 사용자 명령과 JSON projection 추가
- lifecycle과 project validator가 같은 resolver를 사용하도록 정리

검증:

- 이름이 일치하는 기존 프로젝트 통과
- stale `target_agent`가 strict validation과 lifecycle에서 동일하게 차단
- archive의 과거 이름은 실행 차단 사유가 되지 않음
- duplicate current name과 ambiguous lookup 거부
- 기존 snapshot/dashboard JSON 회귀 없음

완료 기준:

- Registry 변경 직후 상태 전이 전에 stale reference를 발견할 수 있다.
- validator와 lifecycle의 판정이 서로 다르지 않다.

### 2차: ID와 alias 호환 계층

진행 상태: 구현 완료, 독립 검증 대기

구현:

- Registry에 optional `id`, `aliases` 추가
- Task에 optional `target_agent_id` 추가
- ID, current name, alias 공용 resolver 구현
- uniqueness와 collision semantic validator 추가
- dashboard와 사용자 CLI는 현재 Agent 이름을 표시하고 machine projection은 ID를 포함
- alias로 해석된 active/backlog Task에 `migration_required` 표시

검증:

- ID 기반 Task 라우팅 통과
- 표시 이름 변경 후에도 같은 ID로 actor/receiver 판정 유지
- alias 충돌, ID 재사용, current-name 충돌 거부
- Agent/Team 고유 표시 이름 보존
- 기존 이름 기반 Task와 Registry 호환
- locale에 따라 고유 이름이 번역되지 않음

완료 기준:

- ID가 있는 프로젝트는 Agent 이름 변경과 무관하게 상태 전이를 계속할 수 있다.
- legacy 프로젝트는 아직 깨지지 않지만 migration 필요 상태가 명확히 보인다.

구현 메모:

- v1 schema에 optional 필드를 추가해 기존 프로젝트를 즉시 깨지 않도록 했다.
- resolver 우선순위는 `target_agent_id`, 현재 이름, 단일 alias 순서다.
- ID와 표시 이름이 서로 다른 Agent를 가리키면 lifecycle과 strict validation이 차단한다.
- snapshot/dashboard는 안정 ID를 machine field로 유지하고 현재 Registry 이름을 표시 projection으로 사용한다.
- 실제 Registry·Task 파일 갱신 명령과 atomic migration receipt는 3차 범위다.

### 3차: rename과 migration 자동화

구현:

- `aiops agent rename --check/--apply/--json`
- `aiops agent migrate-identities --check/--apply/--json`
- plan과 receipt schema 및 semantic validator
- atomic multi-file update와 rollback
- canonical, worktree, lock, content hash guard
- help와 한국어/영어 사용자 안내

검증:

- rename dry-run이 파일을 수정하지 않음
- apply 후 active/backlog Task가 동일 ID와 새 표시 이름을 사용
- 역사 자료 hash 불변
- 중간 실패 주입 후 내용과 permission 복원
- concurrent rename 중 하나만 적용
- apply 재실행 idempotent
- alias와 새 이름의 shell/control character 방어
- malformed plan/receipt와 action 중복·누락 거부

완료 기준:

- 사용자가 Task 파일을 수동 검색·치환하지 않고 Agent 이름을 안전하게 변경할 수 있다.
- 적용 결과가 감사 가능한 receipt로 남는다.

### 4차: ID 기반 계약 강제와 legacy 정리

구현:

- Agent Registry v2와 Task schema 전환
- 새 프로젝트 bootstrap에서 ID를 기본 생성
- active/backlog Task의 `target_agent_id` 필수화
- lifecycle routing에서 이름 기반 fallback 제거
- legacy alias 사용량과 migration readiness를 health/dashboard에 표시
- 기존 프로젝트 upgrade guide와 migration 경로 제공

검증:

- 신규 프로젝트가 처음부터 ID 기반으로 생성됨
- migration 완료 프로젝트에서 이름 기반 참조 없이 전체 lifecycle 통과
- 미완료 프로젝트는 명확한 migration 안내와 함께 fail-closed
- migrate plan/apply 전후 기존 상태·관계·Task 소유 의미 보존
- Homebrew 설치본과 repository CLI 결과 동일

완료 기준:

- 현재 운영 라우팅이 변경 가능한 이름에 의존하지 않는다.
- Agent 이름 재사용이 다른 Agent로의 오인 인계를 만들 수 없다.

## 11. 필수 독립 검증 시나리오

각 차수 구현 후 다른 Agent가 아래 관점으로 독립 검증한다.

### 참조 무결성

- `Execution Agent -> Builder Agent` 변경 후 기존 Task 라우팅
- `Verification Agent -> Verifier Agent` 변경 후 수신 Agent 선택
- 이름 변경 후 과거 이름을 새 Agent가 재사용하는 경우
- 두 Agent가 같은 alias를 선언하는 경우
- Registry ID와 Task ID가 불일치하는 경우
- current name은 맞지만 ID가 다른 경우

### 호환성

- ID가 없는 legacy Registry와 Task
- 이름만 있는 active/backlog/archive Task 혼합
- 기존 receipt와 handoff의 Agent 이름 보존
- 여러 Role을 가진 하나의 Agent identity 유지
- Execution/Verification 독립 분리 규칙 유지

### 안전성

- `--check` read-only 보장
- dirty/stale/concurrent 상태 차단
- 적용 실패 rollback
- symlink와 프로젝트 외부 path 거부
- shell metacharacter와 control character 거부
- arbitrary command 실행 불가

### Machine contract

- schema mutation 검증
- plan/receipt action 중복과 누락 거부
- 기존 snapshot/dashboard 필드는 의도된 추가 필드 외 동일
- terminal/tree/Mermaid 기존 관계와 내부 ID 회귀 없음
- 사용자 locale 변경이 Agent 고유 이름을 바꾸지 않음

## 12. 운영 중 임시 대응 절차

전용 rename 기능이 구현되기 전에는 다음 절차를 사용한다.

1. Registry 이름을 변경하기 전에 old/new mapping을 확정한다.
2. `.ai_project/tasks/active`와 `backlog`에서 기존 이름 참조를 검색한다.
3. Registry와 현재 Task metadata를 같은 변경 단위에서 갱신한다.
4. archive, report, QA, handoff, receipt는 수정하지 않는다.
5. `aiops validate project --strict`를 실행한다.
6. 대상 Task에 `task accept/advance --check --json`을 실행한다.
7. 검증 결과와 변경 mapping을 운영 결정 또는 migration 기록에 남긴다.

현재 relationship validation이 report-only이므로, 전용 개선 전까지는 출력의 `target_agent not registered` 경고도 반드시 차단 이슈로 취급한다.

## 13. 결정이 필요한 항목

- Registry v2에서 표시 필드명을 기존 `agent`로 유지할지 `display_name`으로 변경할지
- Agent ID를 사람이 지정할지 bootstrap이 자동 생성할지
- alias를 migration 완료 후 제거할지 역사 lookup을 위해 유지할지
- active 상태의 handoff에 Agent ID를 추가할지 새 receipt부터만 적용할지
- 이름 변경 권한을 Lead, Ops Governance, Boss 중 어디까지 허용할지
- Boss Automation이 routine rename을 standing authorization으로 수행할 수 있는지
- Registry 직접 편집을 허용하되 strict validation으로 통제할지 명령 사용을 강제할지

초기 구현에서는 기존 `agent` 필드를 표시 이름으로 유지하고 optional ID를 추가하는 방식을 우선한다. 필드명 변경은 기능적 이점보다 migration 비용이 크므로 v2 확정 전 별도 검토한다.

## 14. 완료 정의

아래 조건을 모두 만족하면 개선 완료로 판정한다.

- Agent 이름 변경이 active Task의 상태 전이를 중단시키지 않는다.
- 모든 현재 라우팅은 불변 Agent ID로 검증된다.
- stale 또는 ambiguous Agent reference가 상태 전이 전에 발견된다.
- rename과 migration이 dry-run, atomic apply, rollback, receipt를 제공한다.
- 과거 감사 기록은 변경되지 않는다.
- 기존 이름 기반 프로젝트에 명시적인 무중단 migration 경로가 있다.
- 신규 프로젝트는 처음부터 ID 기반 Agent identity를 사용한다.
- 독립 검증에서 High, Medium, Low 미해결 이슈가 없다.

# Ownership Model

작성일: 2026-07-09  
상태: Draft vNext  
범위: 조직형 AI Agent 운영체계의 path / domain / document ownership 기준

## 1. 목적

이 문서는 `ai-agent-ops` vNext에서 ownership을 정의한다.

Ownership은 특정 경로, 도메인, 문서, 운영 규칙 영역을 어느 Team 또는 Role이 책임지는지를 뜻한다. 목적은 여러 Agent와 Team이 동시에 작업할 때 충돌을 줄이고, cross-team 변경의 검토 책임을 명확히 하는 것이다.

## 2. 기본 원칙

- Ownership은 Agent 이름이 아니라 Team, Role, Owner 단위로 정의한다.
- 초기 ownership은 path 기반으로 시작한다.
- domain ownership은 path만으로 충돌을 설명하기 어려울 때 보조로 사용한다.
- source of truth 문서도 ownership 대상이다.
- Task의 `allowed_paths`는 수정 가능 범위이고, ownership은 책임과 검토 주체다.
- `allowed_paths`가 겹치지 않아도 같은 ownership 영역이면 충돌 가능성이 있다.
- ownership이 불명확한 Task는 `scoped`로 전환하지 않는다.

## 3. Ownership 유형

| 유형 | 의미 | 예시 |
|---|---|---|
| Path Ownership | 파일 또는 디렉토리 책임 | `ios/App/Auth/` |
| Domain Ownership | 기능/제품 도메인 책임 | Auth Domain |
| Document Ownership | source of truth 문서 책임 | `docs/release/` |
| Workflow Ownership | 운영 규칙과 workflow 책임 | `.ai/workflows/` |
| Release Ownership | release gate와 운영 인계 책임 | Release Checklist |

## 4. Path Ownership

Path ownership은 초기 기본 모델이다.

예시:

```text
ios/App/Auth/              iOS Team / Auth Owner
ios/App/WebView/           iOS Team / WebView Owner
ios/App/DesignSystem/      iOS Team / Design System Owner
android/Auth/              Android Team / Auth Owner
web/auth/                  Web Team / Auth Owner
backend/auth/              Backend Team / Auth Owner
docs/release/              Release Role
.ai/workflows/             AI Ops Division
.ai/templates/             AI Ops Division
```

Task가 path ownership 영역을 수정하려면 아래 조건을 만족해야 한다.

- `allowed_paths`에 해당 경로가 포함되어 있다.
- `team`이 ownership Team과 일치하거나 cross-team 변경으로 표시되어 있다.
- `team_lead` 또는 Owner가 검토 주체로 기록되어 있다.
- source of truth가 명시되어 있다.

## 5. Domain Ownership

Domain ownership은 여러 path에 걸친 기능 영역을 표현한다.

예시:

```text
Auth Domain
  iOS Team
  Android Team
  Web Team
  Backend Team

Payment Domain
  Business Division
  Backend Team
  iOS Team
  QA Division

Release Domain
  Release / Operations Division
  QA Division
  Development Division
```

Domain ownership이 필요한 경우:

- 여러 플랫폼이 같은 기능 흐름을 공유한다.
- path는 달라도 사용자 경험 또는 API 계약이 연결되어 있다.
- 한 팀의 변경이 다른 팀의 검증 또는 release gate에 영향을 준다.
- source of truth 문서가 여러 Team의 기준이 된다.

Domain ownership이 있는 Task는 `scoped` 단계에서 domain 영향 여부를 기록한다.

## 6. Document Ownership

source of truth 문서도 ownership을 가진다.

예시:

```text
docs/current_status.md           Direction Role / Product Owner
docs/architecture.md             Development Lead
docs/api_contracts.md            Backend Team / Development Lead
docs/release/checklist.md        Release Role
.ai/core/constitution.md              AI Ops Division
.ai/runtime/workflow.md                  AI Ops Division
.ai/runtime/task_queue.md                AI Ops Division
.ai/models/capabilities.md              AI Ops Division
```

같은 source of truth 문서를 여러 Task가 동시에 수정하면 병렬 작업은 기본 금지다.

Document ownership 변경은 단순 문서 수정이 아니라 기준 문서의 책임 변경으로 본다.

## 7. Workflow Ownership

운영체계 문서는 AI Ops Division이 ownership을 가진다.

대상:

```text
.ai/core/constitution.md
.ai/models/org_model.md
.ai/models/role_model.md
.ai/models/capabilities.md
.ai/runtime/workflow.md
.ai/runtime/task_queue.md
.ai/models/agent_registry.md
.ai/workflows/
.ai/templates/
```

운영체계 문서 변경은 제품 Task와 분리한다. 운영체계 개선 Task는 AI Ops Division의 Task로 다루고, 실제 프로젝트 적용은 migration plan과 사용자 승인 후 진행한다.

## 8. Ownership Metadata

Task는 ownership 판단에 필요한 정보를 metadata에 기록한다.

```yaml
org_unit: Development Division
team: {{TEAM_NAME}}
team_lead: {{TEAM_LEAD}}
ownership:
  paths:
    - path/to/project-area/
  domains:
    - {{DOMAIN_NAME}}
  documents:
    - docs/current_status.md
ownership_review:
  required: true
  reviewer: {{TEAM_LEAD}}
```

초기 Task 템플릿에는 `ownership` 필드가 없어도 된다. 단, ownership 충돌이 있는 Task는 본문이나 scoped 기록에 위 정보를 남겨야 한다.

## 9. Ownership Review

아래 조건 중 하나라도 해당하면 `ownership_review`가 필요하다.

- Task가 여러 Team의 `allowed_paths`를 수정한다.
- Task가 path ownership과 다른 Team에서 실행된다.
- Task가 domain ownership이 있는 기능을 수정한다.
- Task가 source of truth 문서를 수정한다.
- Task가 release gate, API contract, auth, payment, privacy 영역에 영향을 준다.
- 같은 ownership 영역의 다른 Task가 `approved`, `in_progress`, `verification_ready`, `verification_in_progress` 상태다.

Review 결과는 Task에 기록한다.

```text
Ownership Review:
- Owner:
- 영향 영역:
- 충돌 여부:
- 병렬 가능 여부:
- 필요한 후속 Task:
```

## 10. Cross-Team 변경

Cross-team 변경은 한 Team이 다른 Team의 ownership 영역을 수정하거나, 여러 Team의 ownership 영역을 동시에 수정하는 작업이다.

Cross-team 변경 기준:

- `allowed_paths`가 여러 Team 영역에 걸친다.
- domain ownership이 여러 Team에 걸친다.
- API contract, shared model, shared design system, release checklist를 수정한다.
- source of truth 문서가 여러 Team의 기준이다.

Cross-team 변경은 기본적으로 Lead Role의 `scoped` 단계가 필수다.

## 11. Ownership 충돌

아래 경우 ownership 충돌로 본다.

- 두 Task가 같은 path ownership 영역을 동시에 수정한다.
- 두 Task가 같은 domain ownership 영역을 동시에 수정하고 결과가 서로 영향을 줄 수 있다.
- 두 Task가 같은 source of truth 문서를 동시에 수정한다.
- 한 Task의 변경이 다른 Task의 검증 기준을 바꾼다.
- Release 또는 migration 작업이 같은 영역의 실행 Task와 겹친다.

충돌이 있으면 아래 중 하나로 처리한다.

- `depends_on`으로 순서를 정한다.
- `blocks`로 후속 Task 차단을 명시한다.
- `parallel_group`을 같게 두고 병렬 금지로 표시한다.
- Task 범위를 분리한다.
- Lead Role 또는 Owner가 병렬 가능 사유를 기록한다.
- 불확실하면 `blocked`로 전환한다.

## 12. 초기 iOS Ownership 예시

초기 iOS Team 파일럿에서는 아래 예시를 사용할 수 있다.

```text
ios/App/Auth/              iOS Team / Auth Owner
ios/App/WebView/           iOS Team / WebView Owner
ios/App/Navigation/        iOS Team / Navigation Owner
ios/App/DesignSystem/      iOS Team / Design System Owner
ios/App/Networking/        iOS Team / Networking Owner
ios/App/Release/           iOS Team / iOS Release Owner
docs/ios/                  iOS Team
docs/release/              Release Role
```

실제 프로젝트에 적용할 때는 프로젝트 경로에 맞춰 `.ai_project/ownership.md` 또는 동등 문서에 기록한다.

## 13. 금지사항

- ownership이 불명확한 Task를 `scoped`로 전환하지 않는다.
- `allowed_paths`가 있다는 이유만으로 ownership review를 생략하지 않는다.
- 같은 ownership 영역의 Task를 Lead Role 판단 없이 병렬 실행하지 않는다.
- source of truth 문서를 여러 Task가 동시에 수정하지 않는다.
- Agent 개인을 장기 Owner로 지정하지 않는다. Owner는 Team, Role, 또는 명시적 Owner 역할이어야 한다.

## 14. 변경 이력

| 날짜 | 변경 내용 |
|---|---|
| 2026-07-09 | 조직형 AI Agent 운영체계의 ownership 모델 초안 작성 |

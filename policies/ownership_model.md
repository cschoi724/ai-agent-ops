# Ownership Model

작성일: 2026-07-10
상태: Draft vNext Slim Reference
범위: path, domain, document ownership 기준

## 1. 목적

Ownership은 어떤 Role, Agent, Team이 특정 변경의 책임을 갖는지 정하는 기준이다.

AI Agent가 임의로 넓은 범위를 수정하지 않도록 Task마다 책임 경계와 허용 경로를 기록한다.

## 2. 기본 원칙

- ownership은 Task 승인 전에 확인한다.
- `allowed_paths` 밖의 변경은 새 승인 또는 scope 변경이 필요하다.
- path ownership과 domain ownership이 충돌하면 Lead Role이 조율한다.
- source of truth 문서는 별도 ownership을 가질 수 있다.
- ownership이 불명확하면 Task를 `scoped` 또는 `blocked`에서 멈춘다.

## 3. Ownership Model

canonical 선택값은 `schemas/operating_model.schema.json`과 `runtime/bootstrap_options.json`을 따른다.

| Model | 의미 | 권장 상황 |
|---|---|---|
| `path_only` | 파일/디렉토리 경로 기준 | 작은 프로젝트, 경로가 명확한 코드 |
| `path_plus_domain` | path와 기능/기술 domain 함께 사용 | 대부분의 앱/서비스 |
| `document_ownership` | 기준 문서 owner를 명시 | 기획/설계/API 문서가 중요한 프로젝트 |
| `strict_parallel_control` | 충돌 가능성이 있으면 병렬 제한 | migration, multi-team, 민감 영역 |
| `custom` | 프로젝트 규칙 사용 | 기존 CODEOWNERS 또는 조직 정책 |

## 4. Path Ownership

Path ownership은 수정 가능한 파일 범위를 제한한다.

Task metadata 예시:

```yaml
allowed_paths:
  - App/Auth/
  - Tests/Auth/
locked_paths:
  - App/Auth/LoginView.swift
```

Execution Role은 승인된 path 밖을 수정하기 전에 Lead Role에게 scope 변경을 요청한다.

## 5. Domain Ownership

Domain ownership은 기능이나 기술 영역 기준 책임이다.

예시:

```yaml
owned_domains:
  - auth
  - onboarding
  - networking
```

같은 domain이 여러 path에 걸치면 domain owner가 변경 영향과 검증 기준을 확인한다.

## 6. Document Ownership

source of truth 문서는 코드와 별도로 owner를 둘 수 있다.

대상:

- requirements
- architecture
- API contract
- test strategy
- release note
- current status

문서가 실제 코드와 충돌하면 Completion 전에 차이를 기록하고 Lead 또는 Direction Role이 판단한다.

## 7. Workflow Ownership

상태별 기본 owner:

| 상태 | Owner |
|---|---|
| `proposed` / `scoped` | Lead Role |
| `approved` | Direction Role 또는 Lead Role |
| `in_progress` | Execution Role |
| `verification_ready` 이후 | Verification Role |
| `completion_review` | Completion Role 또는 Lead Role |
| `blocked` | Lead Role |

상태 전이의 canonical 기준은 `runtime/workflow.md`를 따른다.

## 8. Ownership Review

Lead Role은 Task 승인 전 아래를 확인한다.

- 변경 목적
- allowed paths
- owned domains
- source of truth
- dependency
- lock 필요 여부
- 검증 책임

확인되지 않은 항목은 `pending_decision` 또는 `unresolved`로 기록한다.

## 9. 충돌 처리

충돌 유형:

| 충돌 | 처리 |
|---|---|
| path 충돌 | 병렬 중단 또는 branch 순서 조정 |
| domain 충돌 | domain owner와 Lead Role이 영향 판단 |
| document 충돌 | source of truth 우선순위 결정 |
| workflow 충돌 | Ops Governance Role이 정책 확인 |

해결되지 않으면 Task를 `blocked`로 둔다.

## 10. 금지사항

- Task에 allowed path 없이 구현을 시작하지 않는다.
- 편의를 위해 ownership을 지나치게 넓게 잡지 않는다.
- 문서 owner 승인 없이 source of truth를 뒤집지 않는다.
- ownership 충돌을 Board에 숨기지 않는다.
- strict control이 필요한 migration에서 병렬 작업을 기본 허용하지 않는다.

## 11. 변경 이력

| 날짜 | 변경 내용 |
|---|---|
| 2026-07-10 | path/domain/document ownership 기준 추가 |
| 2026-07-27 | 중복 예시를 줄이고 slim reference로 압축 |

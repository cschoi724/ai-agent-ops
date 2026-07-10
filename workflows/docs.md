# Docs Workflow

작성일: 2026-06-29  
상태: Draft vNext

## 1. 용도

운영 문서, 기획 문서, 개발 문서, 인수인계 문서, 템플릿 문서를 작성하거나 정리할 때 사용한다.

## 2. 기본 흐름

```text
Direction scopes docs Task -> Lead coordinates ownership -> Execution updates docs -> Verification reviews -> Completion closes
```

초기 bootstrap 구성에서는 별도 문서 전담 Agent를 두지 않아도 된다. Lead Role 또는 Execution Role이 문서 초안을 작성하고 Verification Role이 일관성을 검토할 수 있다. 단, `.ai/` 운영 문서는 `.ai/policies/document_governance.md` 기준으로 사용자 승인 후만 수정한다.

## 3. 단계별 책임

| 단계 | Capability | 기본 Role | Bootstrap Agent 예시 | 산출물 |
|---|---|---|---|---|
| Direction | `planning` | Direction Role | PM Agent | 문서 범위, 독자, 완료 기준 |
| Coordination | `ownership_review` | Lead Role | PM Agent 또는 Team Lead | 문서 ownership, source of truth |
| Execution | `documentation` | Execution Role | PM Agent 또는 Docs Role | 문서 초안 |
| Verification | `qa_review`, `risk_review` | Verification Role | QA Agent | 문서 일관성 검토 |
| Completion | `approval_management` | Completion Role | PM Agent / Product Owner | 반영/보류 판단 |

## 4. 기본 상태 전이

| 현재 status | 수행 Role | 다음 status | 다음 target_role | Bootstrap target_agent |
|---|---|---|---|---|
| `proposed` | Lead Role | `scoped` | Direction Role | PM Agent |
| `scoped` | Direction Role | `approved` | Execution Role | PM Agent |
| `approved` | Execution Role | `in_progress` | Execution Role | PM Agent |
| `in_progress` | Execution Role | `verification_ready` | Verification Role | QA Agent |
| `verification_ready` | Verification Role | `verification_in_progress` | Verification Role | QA Agent |
| `verification_in_progress` | Verification Role | `verification_passed` | Completion Role | PM Agent |
| `verification_passed` | Completion Role | `completion_review` | Completion Role | PM Agent |
| `completion_review` | Completion Role | `done` |  |  |

## 5. Optional Hooks

아래 조건은 프로젝트별 Role 매핑에 따라 추가 검토 관점으로 처리한다.

| 조건 | 추가 검토 관점 | 담당 |
|---|---|---|
| 기술 결정 문서 | `technical_review` | Lead Role 또는 Direction Role |
| 보안/개인정보 정책 문서 | `security_check` | Verification Role |
| 배포 문서 | `release_planning`, `release_check` | Release Role 또는 Verification Role |

## 6. 완료 조건

- 문서 목적과 적용 범위가 명확하다.
- 기존 문서와 충돌하지 않는다.
- 초안, 확정, 실행 지시가 구분되어 있다.
- 보호 문서 수정은 사용자 승인 범위 안에서만 이뤄졌다.

## 7. 변경 이력

| 날짜 | 변경 내용 |
|---|---|
| 2026-06-29 | Docs Workflow v1 작성 |
| 2026-06-29 | Task Queue 기반 기본 흐름 반영 |
| 2026-07-02 | workflow 기준 status/target_agent 전이 표 추가 |
| 2026-07-09 | vNext 상태 체계와 책임 단계 전이표 반영 |
| 2026-07-09 | Agent 고정 표현을 Role 기반 책임으로 개정 |

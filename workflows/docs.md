# Docs Workflow

작성일: 2026-06-29  
상태: Draft v1

## 1. 용도

운영 문서, 기획 문서, 개발 문서, 인수인계 문서, 템플릿 문서를 작성하거나 정리할 때 사용한다.

## 2. 기본 흐름

```text
PM creates docs Task -> PM updates docs -> QA reviews -> PM closes
```

현재 v1에서는 별도 문서 전담 Agent를 두지 않는다. PM Agent가 문서 초안 작성을 담당하고 QA Agent가 일관성을 검토한다. 단, `.ai/` 운영 문서는 `.ai/document_governance.md` 기준으로 사용자 승인 후만 수정한다.

## 3. 단계별 책임

| 단계 | Capability | 기본 Agent | 산출물 |
|---|---|---|---|
| 문서 목적 정의 | `planning` | PM Agent | 문서 범위, 독자, 완료 기준 |
| 문서 작성 | `documentation` | PM Agent | 문서 초안 |
| 검토 | `qa_review`, `risk_review` | QA Agent | 문서 일관성 검토 |
| 확정 판단 | `approval_management` | PM Agent / Product Owner | 반영/보류 판단 |

## 4. Optional Hooks

v1에서는 별도 Agent hook을 추가하지 않는다. 아래 조건은 PM 또는 QA의 추가 검토 관점으로 처리한다.

| 조건 | 추가 검토 관점 | 담당 |
|---|---|---|
| 기술 결정 문서 | `technical_review` | PM Agent |
| 보안/개인정보 정책 문서 | `security_check` | QA Agent |
| 배포 문서 | `release_planning`, `release_check` | PM Agent / QA Agent |

## 5. 완료 조건

- 문서 목적과 적용 범위가 명확하다.
- 기존 문서와 충돌하지 않는다.
- 초안, 확정, 실행 지시가 구분되어 있다.
- 보호 문서 수정은 사용자 승인 범위 안에서만 이뤄졌다.

## 6. 변경 이력

| 날짜 | 변경 내용 |
|---|---|
| 2026-06-29 | Docs Workflow v1 작성 |
| 2026-06-29 | Task Queue 기반 기본 흐름 반영 |

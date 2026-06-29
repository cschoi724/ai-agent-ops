# Release Workflow

작성일: 2026-06-29  
상태: Draft v1

## 1. 용도

배포 준비, 버전 관리, 태그, 릴리즈 노트, 배포 전 QA를 진행할 때 사용한다.

## 2. 기본 흐름

```text
PM -> QA -> PM -> Product Owner Approval
```

현재 v1에서는 별도 릴리즈 전담 Agent를 두지 않는다. PM Agent와 QA Agent가 릴리즈 준비 항목을 나누어 확인한다.

## 3. 단계별 책임

| 단계 | Capability | 기본 Agent | 산출물 |
|---|---|---|---|
| 릴리즈 범위 정리 | `planning`, `release_planning` | PM Agent | 릴리즈 범위, 버전 후보 |
| 배포 전 검증 | `qa_review`, `release_check` | QA Agent | 배포 전 QA 보고 |
| 릴리즈 문서 | `documentation` | PM Agent | 릴리즈 노트 |
| 최종 승인 | `approval_management` | PM Agent / Product Owner | 배포 승인/보류 |

## 4. Optional Hooks

v1에서는 별도 Agent hook을 추가하지 않는다. 아래 조건은 PM 또는 QA의 추가 검토 관점으로 처리한다.

| 조건 | 추가 검토 관점 | 담당 |
|---|---|---|
| 보안/개인정보 변경 포함 | `security_check` | QA Agent |
| 외부 SDK/정책 변경 포함 | `technical_review` | PM Agent |
| 사용자 문서 필요 | `documentation` | PM Agent |

## 5. 완료 조건

- 릴리즈 범위가 명확하다.
- 버전/빌드 번호 변경 여부가 정리됐다.
- 배포 전 QA 결과가 있다.
- 릴리즈 노트 또는 변경 요약이 있다.
- Product Owner가 배포 여부를 승인했다.

## 6. 변경 이력

| 날짜 | 변경 내용 |
|---|---|
| 2026-06-29 | Release Workflow v1 작성 |

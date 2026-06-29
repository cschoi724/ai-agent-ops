# Bugfix Workflow

작성일: 2026-06-29  
상태: Draft v1

## 1. 용도

기존 동작 오류, 회귀, 빌드 실패, 테스트 실패를 수정할 때 사용한다.

## 2. 기본 흐름

```text
PM -> Development -> QA -> PM
```

긴급하고 범위가 작으면 PM Agent가 원인 확인과 수정 범위를 짧게 정리한 뒤 Development Agent로 넘긴다.

## 3. 단계별 책임

| 단계 | Capability | 기본 Agent | 산출물 |
|---|---|---|---|
| 문제 정의 | `planning`, `task_routing` | PM Agent | 증상, 재현 조건, 수정 범위 |
| 수정 | `implementation`, `developer_verification` | Development Agent | 수정 코드, 재검증 결과 |
| 회귀 검증 | `qa_review`, `risk_review` | QA Agent | QA 보고, 회귀 위험 |
| 통합 판단 | `approval_management` | PM Agent | 커밋/재작업 판단 |

## 4. Optional Hooks

v1에서는 별도 Agent hook을 추가하지 않는다. 아래 조건은 PM 또는 QA의 추가 검토 관점으로 처리한다.

| 조건 | 추가 검토 관점 | 담당 |
|---|---|---|
| 인증, 보안, 개인정보, 로그 관련 버그 | `security_check` | QA Agent |
| 구조적 원인이 의심됨 | `technical_review` | PM Agent가 정리, Development Agent가 구현 관점 검토 |
| 외부 SDK/API 이슈가 의심됨 | `technical_review` | PM Agent가 조사 항목 정리 |

## 5. 완료 조건

- 원인 또는 수정 근거가 설명됐다.
- 재현 케이스 또는 검증 기준이 명시됐다.
- 수정 범위가 문제 해결에 필요한 범위를 넘지 않는다.
- QA Agent가 회귀 위험을 정리했다.

## 6. 변경 이력

| 날짜 | 변경 내용 |
|---|---|
| 2026-06-29 | Bugfix Workflow v1 작성 |

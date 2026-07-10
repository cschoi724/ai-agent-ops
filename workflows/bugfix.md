# Bugfix Workflow

작성일: 2026-06-29  
상태: Draft vNext

## 1. 용도

기존 동작 오류, 회귀, 빌드 실패, 테스트 실패를 수정할 때 사용한다.

## 2. 기본 흐름

```text
Direction scopes bugfix Task -> Lead coordinates impact -> Execution fixes -> Verification checks regression -> Completion closes
```

긴급하고 범위가 작아도 Lead Role 또는 Direction Role은 Task 파일에 원인 확인 범위와 수정 범위를 짧게 남긴 뒤 Execution Role이 Queue에서 확인하게 한다.

## 3. 단계별 책임

| 단계 | Capability | 기본 Role | Bootstrap Agent 예시 | 산출물 |
|---|---|---|---|---|
| Direction | `planning`, `task_routing` | Direction Role | PM Agent | 증상, 재현 조건, 수정 범위 |
| Coordination | `team_coordination`, `ownership_review` | Lead Role | PM Agent 또는 Team Lead | 영향 범위, dependency, allowed paths |
| Execution | `implementation`, `developer_verification` | Execution Role | Development Agent | 수정 코드, 재검증 결과 |
| Verification | `qa_review`, `risk_review` | Verification Role | QA Agent | 검증 보고, 회귀 위험 |
| Completion | `approval_management` | Completion Role | PM Agent 또는 Team Lead | 완료/재작업 판단 |

## 4. 기본 상태 전이

| 현재 status | 수행 Role | 다음 status | 다음 target_role | Bootstrap target_agent |
|---|---|---|---|---|
| `proposed` | Lead Role | `scoped` | Direction Role | PM Agent |
| `scoped` | Direction Role | `approved` | Execution Role | Development Agent |
| `approved` | Execution Role | `in_progress` | Execution Role | Development Agent |
| `in_progress` | Execution Role | `verification_ready` | Verification Role | QA Agent |
| `verification_ready` | Verification Role | `verification_in_progress` | Verification Role | QA Agent |
| `verification_in_progress` | Verification Role | `verification_passed` | Completion Role | PM Agent |
| `verification_passed` | Completion Role | `completion_review` | Completion Role | PM Agent |
| `completion_review` | Completion Role | `done` |  |  |

## 5. Optional Hooks

아래 조건은 프로젝트별 Role 매핑에 따라 추가 검토 관점으로 처리한다.

| 조건 | 추가 검토 관점 | 담당 |
|---|---|---|
| 인증, 보안, 개인정보, 로그 관련 버그 | `security_check` | Verification Role |
| 구조적 원인이 의심됨 | `technical_review` | Lead Role이 정리, Execution Role이 구현 관점 검토 |
| 외부 SDK/API 이슈가 의심됨 | `technical_review` | Lead Role 또는 Direction Role이 조사 항목 정리 |

## 6. 완료 조건

- 원인 또는 수정 근거가 설명됐다.
- 재현 케이스 또는 검증 기준이 명시됐다.
- 수정 범위가 문제 해결에 필요한 범위를 넘지 않는다.
- Verification Role이 회귀 위험을 정리했다.

## 7. 변경 이력

| 날짜 | 변경 내용 |
|---|---|
| 2026-06-29 | Bugfix Workflow v1 작성 |
| 2026-06-29 | Task Queue 기반 기본 흐름 반영 |
| 2026-07-02 | workflow 기준 status/target_agent 전이 표 추가 |
| 2026-07-09 | vNext 상태 체계와 책임 단계 전이표 반영 |
| 2026-07-09 | Agent 고정 표현을 Role 기반 책임으로 개정 |

# Feature Workflow

작성일: 2026-06-29  
상태: Draft vNext

## 1. 용도

신규 기능 구현 또는 기존 기능 확장에 사용한다.

## 2. 기본 흐름

```text
Direction scopes feature Task -> Lead coordinates -> Execution implements -> Verification checks -> Completion closes
```

## 3. 단계별 책임

| 단계 | Capability | 기본 Role | Bootstrap Agent 예시 | 산출물 |
|---|---|---|---|---|
| Direction | `planning`, `task_routing` | Direction Role | PM Agent | `.ai_project/tasks/` Task |
| Coordination | `team_coordination`, `ownership_review` | Lead Role | PM Agent 또는 Team Lead | scope, ownership, allowed paths |
| Execution | `implementation`, `developer_verification` | Execution Role | Development Agent | 코드/문서 변경, 작업 보고 |
| Verification | `qa_review`, `risk_review` | Verification Role | QA Agent | 검증 보고 |
| Completion | `approval_management` | Completion Role | PM Agent 또는 Team Lead | 완료/보류/재작업 판단 |

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
| 구조 변경, 모듈 경계 변경, 기술 선택이 있음 | `technical_review` | Lead Role 또는 Execution Role |
| 인증, 권한, 결제, 개인정보, 로그 민감정보가 관련됨 | `security_check` | Verification Role |
| 사용자/운영/개발 문서 변경이 큼 | `documentation` | Execution Role 작성, Verification Role 검토 |
| 배포 대상 기능임 | `release_planning`, `release_check` | Release Role 또는 Verification Role |

## 6. 완료 조건

- Task 승인 범위의 구현이 완료됐다.
- Execution Role이 가능한 검증을 수행했다.
- Verification Role이 `PASS`, `PASS_WITH_RISK`, `FAIL`, `BLOCKED` 중 하나로 결과를 분류했다.
- 남은 리스크와 사용자 결정 항목이 분리되어 있다.

## 7. 변경 이력

| 날짜 | 변경 내용 |
|---|---|
| 2026-06-29 | Feature Workflow v1 작성 |
| 2026-06-29 | Task Queue 기반 기본 흐름 반영 |
| 2026-07-02 | workflow 기준 status/target_agent 전이 표 추가 |
| 2026-07-09 | vNext 상태 체계와 책임 단계 전이표 반영 |
| 2026-07-09 | Agent 고정 표현을 Role 기반 책임으로 개정 |

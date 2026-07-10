# Capabilities

작성일: 2026-06-29  
상태: Draft vNext  
범위: 조직형 AI Agent 운영체계의 capability 정의

## 1. 목적

이 문서는 `ai-agent-ops` vNext에서 Role이 수행할 수 있는 capability를 정의한다.

Capability는 Agent 이름이 아니라 수행 가능한 능력이다. 하나의 Role은 여러 capability를 가질 수 있고, 하나의 capability는 운영 성숙도에 따라 다른 Role 또는 Agent로 위임될 수 있다.

## 2. 기본 원칙

- Workflow는 가능하면 Agent 이름보다 Role과 capability를 기준으로 설계한다.
- 실제 Task 실행 라우팅은 `target_agent`, `target_role`, `required_capabilities` 순서로 판단한다.
- Capability는 명시적 라우팅 불일치를 덮어쓸 수 없다.
- 하나의 Agent는 세션에서 부여된 Role 범위 안에서만 capability를 수행한다.
- Capability 소유권은 고정 상한이 아니라 초기 bootstrap 매핑이다.
- 새 Division 또는 Team이 활성화되면 capability를 해당 Role로 위임할 수 있다.
- AI Ops 관련 capability는 기본 제품 Task 실행 capability가 아니라 운영체계 점검 capability다.

## 3. Capability 분류

vNext capability는 아래 Role 범주에 연결된다.

| Role 범주 | Capability 그룹 |
|---|---|
| Direction Role | 방향, 우선순위, 승인, Task 후보 정리 |
| Lead Role | scope, team coordination, ownership, dependency, 병렬 작업 |
| Execution Role | 구현, 문서 작성, 리팩터링, 개발자 검증, 작업 보고 |
| Verification Role | QA, 테스트, 리스크, 보안, rework 판단 |
| Completion Role | 완료 확정, 잔여 리스크 수용, 후속 Task 판단 |
| Release Role | release planning, release check, release governance |
| Ops Governance Role | 운영 감사, workflow 개선, Role/Capability 경계, migration |

## 4. Core Capabilities

| Capability | 설명 | 기본 Role | Bootstrap Agent |
|---|---|---|---|
| `planning` | 현재 상태 파악, Need 정리, 다음 작업 후보 정리 | Direction Role | PM Agent |
| `task_routing` | Task 유형 분류, workflow 선택, 첫 처리 Role 제안 | Direction Role | PM Agent |
| `priority_management` | priority, Queue 영향, 기존 Task와의 관계 정리 | Direction Role | PM Agent |
| `approval_management` | 사용자 또는 Product Owner 승인 게이트 관리 | Direction Role | PM Agent |
| `task_queue_management` | `.ai_project/tasks/` Task 생성, 상태 관리, board 요약 갱신 | Direction Role | PM Agent |
| `scope_definition` | 작업 범위, 제외 범위, 완료 기준 정리 | Direction Role / Lead Role | PM Agent |
| `team_coordination` | Team 배정, cross-team 조율, Lead 판단 | Lead Role | PM Agent / Development Lead |
| `ownership_review` | path/domain ownership 충돌 확인 | Lead Role | PM Agent / Team Lead |
| `dependency_management` | `depends_on`, `blocks`, 선후행 Task 정리 | Lead Role | PM Agent / Team Lead |
| `parallel_planning` | `parallel_group`, 병렬 가능 여부, 충돌 위험 판단 | Lead Role | PM Agent / Team Lead |
| `branch_management` | task branch 전략, branch 생성/관리 기준 확인 | Lead Role / Execution Role | PM Agent / Development Agent |
| `source_of_truth_mapping` | Task 기준 문서와 프로젝트 문서 우선순위 연결 | Lead Role / Direction Role | PM Agent |
| `technical_review` | 기술 선택지, 구조 영향, 외부 SDK/API 조사 항목 정리 | Lead Role / Execution Role | PM Agent / Development Agent |
| `implementation` | 승인된 범위의 코드/문서 구현 | Execution Role | Development Agent |
| `refactoring` | 승인된 범위의 구조 개선과 정리 | Execution Role | Development Agent |
| `documentation` | Task 문서, 운영 문서, 변경 요약 작성 | Execution Role / Direction Role | PM Agent |
| `developer_verification` | 개발자가 수행하는 빌드/테스트/수동 확인 | Execution Role | Development Agent |
| `task_reporting` | 작업 완료 보고 작성 | Execution Role | Development Agent |
| `pr_creation` | Task branch push 후 PR 생성과 Task에 PR 정보 기록 | Execution Role | Development Agent |
| `qa_review` | 변경 결과 검증 | Verification Role | QA Agent |
| `pr_review` | PR diff, 변경 범위, 리뷰 코멘트 확인 | Verification Role | QA Agent |
| `ci_check` | CI 상태 확인과 실패 원인 분류 | Verification Role / Lead Role | QA Agent / PM Agent |
| `test_execution` | 테스트 실행, 재현 확인, 결과 기록 | Verification Role | QA Agent |
| `risk_review` | 회귀 위험과 잔여 리스크 정리 | Verification Role | QA Agent |
| `security_check` | 인증, 권한, 개인정보, 민감정보 로그 노출 점검 | Verification Role | QA Agent |
| `release_check` | 배포 전 검증 항목 확인 | Verification Role / Release Role | QA Agent |
| `rework_request` | rework 요청 작성, 재검증 기준 정리 | Verification Role / Completion Role | QA Agent |
| `completion_review` | 검증 결과 수용, 잔여 리스크 판단, 완료 확정 준비 | Completion Role | PM Agent / Team Lead |
| `merge_coordination` | PR merge 가능 여부, merge 방식, 후속 정리 판단 | Lead Role / Completion Role | PM Agent / Team Lead |
| `followup_task_planning` | 후속 Task 필요 여부 판단과 후보 정리 | Completion Role / Direction Role | PM Agent |
| `release_planning` | 버전, 릴리즈 범위, 배포 승인 항목 정리 | Release Role / Direction Role | PM Agent |
| `release_governance` | release gate, rollback, 운영 인계 조건 확인 | Release Role | PM Agent / QA Agent |
| `ops_audit` | Agent 운영 문서와 실제 운영 상태의 충돌 점검 | Ops Governance Role | AI Ops Agent |
| `process_governance` | Task Queue, 승인, lock, report/QA 흐름의 운영 규칙 점검 | Ops Governance Role | AI Ops Agent |
| `workflow_governance` | workflow 상태, 전이, Role 라우팅 개선 | Ops Governance Role | AI Ops Agent |
| `agent_boundary_review` | Agent/Role/Capability 경계와 새 Role 추가 영향 검토 | Ops Governance Role | AI Ops Agent |
| `ops_migration` | 새 프로젝트 또는 기존 프로젝트에 AI Agent 운영 체계 도입 | Ops Governance Role | AI Ops Agent |

## 5. Bootstrap Agent 매핑

초기 운영에서는 기존 Agent를 아래 capability 그룹에 매핑한다.

| Bootstrap Agent | 기본 Role | 주요 Capability |
|---|---|---|
| PM Agent | Direction Role, 일부 Lead/Completion/Release Role | `planning`, `task_routing`, `priority_management`, `approval_management`, `task_queue_management`, `scope_definition`, `completion_review`, `merge_coordination`, `release_planning` |
| Development Agent | Execution Role | `implementation`, `refactoring`, `documentation`, `developer_verification`, `task_reporting`, `branch_management`, `pr_creation`, 일부 `technical_review` |
| QA Agent | Verification Role, 일부 Release Role | `qa_review`, `pr_review`, `ci_check`, `test_execution`, `risk_review`, `security_check`, `release_check`, `rework_request` |
| AI Ops Agent | Ops Governance Role | `ops_audit`, `process_governance`, `workflow_governance`, `agent_boundary_review`, `ops_migration` |

이 매핑은 초기값이다. iOS Team이 활성화되면 예를 들어 아래처럼 위임할 수 있다.

| Capability | 위임 대상 |
|---|---|
| `team_coordination` | iOS Team Lead |
| `ownership_review` | iOS Team Lead / Auth Owner |
| `implementation` | iOS Development Agent |
| `developer_verification` | iOS Test Agent 또는 iOS Development Agent |
| `qa_review` | iOS QA Agent |
| `release_check` | iOS Release Agent |

## 6. Capability와 Task Metadata

Task는 필요한 capability를 `required_capabilities`에 기록한다.

```yaml
target_agent: {{EXECUTION_AGENT}}
target_role: Execution Role
required_capabilities:
  - implementation
  - developer_verification
```

라우팅 기준:

1. `target_agent`가 현재 세션 Role 또는 Agent와 맞는지 확인한다.
2. `target_agent`가 비어 있거나 `any`이면 `target_role`을 확인한다.
3. `target_role`도 비어 있거나 `any`이면 `required_capabilities`를 확인한다.
4. Capability만 맞고 라우팅이 맞지 않으면 실행하지 않는다.

## 7. Capability Hook 예시

Workflow 문서에서는 아래처럼 capability hook을 사용한다.

```text
Task가 인증/권한/개인정보/로그를 건드리면 `security_check` capability를 가진 Verification Role의 검증을 필수 항목에 추가한다.
```

```text
Task가 여러 팀의 allowed_paths를 건드리면 `ownership_review`와 `team_coordination` capability를 가진 Lead Role의 scoped 단계를 필수로 둔다.
```

```text
Task가 release gate에 영향을 주면 `release_check`와 `release_governance` capability를 가진 Verification 또는 Release Role의 확인을 추가한다.
```

## 8. Capability 위임 기준

아래 상황이 반복되면 capability 위임 또는 새 Role 분리를 검토한다.

- PM Agent의 Direction/Lead/Completion 책임이 과도하게 커진다.
- QA Agent의 보안/릴리즈 검증 책임이 반복적으로 커진다.
- 특정 Team ownership 확인이 여러 Task에서 반복된다.
- 특정 capability가 독립 검토 단계로 계속 필요하다.
- 기존 Role로 표현하면 책임이 모호해진다.
- 프로젝트 중간에 Agent 교체 가능성을 열어둬야 한다.
- Product Owner가 해당 책임을 별도 Agent 또는 Team으로 분리하길 원한다.

위임할 때는 아래를 함께 갱신한다.

- `.ai/models/role_model.md`
- `.ai/models/agent_registry.md`
- `.ai/models/capabilities.md`
- 관련 `.ai/workflows/*.md`
- `.ai_project/agent_registry.md`
- 관련 Task template 또는 project override

## 9. Capability 추가 기준

새 capability는 아래 조건 중 하나 이상을 만족할 때 추가한다.

- 여러 workflow에서 반복적으로 필요하다.
- 특정 Role의 핵심 책임을 명확히 분리해야 한다.
- 기존 capability로 표현하면 책임이 모호해진다.
- 특정 Team이나 Division의 ownership을 표현해야 한다.
- 별도 검증, 승인, release gate가 필요하다.
- 자동화나 checker가 나중에 해당 능력을 독립적으로 검사해야 한다.

새 capability를 추가할 때는 아래 항목을 정의한다.

- capability 이름
- 설명
- 기본 Role
- bootstrap Agent
- 관련 workflow 상태
- 산출물
- 금지사항 또는 제한

## 10. 금지사항

- Capability가 맞다는 이유만으로 `target_agent` 또는 `target_role`이 다른 Task를 실행하지 않는다.
- Capability를 Agent 권한의 고정 목록으로 해석하지 않는다.
- 모든 capability를 PM Agent에 계속 누적하지 않는다.
- Verification capability를 가진 Agent가 Completion Role의 완료 확정을 대신하지 않는다.
- Ops Governance capability를 가진 Agent가 제품 Task 실행 권한을 임의로 가져오지 않는다.

## 11. 변경 이력

| 날짜 | 변경 내용 |
|---|---|
| 2026-06-29 | Capability 정의 v1 작성 |
| 2026-06-29 | Task Queue 관리 capability 추가 |
| 2026-06-30 | AI Ops Agent 운영 점검 capability 추가 |
| 2026-07-01 | AI Ops Agent 운영 마이그레이션 capability 추가 |
| 2026-07-09 | vNext Role 기반 capability 체계로 개정 |

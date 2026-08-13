# Role Handoff Policy

작성일: 2026-07-13
상태: Draft vNext
범위: Role 간 인계 기준과 기본 workflow용 예시

## 1. 목적

이 문서는 Agent가 Role 경계를 넘겨 작업을 이어갈 때 남겨야 하는 표준 인계 메시지를 정의한다.

Task 상태 전이 자체는 `.ai/runtime/workflow.md`와 `.ai/runtime/task_queue.md`를 따른다. 이 문서는 전이 후 다음 Agent가 같은 맥락에서 바로 시작할 수 있도록 무엇을 전달해야 하는지만 정한다.

Agent 세션 분리와 보조 위임 기준은 `.ai/policies/session_orchestration_policy.md`를 따른다.

아래 Lead -> Execution, Execution -> Verification, Verification -> Completion, Rework/Blocked -> Lead 문구는 기본 workflow의 표준 예시다. 프로젝트별 workflow나 `.ai_project/workflow_overrides.md`가 다른 Role 순서, 추가 게이트, 생략 단계를 정의하면 그 정의가 우선한다.

## 2. 기본 원칙

- Role 전환은 Task의 `status`, `target_agent`, `target_role` 변경으로 표현한다.
- 다음 담당이 다른 Agent이거나 독립 분리 Role이면 현재 Agent는 다음 단계까지 대신 처리하지 않는다.
- 같은 Agent의 `assigned_roles` 안에서 허용된 Role로 이동하면 Agent 정체성을 유지하고 `active_role`만 바꿔 같은 세션에서 계속할 수 있다.
- 상태 전이 결과는 compact receipt 하나를 공통 입력으로 사용하고, Task/report/handoff/최종 응답에 같은 값을 다시 손으로 입력하지 않는다.
- 가능하면 `aiops handoff create TASK_ID --from ROLE --to ROLE --next-action TEXT`로 인계 파일을 만든다.
- 다중 worktree 운영에서는 인계 전에 `aiops sync-status` 또는 동등한 fetch/SHA 확인을 수행하고 `status_ref`, `status_ref_sha`를 남긴다.
- 인계 메시지는 Codex와 Claude 모두 이해할 수 있는 일반 문장과 Task metadata로 작성한다.
- 다음 Agent에게 역할을 명시한다. 예: `너는 Development Agent / Execution Role이야.`
- 다음 Role을 별도 세션에서 시작해야 하면 새 세션 시작에 필요한 정보를 함께 남긴다.
- 인계 메시지는 실행 지시가 아니라 다음 Role이 읽어야 할 시작 컨텍스트다. 승인, commit, push, merge, 배포 권한은 프로젝트 정책을 따른다.
- 실제 다음 Role은 Task의 `workflow`, `status`, `target_agent`, `target_role`, 프로젝트별 override를 기준으로 정한다.
- 이 문서의 상태별 표준 문구와 다른 전이가 필요하면 필수 인계 필드는 유지하고 Role 이름, 상태, 다음 행동만 해당 workflow에 맞게 바꾼다.
- 어떤 세션을 열지 모르면 먼저 `aiops session-guide`를 실행하고, 실제 첫 메시지는 `aiops role prompt ROLE --task TASK_ID`로 만든다.

## 3. Compact transition receipt

모든 상태 전이는 아래 필드를 `aiops.transition_receipt.v1`으로 남긴다.

```text
Task: {{TASK_ID}}
상태: {{FROM_STATUS}} -> {{TO_STATUS}}
처리: {{ACTOR_AGENT}} / {{ACTIVE_ROLE}}
다음: {{NEXT_AGENT}} / {{NEXT_ROLE}}
결과: {{RESULT_SUMMARY}}
근거: {{EVIDENCE_OR_SKIP_REASON}}
위험: {{RISKS_OR_NONE}}
차단: {{BLOCKERS_OR_NONE}}
다음 작업: {{NEXT_ACTION}}
```

`actor.role`은 registry의 전체 Role이 아니라 전이 시점의 `active_role`이다. `next.agent` 또는 `next.role` 중 하나 이상과 `next.action`은 반드시 있어야 한다. 검증을 실행하지 않았다면 빈 근거 대신 `validation_skip_reason`을 남긴다.

## 4. Receiver start context

Handoff는 receipt를 반복하는 보고서가 아니라 다음 담당이 시작하는 데 필요한 컨텍스트다. 기존 `aiops.handoff.v1`은 호환성을 위해 유지하며 아래 정보만 receipt에 덧붙인다.

- receipt 경로 또는 receipt 내용
- source of truth
- allowed paths
- report/QA 경로
- changed/affected paths
- canonical status ref/SHA와 worktree 정보

Task report와 QA report는 상세 근거가 필요한 경우에만 위 정보를 확장한다. 최종 채팅 보고는 기본적으로 compact receipt만 보여준다.

## 5. 기본 workflow 상태별 표준 문구

### 5.1 Lead -> Execution

사용 시점: `scoped` 또는 승인 이후 `approved` Task를 Execution Role로 넘길 때.

```text
Task: {{TASK_ID}}
상태: scoped -> approved
처리: {{LEAD_AGENT}} / Lead Role
다음: {{EXECUTION_AGENT}} / Execution Role
결과: 실행 범위와 승인 조건 확정
근거: {{TASK_FILE}}
위험/차단: {{RISKS_OR_BLOCKERS_OR_NONE}}
다음 작업: allowed_paths 안에서 구현하고 자체 검증 결과를 남긴다.
```

### 5.2 Execution -> Verification

사용 시점: 실행 완료 후 `verification_ready`로 넘길 때.

```text
Task: {{TASK_ID}}
상태: in_progress -> verification_ready
처리: {{EXECUTION_AGENT}} / Execution Role
다음: {{VERIFICATION_AGENT}} / Verification Role
결과: 구현과 자체 검증 완료
근거: {{TASK_REPORT_PATH}}
위험/차단: {{RISKS_OR_BLOCKERS_OR_NONE}}
다음 작업: 변경 결과를 독립 검증하고 PASS/PASS_WITH_RISK/FAIL/BLOCKED를 판단한다.
```

### 5.3 Verification -> Completion

사용 시점: 검증 통과 후 `verification_passed`로 넘길 때.

```text
Task: {{TASK_ID}}
상태: verification_in_progress -> verification_passed
처리: {{VERIFICATION_AGENT}} / Verification Role
다음: {{COMPLETION_AGENT}} / Completion Role
결과: 독립 검증 통과
근거: {{QA_REPORT_PATH}}
위험/차단: {{RISKS_OR_BLOCKERS_OR_NONE}}
다음 작업: 검증 결과와 잔여 리스크를 수용하고 done 가능 여부를 판단한다.
```

### 5.4 Verification / Completion -> Lead

사용 시점: `rework_requested` 또는 `blocked`로 되돌릴 때.

```text
Task: {{TASK_ID}}
상태: {{FROM_STATUS}} -> {{rework_requested_OR_blocked}}
처리: {{ACTOR_AGENT}} / {{ACTIVE_ROLE}}
다음: {{LEAD_AGENT}} / Lead Role
결과: 완료 조건 미충족
근거: {{REPORT_OR_QA_PATHS}}
위험/차단: {{RISKS_OR_BLOCKERS}}
다음 작업: 재작업 범위, ownership, source of truth와 승인 필요 여부를 다시 정리한다.
```

## 6. 금지사항

- 다음 Role의 검증, 완료, merge 판단을 현재 Role이 대신 수행하지 않는다.
- 인계 메시지 없이 `target_role`만 바꾸지 않는다.
- `다음 Agent에게 전달할 말`에 실제로 확인하지 않은 테스트, 승인, 리스크 해소를 적지 않는다.
- Codex 전용 명령이나 Claude 전용 명령을 표준 문구로 강제하지 않는다.
- 보조 작업 결과를 독립 Role 세션의 검증이나 완료 판정으로 표기하지 않는다.

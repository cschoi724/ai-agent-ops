# Role Handoff Policy

작성일: 2026-07-13
상태: Draft vNext
범위: Role 간 인계 기준과 기본 workflow용 예시

## 1. 목적

이 문서는 Agent가 Role 경계를 넘겨 작업을 이어갈 때 남겨야 하는 표준 인계 메시지를 정의한다.

Task 상태 전이 자체는 `.ai/runtime/workflow.md`와 `.ai/runtime/task_queue.md`를 따른다. 이 문서는 전이 후 다음 Agent가 같은 맥락에서 바로 시작할 수 있도록 무엇을 전달해야 하는지만 정한다.

아래 Lead -> Execution, Execution -> Verification, Verification -> Completion, Rework/Blocked -> Lead 문구는 기본 workflow의 표준 예시다. 프로젝트별 workflow나 `.ai_project/workflow_overrides.md`가 다른 Role 순서, 추가 게이트, 생략 단계를 정의하면 그 정의가 우선한다.

## 2. 기본 원칙

- Role 전환은 Task의 `status`, `target_agent`, `target_role` 변경으로 표현한다.
- 다음 담당이 현재 세션 Role과 다르면 현재 Agent는 다음 단계까지 이어서 처리하지 않는다.
- 다음 담당에게 넘길 말은 Task 파일의 `Next Agent Handoff` 섹션과 최종 응답에 같은 내용으로 남긴다.
- 인계 메시지는 Codex와 Claude 모두 이해할 수 있는 일반 문장과 Task metadata로 작성한다.
- 다음 Agent에게 역할을 명시한다. 예: `너는 Development Agent / Execution Role이야.`
- 인계 메시지는 실행 지시가 아니라 다음 Role이 읽어야 할 시작 컨텍스트다. 승인, commit, push, merge, 배포 권한은 프로젝트 정책을 따른다.
- 실제 다음 Role은 Task의 `workflow`, `status`, `target_agent`, `target_role`, 프로젝트별 override를 기준으로 정한다.
- 이 문서의 상태별 표준 문구와 다른 전이가 필요하면 필수 인계 필드는 유지하고 Role 이름, 상태, 다음 행동만 해당 workflow에 맞게 바꾼다.

## 3. 필수 인계 필드

Role이 바뀌는 상태 전이에서는 아래 항목을 채운다.

```text
다음 Agent에게 전달할 말:

너는 {{NEXT_AGENT}} / {{NEXT_ROLE}}이야.
Task {{TASK_ID}}를 이어서 처리해줘.

- 현재 상태: {{CURRENT_STATUS}}
- 다음에 해야 할 일: {{NEXT_ACTION}}
- 기준 문서: {{SOURCE_OF_TRUTH}}
- 허용 경로: {{ALLOWED_PATHS}}
- 참고 산출물: {{REPORT_OR_QA_PATHS}}
- 변경/검토 대상: {{CHANGED_OR_AFFECTED_PATHS}}
- 남은 리스크: {{RISKS_OR_NONE}}
- 차단/결정 필요: {{BLOCKERS_OR_DECISIONS_OR_NONE}}
- 주의: 현재 Task의 workflow, status, target_agent, target_role이 네 Role과 맞는지 먼저 확인해줘.
```

## 4. 기본 workflow 상태별 표준 문구

### 4.1 Lead -> Execution

사용 시점: `scoped` 또는 승인 이후 `approved` Task를 Execution Role로 넘길 때.

```text
다음 Agent에게 전달할 말:

너는 {{EXECUTION_AGENT}} / Execution Role이야.
Task {{TASK_ID}}는 승인된 실행 Task야.

- 현재 상태: approved
- 다음에 해야 할 일: allowed_paths 안에서 작업을 수행하고, 자체 검증 후 task report를 작성해줘.
- 기준 문서: {{SOURCE_OF_TRUTH}}
- 허용 경로: {{ALLOWED_PATHS}}
- 참고 산출물: {{TASK_FILE}}
- 변경/검토 대상: {{AFFECTED_PATHS}}
- 남은 리스크: {{RISKS_OR_NONE}}
- 차단/결정 필요: {{BLOCKERS_OR_DECISIONS_OR_NONE}}
- 완료 시: status를 verification_ready로 바꾸고 target_role을 Verification Role로 넘겨줘.
```

### 4.2 Execution -> Verification

사용 시점: 실행 완료 후 `verification_ready`로 넘길 때.

```text
다음 Agent에게 전달할 말:

너는 {{VERIFICATION_AGENT}} / Verification Role이야.
Task {{TASK_ID}}의 실행 결과를 독립적으로 검증해줘.

- 현재 상태: verification_ready
- 다음에 해야 할 일: task report, 변경 파일, source of truth를 기준으로 PASS/PASS_WITH_RISK/FAIL/BLOCKED를 판단해줘.
- 기준 문서: {{SOURCE_OF_TRUTH}}
- 허용 경로: {{ALLOWED_PATHS}}
- 참고 산출물: {{TASK_REPORT_PATH}}
- 변경/검토 대상: {{CHANGED_PATHS}}
- 남은 리스크: {{RISKS_OR_NONE}}
- 차단/결정 필요: {{BLOCKERS_OR_DECISIONS_OR_NONE}}
- 통과 시: status를 verification_passed로 바꾸고 target_role을 Completion Role로 넘겨줘.
- 수정 필요 시: status를 rework_requested로 바꾸고 수정 항목을 명확히 남겨줘.
```

### 4.3 Verification -> Completion

사용 시점: 검증 통과 후 `verification_passed`로 넘길 때.

```text
다음 Agent에게 전달할 말:

너는 {{COMPLETION_AGENT}} / Completion Role이야.
Task {{TASK_ID}}의 완료 확정 여부를 검토해줘.

- 현재 상태: verification_passed
- 다음에 해야 할 일: 검증 결과, 잔여 리스크, 후속 Task 필요 여부를 확인하고 done 처리 가능성을 판단해줘.
- 기준 문서: {{SOURCE_OF_TRUTH}}
- 허용 경로: {{ALLOWED_PATHS}}
- 참고 산출물: {{QA_REPORT_PATH}}
- 변경/검토 대상: {{CHANGED_OR_AFFECTED_PATHS}}
- 남은 리스크: {{RISKS_OR_NONE}}
- 차단/결정 필요: {{BLOCKERS_OR_DECISIONS_OR_NONE}}
- 완료 가능 시: completion_review를 거쳐 done으로 전환하고 board를 갱신해줘.
```

### 4.4 Verification / Completion -> Lead

사용 시점: `rework_requested` 또는 `blocked`로 되돌릴 때.

```text
다음 Agent에게 전달할 말:

너는 {{LEAD_AGENT}} / Lead Role이야.
Task {{TASK_ID}}의 범위 또는 차단 상태를 다시 조율해줘.

- 현재 상태: {{rework_requested_OR_blocked}}
- 다음에 해야 할 일: 재작업 범위, ownership, source of truth, 승인 필요 여부를 다시 정리해줘.
- 기준 문서: {{SOURCE_OF_TRUTH}}
- 허용 경로: {{ALLOWED_PATHS}}
- 참고 산출물: {{REPORT_OR_QA_PATHS}}
- 변경/검토 대상: {{AFFECTED_PATHS}}
- 남은 리스크: {{RISKS_OR_NONE}}
- 차단/결정 필요: {{BLOCKERS_OR_DECISIONS}}
- 재개 가능 시: scoped 또는 approved로 전환할지 사용자에게 확인해줘.
```

## 5. 금지사항

- 다음 Role의 검증, 완료, merge 판단을 현재 Role이 대신 수행하지 않는다.
- 인계 메시지 없이 `target_role`만 바꾸지 않는다.
- `다음 Agent에게 전달할 말`에 실제로 확인하지 않은 테스트, 승인, 리스크 해소를 적지 않는다.
- Codex 전용 명령이나 Claude 전용 명령을 표준 문구로 강제하지 않는다.

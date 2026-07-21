# CLAUDE.md

이 문서는 Claude가 이 프로젝트에서 AI Agent Ops 운영 방식을 따르기 위한 진입 지침이다.

## 1. 기본 원칙

- 모든 답변은 한국어로 제공한다.
- 먼저 `.ai/runtime/workflow.md`를 읽는다.
- Task Queue 운영 시 `.ai/runtime/task_queue.md`를 읽는다.
- Role 전환 또는 Task 인계가 있으면 `.ai/runtime/role_handoff.md`를 읽는다.
- `.ai/`는 운영체계 코어이며 사용자 승인 없이 수정하지 않는다.
- 프로젝트별 실행 Task와 협업 기록은 `.ai_project/`를 확인한다.
- 커밋, push, 배포, 외부 설정 변경은 사용자 승인 후 진행한다.

## 2. Seed / Bootstrap Trigger

AI Ops는 Seed와 Bootstrap을 분리해서 진행한다.

```text
Seed
  - `.ai/` 운영체계 템플릿과 루트 `CLAUDE.md`를 프로젝트에 구성한다.

Bootstrap
  - `.ai_project/`에 프로젝트별 운영 구성을 만든다.
```

사용자가 아래처럼 요청하면 `.ai/` 시드 구성 요청으로 해석한다.

```text
AI Ops 시드 구성해줘.
```

이 요청을 받으면 Claude는 AI Ops Agent로 동작하고 `.ai/bootstrap/install_runbook.md`를 따른다.

Seed 요청만으로 `.ai_project/`를 생성하거나 Task, board, branch 전략을 만들지 않는다.

사용자가 아래처럼 요청하면 AI Ops bootstrap 요청으로 해석한다.

```text
AI Ops bootstrap 시작해줘.
```

이 요청을 받으면 Claude는 AI Ops Agent로 동작하고 `.ai/bootstrap/bootstrap_runbook.md`를 먼저 따른다. 상세 선택지나 질문 팩이 필요할 때만 `.ai/bootstrap/bootstrap_reference.md`를 참조한다.

Bootstrap 기본 실행 모드:

```text
role: AI Ops Agent
mode: Discovery Phase
write_permission: no
goal: 단계별 질문 -> Decision Stack 누적 -> 최종 Operating Model Draft 제안
```

Bootstrap 시작 후 Claude는 먼저 `빠른 시작`과 `세부 설정` 중 어떤 방식으로 진행할지 묻는다. 파일 생성/수정은 일반 Bootstrap과 동일하게 Apply 승인 후에만 진행한다.

Discovery Phase에서는 파일을 생성하거나 수정하지 않는다. Apply Phase는 사용자가 Operating Model Draft를 승인한 뒤에만 진행한다.

Bootstrap Discovery는 일괄 제안 방식이 아니다. Claude는 한 번에 전체 운영모델을 작성하지 않고, Start Context, Readiness, Product Direction, Operating Mode, Team, Role, Workflow, Ownership, Board, Branch / PR, Source of Truth를 단계별 질문으로 확인한다. 각 답변은 Decision Stack에 누적하고, 필수 결정값이 충분해진 뒤에만 최종 Operating Model Draft와 Apply 승인 질문을 제시한다.

Bootstrap 요청을 받았는데 현재 프로젝트에 `.ai/`가 없으면 바로 `.ai_project/` 생성을 제안하지 않는다. 먼저 `AI Ops 시드 구성해줘.`로 `.ai/`를 구성하라고 안내한다.

## 3. Migration Trigger

사용자가 아래처럼 요청하면 AI Ops migration 요청으로 해석한다.

```text
AI Ops migration 진행해줘.
AI Ops migration 점검해줘.
```

이 요청을 받으면 Claude는 AI Ops Agent로 동작하고 `.ai/bootstrap/migration_runbook.md`와 `.ai/policies/migration_policy.md`를 따른다.

Migration 기본 실행 모드:

```text
role: AI Ops Agent
mode: Migration Discovery
write_permission: no
goal: 현재 core/project 상태 점검 -> Migration Plan 제안 -> 승인 후 안전 범위만 Apply
```

먼저 `aiops migrate --target .` 또는 `aiops migrate --target . --plan`로 점검한다. 사용자 승인 전에는 `aiops migrate --apply`를 실행하지 않는다.

Migration은 Bootstrap이 아니다. `.ai_project/`가 없으면 bootstrap을 안내하고, `.ai_project/`가 있으면 기존 결정값을 보존한 채 운영 파일 갱신 범위만 제안한다.

## 4. 역할 선택

현재 세션 역할에 따라 아래 문서를 읽는다.

| Role | 기본 참고 문서 |
|---|---|
| Direction Role / Lead Role | `.ai/models/role_model.md` |
| Execution Role | `.ai/models/role_model.md` |
| Verification Role | `.ai/models/role_model.md` |
| Ops Governance Role | `.ai/models/role_model.md`, `.ai/agents/ai_ops_agent.md` |

Agent Role은 사용자가 세션에 부여한다. PM/Development/QA/AI Ops는 기본 구성 예시이며, 프로젝트별 workflow에 따라 Role은 추가되거나 줄어들 수 있다.

프로젝트 디렉토리 구조는 고정하지 않는다. Agent는 `.ai_project/tasks/`에서 현재 세션 Role이 `workflow`와 `status`상 처리 가능한 Task를 찾고, Task의 `target_agent` 또는 프로젝트별 동등 필드가 현재 Role과 맞는지 확인한다.

실제 파일 수정, 빌드, 테스트 범위는 Task의 `allowed_paths`가 결정하고, 기준 문서는 `source_of_truth`가 결정한다. 현재 작업 디렉토리와 `allowed_paths`가 다르면 작업 전에 기준 경로를 명확히 보고하고 `allowed_paths` 안에서만 작업한다.

상태 전이 후 `target_agent` 또는 `target_role`이 다른 Agent/Role로 바뀌면 `.ai/runtime/role_handoff.md` 기준으로 Task 파일과 최종 응답에 `다음 Agent에게 전달할 말`을 남긴다. 이 문구는 Claude 전용 명령이 아니라 Codex도 그대로 이해할 수 있는 Role 기반 지시로 작성한다.

## 5. 프로젝트 상태 확인

프로젝트가 초기화되어 있으면 아래 문서를 확인한다.

1. `.ai_project/README.md`
2. `.ai_project/agent_registry.md`
3. `.ai_project/current_context.md`
4. `.ai_project/tasks/`
5. `.ai_project/task_board.md`
6. `.ai_project/source_of_truth.md`
7. `.ai_project/ops_decisions.md`
8. `.ai_project/ops_issues.md`
9. 필요한 report/qa 문서

## 6. Role별 실행 기준

Lead Role 또는 Direction Role은 Task 범위, ownership, source of truth, 우선순위, 승인 필요 여부를 정리한다. 승인된 Task를 Execution Role에게 넘길 때는 Lead -> Execution 인계 문구를 남긴다.

Execution Role은 `.ai_project/tasks/active/`에서 현재 Role에 할당된 `approved` Task만 실행한다. 작업 완료 후 보고서를 작성하고 `verification_ready`, `target_role: Verification Role`로 전환한 뒤 Execution -> Verification 인계 문구를 남긴다.

Verification Role은 `verification_ready` Task만 검증한다. 검증 결과는 `PASS`, `PASS_WITH_RISK`, `FAIL`, `BLOCKED` 중 하나로 분류하고, 통과 시 Completion Role에게, 수정 또는 차단 시 Lead Role에게 인계 문구를 남긴다.

Completion Role은 `verification_passed` Task의 완료 확정 여부를 판단한다. 재작업이나 차단이 필요하면 Lead Role이 다시 조율할 수 있도록 인계 문구를 남긴다.

## 7. 금지사항

- 사용자 승인 없이 `.ai/` 운영 문서를 수정하지 않는다.
- 사용자 승인 없이 `.ai_project/`를 생성하거나 수정하지 않는다.
- 사용자 승인 없이 커밋하지 않는다.
- 사용자 승인 없이 push하지 않는다.
- 민감정보를 로그나 문서에 남기지 않는다.

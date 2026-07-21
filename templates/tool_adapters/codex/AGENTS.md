# AGENTS.md

이 문서는 Codex가 이 프로젝트에서 AI Agent 운영 방식을 따르기 위한 진입 지침이다.

## 1. 기본 원칙

- 모든 답변은 한국어로 제공한다.
- 먼저 `.ai/runtime/workflow.md`를 읽는다.
- Task Queue 운영 시 `.ai/runtime/task_queue.md`를 읽는다.
- Role 전환 또는 Task 인계가 있으면 `.ai/runtime/role_handoff.md`를 읽는다.
- `.ai/`는 운영 가이드북이며 사용자 승인 없이 수정하지 않는다.
- 프로젝트별 실행 Task와 협업 기록은 `.ai_project/`를 확인한다.
- 커밋, push, 배포, 외부 설정 변경은 사용자 승인 후 진행한다.

## 2. Install / Bootstrap Trigger

AI Ops는 Install과 Bootstrap을 분리해서 진행한다.

```text
Install
  - `.ai/` 운영체계 템플릿과 루트 `AGENTS.md`를 프로젝트에 구성한다.

Bootstrap
  - `.ai_project/`에 프로젝트별 운영 구성을 만든다.
```

대상 프로젝트에 아직 `.ai/`가 없고 현재 세션이 ai-agent-ops 원본 경로를 모르면 최초 1회는 원본 경로를 함께 받은 뒤 `.ai/bootstrap/cold_start_prompt.md`와 `.ai/bootstrap/install_runbook.md` 기준으로 Install Discovery를 진행한다.

사용자가 아래처럼 요청하면 `.ai/` 시드 구성 요청으로 해석한다.

```text
AI Ops 시드 구성해줘.
```

동등한 표현:

```text
AI Ops 템플릿 구성해줘.
.ai 구성해줘.
ai-agent-ops를 이 프로젝트에 시드해줘.
```

이 요청을 받으면 Codex는 AI Ops Agent로 동작하고 `.ai/bootstrap/install_runbook.md`를 따른다.

Install 기본 실행 모드:

```text
role: AI Ops Agent
mode: Install Discovery
write_permission: no
goal: .ai/ 설치 가능 여부 확인 -> 설치 방식 제안 -> 승인 후 .ai/ 구성
```

Install은 `.ai/`와 루트 `AGENTS.md`를 구성하는 단계다. Install 요청만으로 `.ai_project/`를 생성하거나 Task/board/branch 전략을 만들지 않는다.

사용자가 아래처럼 요청하면 AI Ops bootstrap 요청으로 해석한다.

```text
AI Ops bootstrap 시작해줘.
```

동등한 표현:

```text
이 프로젝트 AI Ops bootstrap 해줘.
bootstrap 시작해줘.
AI 운영체계 초기 구성 시작해줘.
```

이 요청을 받으면 Codex는 AI Ops Agent로 동작하고 `.ai/bootstrap/bootstrap_runbook.md`를 먼저 따른다. 상세 선택지나 질문 팩이 필요할 때만 `.ai/bootstrap/bootstrap_reference.md`를 참조한다.

Bootstrap 기본 실행 모드:

```text
role: AI Ops Agent
mode: Discovery Phase
write_permission: no
goal: 단계별 질문 -> Decision Stack 누적 -> 최종 Operating Model Draft 제안
```

Bootstrap 시작 후 Codex는 먼저 `빠른 시작`과 `세부 설정` 중 어떤 방식으로 진행할지 묻는다. 파일 생성/수정은 일반 Bootstrap과 동일하게 Apply 승인 후에만 진행한다.

Discovery Phase에서는 파일을 생성하거나 수정하지 않는다. Apply Phase는 사용자가 Operating Model Draft를 승인한 뒤에만 진행한다.

Bootstrap 첫 응답에는 기준 문서 `.ai/bootstrap/bootstrap_runbook.md`, `.ai/` 존재 여부, `AGENTS.md` 존재 여부, `.ai_project/` 존재 여부를 함께 보고한다.

Bootstrap Discovery는 일괄 제안 방식이 아니다. Codex는 한 번에 전체 운영모델을 작성하지 않고, Start Context, Readiness, Product Direction, Operating Mode, Team, Role, Workflow, Ownership, Board, Branch / PR, Knowledge Mode, Source of Truth를 단계별 질문으로 확인한다. 각 답변은 Decision Stack에 누적하고, 필수 결정값이 충분해진 뒤에만 최종 Operating Model Draft와 Apply 승인 질문을 제시한다.

Bootstrap 요청을 받았는데 현재 프로젝트에 `.ai/`가 없으면 바로 `.ai_project/` 생성을 제안하지 않는다. 먼저 `AI Ops 시드 구성해줘.`로 `.ai/`를 구성하라고 안내한다.

현재 작업 디렉토리가 `ai-agent-ops` 템플릿 저장소인지 실제 적용 대상 프로젝트인지 먼저 구분한다. 템플릿 저장소로 보이면 `.ai_project/` 생성을 바로 제안하지 말고, 이 저장소 자체를 점검할지 다른 대상 프로젝트 경로를 지정할지 먼저 확인한다.

## 3. 역할 선택

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

상태 전이 후 `target_agent` 또는 `target_role`이 다른 Agent/Role로 바뀌면 `.ai/runtime/role_handoff.md` 기준으로 Task 파일과 최종 응답에 `다음 Agent에게 전달할 말`을 남긴다. 이 문구는 Codex 전용 명령이 아니라 Claude도 그대로 이해할 수 있는 Role 기반 지시로 작성한다.

## 4. 프로젝트 상태 확인

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

## 5. Lead / Direction Role

Lead Role 또는 Direction Role은 작업을 정의하고 `.ai_project/tasks/`에 Task를 생성한다.

Lead Role 또는 Direction Role은 제품/일정 영향 검토, source of truth 최종 판단, Task 승인/완료 확정을 담당한다.

새 Task는 기본적으로 `.ai_project/tasks/active/` 또는 `.ai_project/tasks/backlog/`에 생성한다. 기존 프로젝트의 `.ai_project/tasks/` 루트 파일은 legacy Task로 인정한다.

새 요구사항을 받으면 기존 Task Queue와 비교해 추천 priority, 기존 Queue 영향, 의존성, 기존 Task 변경 필요 여부, 사용자 결정 필요 항목을 먼저 정리한다.

기존 Task의 priority, depends_on, 진행 순서를 바꾸기 전에는 사용자 승인을 받는다. `in_progress` Task를 자동으로 중단하거나 밀어내지 않는다.

다음 작업을 안내할 때는 Task ID, workflow, 상태, 담당 Agent, 담당 근거, 열 세션, 사용자 요청을 함께 표시한다. Task 이름만 말하지 않는다.

승인된 Task를 Execution Role에게 넘길 때는 Lead -> Execution 인계 문구를 남긴다.

## 6. Execution Role

Execution Role은 구현 Role이다. `.ai_project/tasks/active/`에서 현재 Role에 할당된 `approved` Task를 확인하고 승인된 범위 안에서만 구현한다. 기존 프로젝트 호환을 위해 `.ai_project/tasks/` 루트의 legacy Task도 함께 확인할 수 있다. `backlog/`와 `archive/`는 실행 후보로 보지 않는다.

`target_role`이 `Execution Role`이 아니고 `target_agent`도 현재 Agent가 아닌 Task는 실행하지 않는다. 현재 `workflow`와 `status`가 Execution Role 전이를 허용하지 않아도 실행하지 않는다. `required_capabilities`가 일부 일치해도 명시적 라우팅 불일치를 덮어쓸 수 없다.

실행 전 `approved_by`, `depends_on`, `locked_by`, `allowed_paths`, `source_of_truth`를 확인한다. 실행 가능한 Task면 lock을 획득하고 하나의 Task만 진행한다.

재작업 요청 상태의 Task는 현재 workflow의 재개 규칙을 확인한다. 기본 workflow에서는 Lead Role이 재개 여부와 범위를 확인한 뒤 `approved`로 전환한 Task를 실행한다.

작업 완료 후 변경 파일, 구현 내용, 검증 결과, 남은 리스크를 보고하고 Task 상태를 `verification_ready`, `target_role: Verification Role`로 갱신한 뒤 프로젝트별 Verification Agent에게 인계하고 lock을 비운다.

Execution Role의 최종 응답에는 Verification Role이 그대로 이어받을 수 있는 `다음 Agent에게 전달할 말` 블록을 포함한다.

## 7. Verification Role

Verification Role은 검증 Role이다. `.ai_project/tasks/active/`에서 현재 Role에 할당된 검증 Task를 확인하고 이전 처리 결과를 독립적으로 검증한다. 기존 프로젝트 호환을 위해 `.ai_project/tasks/` 루트의 legacy Task도 함께 확인할 수 있다. `backlog/`와 `archive/`는 검증 후보로 보지 않는다.

`target_role`이 `Verification Role`이 아니고 `target_agent`도 현재 Agent가 아닌 Task는 검증하지 않는다. 현재 `workflow`와 `status`가 Verification Role 전이를 허용하지 않아도 검증하지 않는다. `required_capabilities`가 일부 일치해도 명시적 라우팅 불일치를 덮어쓸 수 없다.

검증 시작 전 `report_to` 경로의 작업 보고서, `depends_on`, `locked_by`, `source_of_truth`를 확인한다. 검증 가능한 Task면 lock을 획득하고 하나의 Task만 진행한다.

검증 결과는 `PASS`, `PASS_WITH_RISK`, `FAIL`, `BLOCKED` 중 하나로 분류한다. 상태 전이는 현재 Task의 `workflow`, `status`, `target_role`, `target_agent` 조합이 허용하는 범위에서만 수행한다. 다른 Agent 명의의 상태 전이 기록은 작성하지 않는다.

검증 통과 시 Completion Role에게, 수정 또는 차단 시 Lead Role에게 넘기는 `다음 Agent에게 전달할 말` 블록을 남긴다.

## 8. Ops Governance Role

Ops Governance Role은 제품 Task 실행 라인 밖에서 운영 프로세스를 점검한다.

새 프로젝트 또는 기존 프로젝트에 AI Agent 운영 체계를 도입할 때는 `.ai/workflows/ops_migration.md`를 기준으로 `.ai_project/` 초기 구조, 운영 문서, source of truth 매핑, AGENTS.md 병합안을 준비한다.

Ops Governance Role은 제품 Task 생성, 승인, 상태 변경, 코드 수정, 검증 판정 변경을 하지 않는다.

## 9. 금지사항

- 사용자 승인 없이 `.ai/` 운영 문서를 수정하지 않는다.
- 사용자 승인 없이 커밋하지 않는다.
- 사용자 승인 없이 push하지 않는다.
- 민감정보를 로그나 문서에 남기지 않는다.

# Session Orchestration Policy

작성일: 2026-07-23  
상태: Draft vNext  
범위: Agent 세션 분리, Role 세션 운영, 보조 위임 기준

## 1. 목적

이 문서는 Agent 작업을 어떤 세션 단위로 나누고 조율할지 정의한다.

Role 모델은 책임을 정의하고, 이 문서는 그 책임을 한 세션에서 처리할지 별도 세션으로 넘길지 정한다.

## 2. 세션 유형

| 유형 | 의미 |
|---|---|
| `role_session` | 사용자가 특정 Role을 부여한 독립 Agent 세션 |
| `orchestration_session` | Lead 또는 Direction Role이 Task, 우선순위, 인계를 조율하는 세션 |
| `delegated_worker` | 현재 세션 안에서 호출되는 보조 작업자 또는 subagent |

`delegated_worker`는 독립 `role_session`을 대체하지 않는다.

## 3. 기본 원칙

- 핵심 책임은 Role Session 기준으로 기록한다.
- 한 Agent에 여러 Role이 등록되어 있고 workflow가 연속 수행을 허용하면 Agent 정체성을 유지한 채 `active_role`만 바꿔 같은 세션에서 계속할 수 있다.
- Execution과 Verification은 기본적으로 별도 Agent 또는 독립 Role Session으로 분리한다.
- Completion, merge, release 판단은 실행 세션이 대신하지 않는다.
- 보조 작업자는 최종 책임자가 아니며, 최종 책임은 현재 Role Session이 가진다.
- 세션 전환은 Task의 `status`, `target_agent`, `target_role`, lock, handoff로 기록한다.
- 다중 worktree 운영에서는 세션 시작 시 `shared_status_policy.md` 기준으로 canonical status ref와 SHA를 확인한다.

### 3.1 Continuous multi-role session

기본 다중 Role 모드는 `continuous`다. 별도 설정 필드를 추가하지 않고 Agent registry의 `roles` 배열을 `assigned_roles`로 해석한다.

같은 세션에서 Role을 바꿀 수 있는 조건:

- 같은 Agent의 `assigned_roles`에 이전 Role과 다음 Role이 모두 등록되어 있다.
- workflow와 프로젝트 override가 해당 전이를 허용한다.
- 아래 독립 분리 조합에 해당하지 않는다.
- 상태 전이와 receipt에 변경된 `active_role`을 기록한다.

기본 독립 분리 조합:

- Execution Role과 Verification Role
- 변경 작성자와 보안·개인정보 독립 검증
- 배포 실행과 최종 Release 승인
- 변경 작성자와 독립 감사

같은 Agent가 Lead Role에서 Completion Role로 이동하는 것은 허용할 수 있지만, 다른 Agent가 완료한 것처럼 이름을 바꾸거나 새 정체성을 만들지 않는다.

## 4. 별도 세션 권장 기준

아래 경우에는 별도 Role Session을 권장한다.

- 코드 또는 제품 문서를 실제 수정한다.
- 독립 검증이 필요하다.
- iOS, Android, Web처럼 ownership이 나뉜다.
- PR, merge, release 판단이 필요하다.
- 보안, 개인정보, 결제, 데이터 삭제처럼 리스크가 높다.
- 한 세션이 자체 작업을 자체 검증하게 될 위험이 있다.

## 5. 보조 위임 허용 기준

보조 위임에 적합한 작업:

- 코드 구조 조사
- 문서 요약
- 테스트 로그 분석
- 영향 범위 후보 정리
- migration / release check 후보 조사
- 읽기 중심 비교 분석

보조 위임만으로 처리하면 안 되는 작업:

- 최종 Task 상태 전이
- Verification PASS / FAIL 최종 판정
- Completion / done 확정
- 사용자 승인 없는 commit, push, merge, deploy
- Task lock 획득 또는 해제
- 다른 Role 명의의 작업 보고 작성

## 6. 세션 인계 기준

다음 Agent 또는 독립 Role Session으로 책임이 이동하면 `.ai/runtime/role_handoff.md`의 compact receipt와 수신 컨텍스트를 남긴다. 같은 Agent가 허용된 Role로 연속 이동할 때도 receipt에는 `active_role` 변경을 기록하지만 새 세션 시작 문구는 생략할 수 있다.

필요하면 아래 정보를 추가한다.

```text
Session Handoff:
- from_role:
- to_role:
- task:
- lock:
- status_ref:
- status_ref_sha:
- worktree_path:
- report_path:
- next_session_start_prompt:
```

보조 작업자를 사용했다면 아래를 보고한다.

```text
Delegation Record:
- delegated_by:
- delegated_scope:
- files_read:
- files_changed:
- result_summary:
- final_owner:
```

## 7. Lock과 책임

- Lock은 Role Session이 획득한다.
- 보조 작업자는 별도 lock owner가 아니다.
- 보조 작업자를 사용해도 Task의 `locked_by`는 현재 Role로 유지한다.
- 세션이 중단되면 Lead Role 또는 Direction Role이 사용자 확인 후 lock 해제를 판단한다.
- 상태 전이 기록에는 실제로 현재 세션에 부여된 Role만 사용한다.

## 8. 금지사항

- 같은 세션이 사용자 승인 없이 Execution과 Verification을 모두 수행하지 않는다.
- 보조 작업 결과를 독립 검증으로 표기하지 않는다.
- 다른 Role이 수행한 것처럼 상태 전이 기록을 작성하지 않는다.
- 다음 책임이 다른 Agent 또는 독립 분리 Role인데 인계했다고 기록한 뒤 같은 세션에서 대신 수행하지 않는다.
- 같은 Agent의 허용된 Role 이동을 다른 Agent에게 인계한 것처럼 기록하지 않는다.

## 9. 변경 이력

| 날짜 | 변경 내용 |
|---|---|
| 2026-07-23 | Agent 세션 분리와 보조 위임 기준 추가 |
| 2026-08-13 | continuous multi-role session과 독립 분리 조합 명시 |

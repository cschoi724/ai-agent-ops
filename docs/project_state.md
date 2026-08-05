# 프로젝트 상태 조회

AI Ops에서 프로젝트 상태를 안정적으로 읽기 위한 기준 문서다.

## Inspect

`aiops project inspect`는 현재 프로젝트의 운영 상태를 읽기 전용으로 요약한다.

```sh
aiops project inspect
aiops project inspect --json
```

확인하는 항목:

- `.ai/` core 연결 상태와 버전
- Codex / Claude adapter 존재 여부
- `.ai_project/` 운영 모델
- 현재 Git branch와 HEAD
- `canonical_status_ref`와 기록된 status ref SHA
- 활성 Role
- Task 개수와 상태 분포

이 명령은 파일을 수정하지 않는다.

## 왜 필요한가

다중 Agent나 여러 worktree를 사용하는 프로젝트에서는 현재 폴더의 문서가 최신 공용 상태가 아닐 수 있다.

`project inspect`는 Agent가 작업 전에 현재 상태를 한 번에 확인할 수 있는 공통 입력 기반이다. 이후 `doctor`, `validate`, `context`, `health`, Dashboard 기능은 이 정규화된 상태 조회를 기준으로 확장한다.

## JSON 출력

외부 도구나 후속 자동화를 위해 JSON 출력도 제공한다.

```sh
aiops project inspect --json
```

현재 schema:

```text
aiops.project_inspect.v1
```

JSON 출력은 source of truth가 아니라, 현재 프로젝트 파일과 Git 상태를 읽어 만든 파생 결과다.

## 관계 검증

`aiops validate project --strict`는 schema 검증 후 문서 간 관계도 함께 점검한다.

현재 관계 검증은 기존 프로젝트 호환성을 위해 `report_only`로 동작한다. 즉, 잘못된 참조는 `warn:`으로 보여주지만 아직 validate 실패로 만들지는 않는다.

점검하는 관계:

- Task의 `target_role`이 운영 모델 또는 Agent registry에 선언되어 있는가
- Task의 `target_agent`가 Agent registry에 등록되어 있는가
- Task의 `workflow`가 `.ai/workflows/` 기준에 존재하는가
- Task의 `depends_on` / `blocks`가 실제 Task를 가리키는가
- Task의 `source_of_truth`가 존재하는 로컬 파일 또는 명시적 외부 기준인가
- `canonical_status_ref`가 로컬 Git ref로 해석되는가

이 검증은 이후 단계에서 `doctor`, `context`, `health`와 연결할 수 있는 상태 정합성 기반이다.

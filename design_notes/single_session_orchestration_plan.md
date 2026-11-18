# Single Session Orchestration and Dual Provider Plan

상태: 확정 / PR A(#67)·B(#68)·C(#69)·D(#70) 완료 / PR E-1(보안 보강) 구현·로컬 검증 완료
대상: Claude·Codex 동일 지원, 한 세션 워크플로 진행(Operator Role), Owner 승인, 팀 협업 충돌 방지
기준 버전: v0.16.0
작성일: 2026-11-17

## 1. 목적

이 계획은 사용자 요구 두 가지를 우선 해결한다.

1. **한 세션 멀티 에이전트 진행**: 사용자가 업무를 한 번 지시하고 작업 범위와 일감만 승인하면, 한 세션 안에서 Direction → Lead → Execution → Verification → (재작업) → Completion까지 기존 워크플로를 지키며 진행한다.
2. **Claude·Codex 동일 지원**: 두 도구가 같은 프로젝트에서 같은 규칙과 같은 기능 범위로 동작한다.

추가로 팀·다중 머신 협업에서 Task ID와 잠금 충돌을 줄인다.

## 2. 확정된 결정

| 항목 | 결정 |
|---|---|
| Owner Role | 사용자 본인만 가진다. Agent Registry에 Agent로 등록할 수 없다. 이 Role의 승인이 사용자 승인이다. |
| Operator Role | 업무 Role이 아니라 기존 Role을 가진 Agent에게 **추가로 부여하는 진행 권한**이다. 부여는 Owner만 한다. |
| Operator 권한 내용 | 그 Agent의 세션 하나에서 워크플로 전체를 진행할 수 있다. 각 단계는 해당 Role을 가진 Agent를 subagent로 호출해 수행하고, Operator는 `dispatched_by`로만 기록된다. |
| Operator 제약 | 자기 Role이 아닌 단계의 업무를 대신 하지 않는다. 상태 전이 권한은 기존 Role 규칙을 그대로 따른다. Execution과 Verification은 서로 다른 Agent여야 한다. |
| 사용자 승인 지점 | ① 작업 범위 승인 ② 일감 승인. 그 뒤는 완료까지 자동 진행한다. |
| 자동 재작업 | 검증 FAIL 시 기본 1회. 사용자가 승인하면 늘릴 수 있다. |
| commit / merge | 프로젝트 운영 방침(branch_pr_strategy)을 따른다. 기본값은 **일감 승인 = 해당 Task 브랜치에 commit까지 허용**. push, PR, merge는 운영 방침에 따르며 기본은 사용자 승인. |
| 최초 진행 확인 | 한 세션 진행을 처음 시작하기 전에 commit 허용 범위 등 진행 방식에 대해 사용자 의사를 먼저 묻는다. |
| 커밋 메시지 | 기본은 프로젝트에서 쓰는 언어(예: 한국어). AI Ops 관련 내용(Role, Agent, Task ID, receipt, handoff, `.ai_project` 경로, AI Ops 용어)은 넣지 않고 프로젝트, 작업 내용, 작업 범위, 상태만 쓴다. 사용자가 요청하면 형식과 내용을 바꿀 수 있다. |
| Claude·Codex 지원 범위 | 모든 기능을 두 도구 모두 같은 범위로 지원한다. parity 테스트로 강제한다. |
| `.ai/` 보호 | `.ai/`는 헌법 폴더다. 도구 hook, 파일 권한, git pre-commit, 무결성 검사의 다중 방어를 기본으로 켠다. |
| Task ID | 새 형식 `T-YYYYMMDD-NNN-XX`. 아래 §6 참고. 기존 형식은 계속 인정한다. |
| Structure Role | 보류. |

## 3. 한 세션 진행 흐름

```text
사용자 지시
  → [Direction] 목표·작업 범위 정리
  → 승인 ① 작업 범위 (Owner)
  → [Lead] 작업 구체화, Task 분할·등록, 담당 배정
  → 승인 ② 일감 (Owner)  — 기본: 해당 Task 브랜치 commit 허용 포함
  → [Execution] 구현·자체 확인 → verification_ready
  → [Verification] 독립 검증 (Task, diff, report만 전달. 구현 추론은 전달하지 않음)
       FAIL → [Lead] 재작업 조율 → [Execution] → [Verification]  (자동 1회)
  → [Completion] 완료 판단 → done
  → 사용자에게 결과 요약
```

멈추고 Owner에게 묻는 경우:

- 재작업 허용 횟수 초과
- blocked, 정책 위반, 작업 범위 밖 변경 필요
- 제품 방향·MVP 범위·핵심 UX 변경, strict 위험도 Task
- 운영 방침상 승인이 필요한 push, PR, merge, 배포
- `.ai/` 수정, Agent Registry·Role·운영 모델 변경, Task 취소

## 4. PR 범위

### PR A — 어댑터 공통 원본화

- `templates/tool_adapters/_source/` 공통 원본(ERB)과 `scripts/build_adapters.rb`
- 생성된 `codex/AGENTS.md`, `claude/CLAUDE.md`는 계속 커밋한다 (doctor/migrate가 바이트 비교를 하기 때문)
- 현재 CLAUDE.md에서 빠진 규칙 복원: Execution·Verification 세부 규칙, 템플릿 레포 구분, Knowledge Mode, Install Discovery, Lead 새 요구사항 분석
- `tests/e2e_adapter_parity.sh`: 재생성 결과와 커밋 파일 일치, 핵심 규칙 문단 양쪽 존재

### PR B — 도구별 확장 파일과 `.ai/` 보호

- `seed --adapter claude|both`: `.claude/` 아래 skill, Role별 subagent 정의, hook 설정 생성 (기존 파일은 skip, `--force`만 덮어씀)
- `seed --adapter codex|both`: Codex에서 대응하는 파일 생성. Codex의 subagent·hook 지원 방식을 먼저 조사하고 결과를 PR에 기록
- 끄는 옵션 제공 (`--no-tool-extras` 등 이름은 구현 시 확정)
- `aiops guard check`: 보호 경로 판정 CLI. Claude hook, Codex 대응 장치, git pre-commit이 모두 이 CLI를 사용
- `.ai/` 무결성 검사: doctor, snapshot, `task advance`에서 core 내용 지문 확인, 불일치는 blocker
- copy 방식 seed 시 `.ai/` 읽기 전용 설정
- doctor drift 보고, migrate 누락분 추가

### PR C — 권한 계약

- `models/role_model.md`: Owner Role, Operator Role 정의
- Agent Registry 선택 필드: `provider`(codex / claude-code / any), `runtime`(session / subagent). schema, validate, snapshot, agents 대시보드 반영
- Owner Role은 Registry 등록 불가 (validate 차단)
- 상태 전이 `--dispatched-by AGENT`, receipt·handoff 기록, 지시자가 같은 Task의 Execution·Verification actor가 되면 차단
- Owner 승인 기록 형식 (`approved_by: owner`)
- branch_pr_strategy에 "일감 승인 시 commit 허용" 기본값과 커밋 메시지 규칙 반영

### PR D — 한 세션 진행 실행

- `aiops orchestrate plan TASK_ID [--until STATUS] --json` (읽기 전용): 다음 단계, 담당 subagent, 실행 명령, 사용자 확인 필요 여부 계산
- Claude skill `aiops-run`과 Codex 대응 지침: plan → subagent 호출 → `task accept/advance --dispatched-by` → 반복 → 멈춤 지점·완료 시 요약
- 최초 진행 전 사용자 의사 확인, 재작업 1회 제한, 커밋 메시지 규칙 적용
- e2e: CLI만으로 approved → done 전체 흐름 재현, 분리 위반·지시자 직접 수행 차단 확인

### PR F — 팀 협업 충돌 방지 (0.18.0)

> 0.18.0 반영: 팀별 동시 진행 한도(`parallel_tasks`), 진행 중 Task 사이 `allowed_paths` 겹침 검사(같은 팀), `aiops worktree create/merge`, `orchestrate next`, `aiops approve --all`. 남은 항목: 새 Task ID 형식·생성 잠금, 공유 잠금 저장소, worktree doctor Task 표시, `task_find_file` 후보 여럿 차단.

- 새 Task ID 형식과 생성 잠금, 중복 검사
- 공유 잠금 저장소 (git 공용 디렉터리, Task·Agent·이유·시작·만료 기록)
- 진행 중 Task 사이 `allowed_paths`·ownership 겹침 검사 (accept 차단, snapshot/risks 표시)
- `aiops worktree create TASK_ID` (표준 위치, Task 자동 기록, 이유 포함 git 잠금), worktree doctor에 Task·잠금 이유·용량 표시
- `task_find_file` 접두어 일치 시 후보가 여럿이면 임의 선택하지 않고 차단

### PR E — 문서와 릴리스

- README, workflow, role model, DEVELOPMENT.md, CHANGELOG
- v0.17.0 (A~D), v0.18.0 (F)

## 5. Claude·Codex 동일 지원 원칙

- 모든 PR의 완료 조건에 "두 도구 모두 지원"을 포함한다.
- 한쪽에서만 가능한 기능이 발견되면 구현 전에 사용자에게 보고하고 대안을 정한다.
- parity 테스트를 CI에 둔다.

## 6. Task ID 규칙

```text
T-20261117-003-K7
   날짜     순번 환경 코드
```

- 환경 코드: clone마다 최초 1회 무작위 2자. git 공용 디렉터리(`.git/aiops/id_suffix`)에 저장하고 커밋하지 않는다. 같은 clone의 워크트리는 같은 코드를 쓴다. canonical ref에 이미 쓰인 코드는 피한다. 사용자가 원하면 바꿀 수 있다.
- 문자 집합: 숫자와 영문 대문자에서 O, I, L, U 제외. 입력은 대소문자 구분 없음.
- 순번: 같은 환경 안에서 날짜별로 001부터. 같은 clone 안의 동시 생성은 잠금으로 순서화.
- 짧은 호칭: `003-K7`, `003K7`, 내 환경이면 `003`. 후보가 여럿이면 목록을 보여주고 멈춘다.
- 표시: 항상 제목과 함께. 파일 이름은 `<ID>_<title-slug>.md`.
- 안전망: 생성 시 중복 확인, `validate --strict`와 CI 중복 검사.
- 호환: 기존 `T-YYYYMMDD-NNN`은 계속 인정하고 바꾸지 않는다.

## 7. 보류 항목

- Structure Role (프로젝트 구조 변경 권한)
- 다른 머신 간 잠금 공유 (canonical 브랜치 lock 커밋 방식)
- worktree prune 일괄 정리, 완료 시 정리 연결 (개선 1번 나머지)
- 인계·완료 상황의 사람용 요약 (개선 3번)

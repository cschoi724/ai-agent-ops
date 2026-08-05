# 상태 전이와 CI 비용 논의 메모

상태: 임시 논의 메모
작성일: 2026-08-05

이 문서는 다중 Agent/worktree 환경에서 Task 상태 전이를 원격 기준 브랜치에 반영할 때 발생할 수 있는 PR/CI 비용 문제를 다음에 다시 논의하기 위해 남긴다.

아직 확정된 정책이 아니며, 현재 구현 범위에 바로 반영하지 않는다.

## 논의 배경

`canonical_status_ref`를 기준으로 오래된 worktree 상태 전이를 막는 방향은 필요하다.

다만 `origin/develop` 같은 원격 기준 브랜치를 공용 상태 기준으로 삼을 경우, 모든 Task 상태 전이를 PR로 반영하면 다음 문제가 생길 수 있다.

- 상태만 바뀌었는데 제품 CI가 매번 실행된다.
- `in_progress`, `verification_in_progress`, lock 같은 임시 상태까지 PR 대상이 되면 운영 비용이 커진다.
- 문서-only 변경과 코드 변경이 같은 CI 비용을 갖게 된다.
- Agent 간 인계 속도가 느려질 수 있다.

## 현재 이해

`canonical_status_ref`는 모든 중간 상태를 저장하는 곳이 아니라, 여러 Agent가 공유해야 하는 기준 상태를 확인하는 기준점으로 쓰는 것이 적합하다.

따라서 모든 상태 전이를 canonical branch에 즉시 반영하지 않아도 된다.

## 후보 운영 모델

### 1. Local / Worktree State

작업 중 상태를 기록한다.

예:

- `in_progress`
- `verification_in_progress`
- 임시 lock
- 작업 중간 메모

이 단계는 CI를 실행하지 않는다.

### 2. Task Branch State

Agent 간 인계를 위한 상태를 기록한다.

예:

- 구현 결과
- 작업 보고서
- 검증 요청
- handoff

필요하면 lightweight validation만 실행한다.

### 3. Canonical State

공용 기준 상태로 반영해야 하는 체크포인트만 기록한다.

예:

- `approved`
- `verification_ready`
- `verification_passed`
- `done`
- dependency 해제
- board 기준 상태 변경

이 단계에서도 상태-only 변경은 제품 heavy CI를 피하는 방향이 필요하다.

## CI 비용 절감 후보

후보 방안:

- `.ai_project/**`만 바뀐 PR은 AI Ops validate만 실행한다.
- 제품 코드 경로가 바뀐 PR만 build/test CI를 실행한다.
- 상태-only PR과 code PR을 GitHub Actions path filter로 분리한다.
- `in_progress`, `verification_in_progress`, lock은 canonical branch 반영 대상에서 제외한다.
- 공유 체크포인트 상태만 canonical branch에 반영한다.

예상 방향:

```text
state-only PR -> aiops validate / project inspect
code PR       -> product build / test + aiops validate
```

## 나중에 결정할 질문

- 어떤 상태를 canonical checkpoint로 볼 것인가?
- 상태-only PR을 허용할 것인가, 아니면 code PR에 묶어서만 반영할 것인가?
- GitHub Actions path filter 템플릿을 AI Ops가 제공해야 하는가?
- `aiops ci init`가 lightweight/heavy CI 분리를 생성해야 하는가?
- Task 상태 전이 명령이 checkpoint 여부를 구분해야 하는가?

이 내용은 workflow catalog 단일화 또는 CI 정책 개선 단계에서 다시 확정한다.

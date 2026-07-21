# Versioning Policy

작성일: 2026-07-21  
상태: Draft vNext

## 1. 목적

이 문서는 AI Agent Ops core 버전과 적용 대상 프로젝트의 운영 안정성을 관리하는 기준을 정의한다.

Homebrew link mode는 편리하지만, 여러 프로젝트의 `.ai`가 같은 설치 경로를 바라볼 수 있다. 이 경우 core 업데이트가 여러 프로젝트의 운영 규칙에 동시에 영향을 줄 수 있다.

## 2. 기본 원칙

- `.ai/` core 버전은 적용 대상 프로젝트의 `.ai_project/operating_model.md`에 기록한다.
- 프로젝트별 운영 상태인 `.ai_project/`는 core 업데이트로 자동 변경하지 않는다.
- core 버전이 바뀌면 AI Ops Agent가 `.ai_project/`와 충돌 가능성을 점검한다.
- 중요한 프로젝트는 업데이트 전에 `aiops doctor --strict`와 테스트를 실행한다.
- 사용자 승인 없이 `.ai/` 업데이트, `.ai_project/` 마이그레이션, Task 상태 변경을 진행하지 않는다.

## 3. 설치 모드별 기준

| Mode | 설명 | 장점 | 주의 |
|---|---|---|---|
| link | `.ai`가 Homebrew 또는 로컬 checkout core를 symlink로 참조 | 업데이트가 쉽다 | 여러 프로젝트가 동시에 새 core 영향을 받을 수 있다 |
| copy | `.ai`에 core 파일을 복사 | 프로젝트별 core가 고정된다 | 업데이트와 보안 패치 반영이 수동이다 |
| pinned | 특정 버전/커밋을 명시적으로 고정하는 미래 모드 | 안정성과 추적성이 높다 | 아직 자동화 대상 |

## 4. Version Record

프로젝트별 운영 모델에는 아래 값을 기록한다.

```text
core_version: 0.6.1
core_source: homebrew | local_checkout | copy | unknown
core_update_policy: auto_check | manual_review | pinned
```

Markdown table에 기록해도 된다.

```text
| core_version | 0.6.1 |
| core_source | homebrew |
| core_update_policy | manual_review |
```

## 5. Doctor 기준

`aiops doctor`는 `.ai_project/operating_model.md`의 `core_version`이 현재 `.ai/VERSION`과 다르면 경고한다.

경고가 발생하면 바로 마이그레이션하지 않는다. 먼저 아래를 확인한다.

1. 변경된 `.ai/` 버전의 CHANGELOG
2. workflow, task queue, role model 변경 여부
3. 현재 `.ai_project/tasks/`와 상태 전이 충돌 여부
4. 프로젝트별 override와 source of truth 영향

## 6. 변경 이력

| 날짜 | 변경 내용 |
|---|---|
| 2026-07-21 | core version 기록과 update risk 정책 추가 |

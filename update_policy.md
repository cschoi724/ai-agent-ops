# AI Agent Ops Update Policy

작성일: 2026-06-29  
상태: Draft v1  
범위: `ai-agent-ops` 템플릿 업데이트 정책

## 1. 목적

이 문서는 `.ai/` 템플릿 업데이트와 적용 대상 프로젝트의 `.ai_project/` 보존 원칙을 정의한다.

## 2. 기본 원칙

- `.ai/`는 `ai-agent-ops` 저장소에서 업데이트한다.
- `.ai_project/`는 적용 대상 프로젝트의 진행 기록이므로 템플릿 업데이트로 덮어쓰지 않는다.
- 업데이트 전 변경 내용을 검토한다.
- breaking change가 있으면 PM Agent가 migration 제안을 작성한다.
- `.ai/`에 변경 또는 개정된 운영 규칙이 있으면 적용 대상 프로젝트의 `.ai_project/`도 함께 감사한다.
- `.ai_project/`에 새 `.ai/` 기준과 충돌하거나 보강이 필요한 항목이 있으면 AI Ops Agent가 프로젝트별 반영안을 작성한다.
- 사용자 승인 없이 `.ai/`를 업데이트하거나 `.ai_project/`를 수정하지 않는다.

## 3. 업데이트 절차

1. PM Agent가 업데이트 필요성을 정리한다.
2. 변경 대상과 예상 영향을 설명한다.
3. 사용자가 업데이트를 승인한다.
4. `.ai/` 저장소에서 변경을 가져온다.
5. 업데이트된 `.ai/` 커밋과 변경 파일을 확인한다.
6. `.ai_project/`와 충돌 여부를 확인한다.
7. `.ai_project/workflow_overrides.md`, `.ai_project/current_context.md`, `.ai_project/task_board.md`, `.ai_project/source_of_truth.md`, `.ai_project/ops_decisions.md`, `.ai_project/ops_issues.md`, `.ai_project/tasks/`가 새 `.ai/` 기준과 어긋나는지 감사한다.
8. 필요한 경우 AI Ops Agent가 `.ai_project/ops_issues.md`와 `.ai_project/ops_migration_plan.md`에 반영 필요 항목을 기록한다.
9. 사용자 승인 범위 안에서 `.ai_project/` 반영 패치를 적용한다.
10. 적용 결과와 남은 수동 확인 항목을 보고한다.

## 4. `.ai_project/` 동기화 감사 기준

`.ai/` 업데이트 후 AI Ops Agent는 아래 항목을 확인한다.

- `.ai/task_queue.md`의 상태 전이, target_agent, lock, 승인 규칙이 `.ai_project/tasks/`와 충돌하지 않는가
- `.ai/agents/`의 역할/권한 변경이 `.ai_project/agent_registry.md`와 충돌하지 않는가
- `.ai/workflows/` 변경이 `.ai_project/workflow_overrides.md`와 충돌하지 않는가
- `.ai/templates/` 변경이 새 Task 작성 방식과 report/QA 기록 방식에 영향을 주는가
- `.ai_project/current_context.md`와 `.ai_project/task_board.md`가 새 실행 기준을 잘 안내하는가
- `.ai_project/source_of_truth.md`가 새 운영 문서 우선순위를 반영하는가

감사 결과는 프로젝트 문맥을 보존해 반영한다. `.ai_project/`를 템플릿으로 덮어쓰지 않는다.

## 5. 금지사항

- `.ai_project/`를 템플릿으로 덮어쓰지 않는다.
- 기존 Task, report, QA 기록을 삭제하지 않는다.
- 프로젝트별 운영 결정과 제품/기술 결정을 템플릿 기본값으로 되돌리지 않는다.
- 도구 어댑터를 사용자 승인 없이 생성하지 않는다.

## 6. Migration 기록

적용 대상 프로젝트는 필요 시 `.ai_project/ops_decisions.md` 또는 별도 migration 문서에 업데이트 이력을 남긴다.

권장 형식:

```text
날짜:
적용한 ai-agent-ops 버전/커밋:
변경 요약:
프로젝트 영향:
필요 조치:
승인:
```

## 7. 변경 이력

| 날짜 | 변경 내용 |
|---|---|
| 2026-06-29 | 업데이트 정책 v1 작성 |
| 2026-07-02 | `.ai/` 업데이트 후 `.ai_project/` 동기화 감사와 반영 기준 추가 |

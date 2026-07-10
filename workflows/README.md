# Workflows

작성일: 2026-06-29  
상태: Draft vNext  
범위: 조직형 Task 유형별 workflow

## 1. 목적

이 폴더는 Task 유형별 workflow를 정의한다.

Workflow는 Task 유형별 상태 전이와 다음 처리 Role을 정의한다. 기존 PM, Development, QA Agent는 vNext 책임 단계 위에 매핑되는 bootstrap Role이다.

AI Ops Agent는 기본 제품 Task 실행 workflow에 참여하지 않는다. 운영 프로세스, 역할 경계, Task Queue 규칙 충돌을 독립 점검하고 `.ai_project/ops_issues.md`에 기록한다.

## 2. 기본 Workflow

| Workflow | 문서 | 용도 |
|---|---|---|
| Feature | `.ai/workflows/feature.md` | 신규 기능, 기능 확장 |
| Bugfix | `.ai/workflows/bugfix.md` | 버그 수정, 회귀 보정 |
| Docs | `.ai/workflows/docs.md` | 문서 작성, 정리, 계획 수립 |
| Ops Migration | `.ai/workflows/ops_migration.md` | 새 프로젝트 또는 기존 프로젝트에 AI 운영 체계 도입 |

## 3. 공통 단계

대부분의 작업은 아래 기본 흐름을 따른다.

```text
Need
  -> proposed
  -> scoped
  -> approved
  -> in_progress
  -> verification_ready
  -> verification_in_progress
  -> verification_passed
  -> completion_review
  -> done
```

책임 단계로 보면 아래 흐름이다.

```text
Direction -> Coordination -> Execution -> Verification -> Completion
```

## 4. Workflow 선택 기준

Direction Role이 Task 시작 전에 workflow를 선택한다. AI 운영 체계 도입은 제품 Task가 아니므로 AI Ops Agent 또는 AI Ops Division이 `Ops Migration` workflow를 선택하고 주도한다.

Agent는 Task의 `workflow`, `status`, `target_agent`, `target_role` 조합으로 현재 실행 가능 여부를 판단한다. 작업 완료 시 `status`, `target_agent`, `target_role`을 해당 workflow가 정의한 다음 처리 상태로 갱신한다.

| Task 성격 | 권장 Workflow |
|---|---|
| 새 기능 구현 | Feature |
| 기존 동작 오류 수정 | Bugfix |
| 운영/기획/개발 문서 정리 | Docs |
| 배포, 버전, 릴리즈 노트 | Release |
| `.ai/`, `.ai_project/`, Agent 운영 체계 도입 | Ops Migration |

## 5. Task별 기록 필수 항목

`.ai_project/tasks/`의 Task 파일에는 아래 항목을 기록한다.

```text
## Workflow

- Type:
- Status:
- Target Agent:
- Target Role:
- Active Agents:
- Active Capabilities:
- Additional Review Points:
```

report와 QA 문서는 Task 파일을 보조하며, 실행 기준은 항상 Task 파일이다.

## 6. 변경 이력

| 날짜 | 변경 내용 |
|---|---|
| 2026-06-29 | Workflow 문서 구조 v1 작성 |
| 2026-06-29 | Task Queue 기반 공통 흐름 반영 |
| 2026-06-30 | AI Ops Agent의 workflow 비참여 원칙 추가 |
| 2026-07-01 | Ops Migration workflow 추가 |
| 2026-07-02 | workflow/status/target_agent 기준 실행 조건 추가 |
| 2026-07-09 | vNext 상태 체계와 책임 단계 흐름 반영 |

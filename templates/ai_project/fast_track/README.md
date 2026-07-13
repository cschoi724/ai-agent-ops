# AI Project Workspace

작성일: {{DATE}}
프로젝트: {{PROJECT_NAME}}
상태: Active

## 1. 목적

이 `.ai_project/`는 Fast Track으로 생성된 최소 AI Ops 운영 구성이다.

## 2. 문서 목록

| 문서/폴더 | 역할 |
|---|---|
| `operating_model.md` | 현재 프로젝트 운영 구성 요약 |
| `agent_registry.md` | 활성 Agent / Role 후보 |
| `current_context.md` | 세션 시작 시 확인할 현재 초점 |
| `task_board.md` | Task Queue 요약 |
| `source_of_truth.md` | 기준 문서와 미정 항목 |
| `ops_decisions.md` | 운영 결정 기록 |
| `ops_issues.md` | 운영 이슈와 개선 후보 |
| `tasks/` | Task 파일 |
| `reports/` | 작업 보고 |
| `qa/` | 검증 보고 |

## 3. 운영 원칙

- Fast Track은 작게 시작하고 필요할 때 확장한다.
- Branch / PR, Team board, workflow override는 기본 생성하지 않는다.
- 구현 가능한 Task가 생기면 Execution Role과 Verification Role 활성 여부를 다시 결정한다.
- 운영 구성이 복잡해지면 Guided Full 템플릿 문서를 추가한다.

## 4. 다음 단계

1. `current_context.md`의 다음 초점을 확인한다.
2. `agent_registry.md`에서 시작할 Role을 고른다.
3. 제품/업무 방향이 정리되면 첫 Task 생성 여부를 사용자에게 확인한다.

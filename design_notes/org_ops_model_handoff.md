# Org Ops Model Handoff

작성일: 2026-07-09
브랜치: `org-ops-model`
상태: Draft / Design Handoff

## 1. 문서 목적

이 문서는 `ai-agent-ops`의 차세대 조직형 운영모델 설계를 이어가기 위한 인수인계 문서다.

현재 `main` 브랜치의 운영모델은 안정 운영 기준으로 유지한다. 이 브랜치에서는 조직, 팀, Role, Capability, 병렬 작업, 의존성 관리까지 포함하는 확장 운영모델을 설계한다.

중요한 기준:

- 이 문서는 현재 안정 운영 규칙이 아니다.
- 이 브랜치의 설계는 DevIPPEO 현재 운영에 자동 적용하지 않는다.
- 실제 적용은 별도 migration plan과 사용자 승인 후 진행한다.
- 현재 DevIPPEO 안의 `.ai/`는 운영 중인 템플릿이므로, 실험/설계 작업은 별도 clone에서 이어가는 것을 권장한다.

## 2. 현재 안정 운영모델 요약

현재 `main` 운영모델은 단일 프로젝트에서 PM/Development/QA/AI Ops Role이 `.ai_project/tasks/`를 공유하는 구조다.

고정 구조:

```text
.ai/
.ai_project/
```

핵심 기준:

- `.ai/`: 공통 AI Agent 운영 가이드북과 템플릿
- `.ai_project/`: 프로젝트별 Agent 협업 상태, Task Queue, 보고서, QA 결과
- Agent Role은 사용자가 세션 시작 시 부여한다.
- Task 실행 가능 여부는 Role, `workflow`, `status`, `target_agent`, `approved_by`, `depends_on`, `locked_by` 조합으로 판단한다.
- 실제 작업 범위는 `allowed_paths`가 제한한다.
- 기준 문서는 `source_of_truth`가 제한한다.
- 프로젝트 디렉토리 구조는 고정하지 않는다.

현재 구조는 DevIPPEO처럼 하나의 프로젝트 목표를 향해 1인 + AI Agent 팀으로 개발할 때 충분히 실용적이다.

## 3. 현재 모델의 회고

잘 동작한 점:

- 복사/붙여넣기 지시 대신 Task 파일을 기준으로 Agent들이 같은 작업 큐를 본다.
- `target_agent`, `status`, `workflow` 조합으로 담당 Role을 구분할 수 있다.
- `allowed_paths`와 `source_of_truth`로 작업 범위와 기준 문서를 제한할 수 있다.
- PM/Development/QA/AI Ops의 기본 역할 분리는 단일 프로젝트 운영에 충분히 명확하다.
- `.ai/`와 `.ai_project/`를 분리해 공통 템플릿과 프로젝트별 상태를 나눌 수 있다.

드러난 한계:

- PM/Development/QA 중심 구조는 당장 편하지만, 큰 조직 모델로 확장하면 Role 이름이 규칙에 박힐 위험이 있다.
- 팀, 팀장, 여러 개발자, 여러 Agent, 여러 플랫폼이 동시에 움직이는 상황에 대한 상위 조정 구조가 부족하다.
- 병렬 작업은 `allowed_paths`, `depends_on`, lock만으로 어느 정도 가능하지만, ownership과 팀 단위 조율이 없으면 충돌 가능성이 있다.
- iOS, Android, Web, Backend처럼 여러 작업 경로가 생기면 단일 Task Board만으로 전체 상태를 보기 어려울 수 있다.
- QA, Test, Release, Security 같은 검증 역할이 커질 경우 Development/QA 단순 구분으로는 부족할 수 있다.

운영 중 배운 점:

- 하드스탑을 너무 많이 넣으면 유연성이 떨어진다.
- 반대로 문구가 느슨하면 Agent가 자기 Role이 아닌 Task를 실행하거나 한 번에 여러 상태 전이를 수행할 수 있다.
- 따라서 강제 규칙은 최소화하되, `Role + workflow/status + target_agent + allowed_paths` 같은 실행 판단 기준은 명확해야 한다.
- 특정 프로젝트 경로를 템플릿 규칙으로 고정하면 안 된다.
- `.ai`는 운영 방식만 알고, 실제 프로젝트 구조는 `.ai_project`와 Task metadata가 알아야 한다.

## 4. 차세대 모델의 목표

목표는 AI Agent를 단순 PM/Dev/QA 세션이 아니라 하나의 조직처럼 운영할 수 있게 하는 것이다.

원하는 장기 그림:

```text
Organization
  Planning Division
  Design Division
  Development Division
    Development Lead
    iOS Team
    Android Team
    Web Team
    Backend Team
  QA Division
  Business Division
  AI Ops Division
```

현재 실제 운영 시작점:

```text
Development Division
  iOS Team
```

미래 확장 대상:

```text
Development Division
  Android Team
  Web Team
  Backend Team

Design Division
Planning Division
Business Division
QA Division
```

## 5. 핵심 설계 원칙

조직과 실행을 분리한다.

```text
Org Unit = 어느 조직/팀 책임인가
Role = 현재 세션이 어떤 역할인가
Capability = 어떤 능력을 수행할 수 있는가
Workflow = 어떤 절차로 흘러가는가
Task = 이번에 정확히 무엇을 처리하는가
```

고정해야 하는 것:

- `.ai/`
- `.ai_project/`
- Task 기반 협업
- Role 기반 실행 판단
- `allowed_paths`
- `source_of_truth`
- `depends_on`
- lock

고정하면 안 되는 것:

- 프로젝트 코드 디렉토리 구조
- 특정 플랫폼 경로
- PM/Development/QA만 존재한다는 가정
- 모든 Task가 Dev -> QA -> PM 흐름을 탄다는 가정
- 모든 팀이 하나의 Task Board만 사용한다는 가정

## 6. 조직 유닛 모델 초안

조직 유닛은 책임 영역을 표현한다.

예상 문서:

```text
.ai_project/org_units.md
```

초기 예시:

```text
Planning Division
- 제품 방향, 요구사항, 우선순위, 로드맵

Design Division
- UX/UI, 사용자 흐름, 디자인 시스템, 디자인 QA

Development Division
- 구현, 리팩터링, 빌드, 기술 문서, 플랫폼별 개발

QA Division
- 테스트 전략, 검증, 릴리즈 리스크

Business Division
- 시장, 정책, 수익화, 운영 전략

AI Ops Division
- Agent 운영 프로세스, 역할 충돌, workflow 개선
```

현재 활성 유닛:

```text
Development Division
AI Ops Division
```

## 7. Development Division 초안

Development Division은 여러 플랫폼 팀을 묶는다.

```text
Development Division
  Development Lead
  iOS Team
  Android Team
  Web Team
  Backend Team
```

Development Lead 책임:

- 팀 간 우선순위 조율
- cross-platform dependency 관리
- 공통 아키텍처 영향 판단
- release 영향과 병렬 작업 가능 여부 조율
- 팀 간 충돌과 ownership 충돌 조정
- 필요한 경우 PM/Product Owner에게 결정 항목 보고

iOS Team 예시:

```text
iOS Team
  iOS Team Lead
  iOS Development Agent
  iOS Test Agent
  iOS QA Agent
  iOS Release Agent
```

Android Team은 같은 구조를 복제할 수 있다.

```text
Android Team
  Android Team Lead
  Android Development Agent
  Android Test Agent
  Android QA Agent
  Android Release Agent
```

## 8. Task Metadata 확장 아이디어

기존 Task metadata는 유지하되, 조직형 모델에서는 아래 필드를 추가 검토한다.

```yaml
org_unit: Development Division
team: iOS Team
team_lead: iOS Team Lead
target_agent: iOS Development Agent
workflow: feature
status: approved
priority: P1
depends_on: []
blocks: []
parallel_group: ios-auth
allowed_paths:
  - path/to/ios/
source_of_truth:
  - docs/current_status.md
```

필드 의미:

- `org_unit`: 상위 조직 책임
- `team`: 실제 작업 팀
- `team_lead`: 팀 내 조율 Role
- `target_agent`: 현재 상태에서 처리할 Role 또는 Agent 이름
- `depends_on`: 선행 Task
- `blocks`: 이 Task 완료 전 막는 후속 Task
- `parallel_group`: 병렬 작업 충돌 판단용 그룹
- `allowed_paths`: 실제 작업 가능 범위
- `source_of_truth`: 기준 문서

주의:

- 기존 `target_agent` 필드는 호환성을 위해 유지한다.
- 장기적으로 `target_role` 이름이 더 직관적일 수 있지만, 기존 Task 영향이 크므로 별도 migration이 필요하다.

## 9. 병렬 작업 모델 초안

여러 Agent가 동시에 작업하려면 아래 조건이 필요하다.

필수 기준:

- Task별 `allowed_paths`
- Task별 `depends_on`
- Task lock
- path ownership
- team board
- lead coordination

병렬 가능 판단:

```text
1. depends_on이 모두 완료됐는가?
2. allowed_paths가 충돌하지 않는가?
3. 같은 ownership 영역을 동시에 수정하지 않는가?
4. 같은 문서를 동시에 수정하지 않는가?
5. team_lead 또는 coordination policy가 병렬을 허용하는가?
6. 각 Agent가 하나의 in_progress Task만 갖는가?
```

병렬 금지 예시:

- 같은 파일 또는 같은 좁은 디렉토리 수정
- 같은 source of truth 문서 동시 수정
- 한 Task가 다른 Task의 선행 조건인 경우
- 릴리즈/배포처럼 순차 게이트가 필요한 workflow

병렬 가능 예시:

- iOS Auth 구현과 Android 문서 분석
- iOS 테스트 문서 정리와 Backend API 설계 검토
- 서로 다른 allowed_paths와 source_of_truth를 가진 독립 Task

## 10. Ownership 모델 초안

여러 팀과 Agent가 생기면 `allowed_paths`만으로는 부족하다.

예상 문서:

```text
.ai_project/ownership.md
```

예시:

```text
path/to/ios/auth/       iOS Team / Auth Owner
path/to/ios/webview/    iOS Team / WebView Owner
path/to/android/auth/   Android Team / Auth Owner
docs/release/           Release Owner
```

목적:

- 같은 영역을 여러 Agent가 동시에 수정하는 것을 방지
- cross-team 변경 시 소유 팀 검토 요구
- rework나 rollback 책임 추적

## 11. Team Board 모델 초안

초기에는 단일 `.ai_project/task_board.md`를 유지한다.

팀이 늘어나면 아래 구조를 검토한다.

```text
.ai_project/
  task_board.md
  teams/
    ios/
      team_context.md
      task_board.md
    android/
      team_context.md
      task_board.md
```

원칙:

- 전체 보드는 Product/PM/Development Lead 관점
- 팀 보드는 해당 팀의 실행 관점
- Task source of truth는 여전히 `.ai_project/tasks/`의 Task 파일
- team board는 요약판일 뿐 Task 파일을 대체하지 않는다.

## 12. Workflow 확장 방향

현재 기본 workflow:

```text
proposed -> approved -> in_progress -> ready_for_qa -> qa_in_progress -> qa_passed -> done
```

확장 예시:

```text
team_proposed -> lead_review -> approved -> in_progress -> test_ready -> qa_ready -> done
```

또는:

```text
design_ready -> dev_ready -> in_progress -> code_review -> qa_ready -> release_ready -> done
```

기준:

- workflow가 현재 상태의 처리 Role을 정의한다.
- Agent 문서에 고정 권한표를 계속 늘리기보다 workflow에 상태 전이와 전이 후 `target_agent`를 추가한다.
- 특정 workflow에서 연속 전이가 필요하면 명시적으로 허용한다.
- 기본값은 한 Agent가 한 번에 한 단계만 전이한다.

## 13. 현재 모델에서 배운 주의점

피해야 할 방향:

- 특정 디렉토리를 공통 템플릿 규칙으로 고정
- PM/Development/QA만 있다는 전제
- QA 통과 후 같은 Agent가 바로 `done`까지 처리
- `target_agent`가 맞지 않는데 capability만 보고 실행
- `rework_requested`를 승인 없이 바로 재작업
- 작업 지시를 대화 복붙으로 전달하고 Task 파일을 생략

유지해야 할 방향:

- Task 파일이 실행 지시의 source of truth
- `task_board.md`는 요약판
- Agent Role은 사용자 부여
- Task 실행은 Role + workflow/status + target_agent 기준
- 작업 범위는 allowed_paths
- 기준 문서는 source_of_truth
- lock과 depends_on은 병렬 작업의 최소 안전장치

## 14. 설계 브랜치 작업 원칙

이 브랜치에서 할 수 있는 일:

- 조직형 운영모델 문서 작성
- 팀/Role/Capability 구조 설계
- Task metadata 확장안 작성
- 병렬 작업 정책 설계
- ownership/coordination 정책 설계
- 마이그레이션 전략 설계
- 예시 템플릿 작성

이 브랜치에서 바로 하지 않을 일:

- DevIPPEO 현재 `.ai_project/`를 마이그레이션
- 현재 main 운영모델을 대체
- 기존 Task 파일 필드 일괄 변경
- 현재 프로젝트 코드 수정

## 15. 다음 세션 시작 프롬프트

새 폴더에서 이 브랜치를 clone한 뒤 아래처럼 시작한다.

```text
너는 ai-agent-ops의 조직형 운영모델 설계 세션이야.

현재 브랜치는 org-ops-model이고, 목표는 현재 main 안정 운영모델을 깨지 않고
조직/팀/Role/Capability 기반 차세대 AI 운영모델을 바로 실운영 가능한 수준으로 설계하는 것이다.

먼저 .ai/design_notes/org_ops_model_handoff.md를 읽고,
현재 저장소 구조와 main 운영모델을 확인한 뒤,
조직형 운영모델에서 추가해야 할 문서 구조와 첫 설계 작업 순서를 제안해줘.

아직 main 운영 문서에 병합하지 말고, 이 브랜치 안에서만 설계해줘.
```

## 16. 아직 결정하지 않은 질문

- `target_agent`를 장기적으로 `target_role`로 rename할 것인가?
- `org_unit`, `team`, `team_lead`를 Task 필수 필드로 둘 것인가, 선택 필드로 둘 것인가?
- Team별 Task Queue를 실제 파일 분리로 둘 것인가, 단일 Task Queue + team 필드로 둘 것인가?
- Development Lead와 PM Agent의 책임 경계를 어디까지 나눌 것인가?
- QA Division을 Development Division 내부 검증 기능으로 시작할 것인가, 별도 상위 조직으로 둘 것인가?
- 병렬 작업 충돌 판단을 문서 규칙으로만 둘 것인가, 나중에 스크립트/체커로 보강할 것인가?
- ownership은 경로 기반으로 시작할 것인가, 도메인 기반으로 시작할 것인가?
- 조직형 모델을 어느 시점에 experimental 또는 main으로 승격할 것인가?

## 17. 추천 다음 작업

1. 현재 `.ai/` main 모델과 이 문서의 목표를 비교한다.
2. `org_model.md` 초안을 작성한다.
3. `team_model.md` 초안을 작성한다.
4. `coordination_policy.md` 초안을 작성한다.
5. `ownership.md` 템플릿 초안을 작성한다.
6. Task metadata 확장안을 별도 문서로 작성한다.
7. iOS Team 단일 활성 운영 예시를 만든다.
8. Android Team 추가 시나리오를 만든다.
9. 기존 main 모델에서 org model로 이동하는 migration plan을 작성한다.

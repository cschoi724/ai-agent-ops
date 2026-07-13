# Changelog

이 문서는 `ai-agent-ops` 템플릿의 버전별 변경 이력을 기록한다.

버전은 아래 기준으로 관리한다.

- Major: 기존 프로젝트 적용 방식과 호환되지 않는 운영 구조 변경
- Minor: 새 Agent, workflow, 템플릿, 운영 규칙 추가 또는 기본 흐름 변경
- Patch: 문구 정리, 충돌 제거, 설명 보강, 누락 수정

## 0.6.1 - 2026-07-13

### Added

- `aiops bootstrap-guide` 명령 추가
- bootstrap 전 `.ai/`, adapter 파일, `.ai_project/` 상태를 확인하고 다음 Agent 입력 문구를 안내하는 CLI 흐름 추가
- `.ai_project` 구성 완료 상태에서 활성 Agent/Role 후보, 현재 초점, 첫 Agent 세션 명령 후보를 안내하는 흐름 추가

### Changed

- README, Quick Start, 설치 문서에 `bootstrap-guide` 사용법 추가

## 0.6.0 - 2026-07-09

### Added

- 로컬 CLI `bin/aiops` 추가
- Claude 호환 어댑터 `templates/tool_adapters/claude/CLAUDE.md` 추가
- 초보자용 `QUICKSTART.md` 추가
- 설치 구조 문서 `docs/installation.md` 추가
- 조직형 AI Agent 운영체계의 최상위 원칙 문서 `constitution.md` 추가
- Organization / Division / Team 기준 문서 `org_model.md` 추가
- Role / Agent / Capability 책임 기준 문서 `role_model.md` 추가
- path / domain / document ownership 기준 문서 `ownership_model.md` 추가
- 병렬 작업, dependency, rework, blocked 조율 문서 `coordination_policy.md` 추가
- project board / team board 기준 문서 `board_model.md` 추가
- Git branch / commit / PR / merge 일반 정책 문서 `branch_pr_policy.md` 추가
- 프로젝트별 운영체계 구성 선택 정책 문서 `project_bootstrap_policy.md` 추가
- 프로젝트 bootstrap 실행 절차 문서 `bootstrap_runbook.md` 추가
- 실제 프로젝트에 `.ai/` 운영체계 템플릿을 설치하는 `install_runbook.md` 추가
- `.ai/`가 없는 프로젝트 최초 1회용 `cold_start_prompt.md` 추가
- Team 구성 패턴과 최소 계약 문서 `team_model.md` 추가
- 프로젝트별 실제 운영 구성 템플릿 `templates/ai_project/operating_model.md` 추가
- 프로젝트별 branch / PR 전략 템플릿 `templates/ai_project/branch_pr_strategy.md` 추가
- Organization, Division, Team, Role, Capability, Workflow, Task 분리 원칙 추가
- 초기 운영 후보를 Development Division / 선택 Team / AI Ops Division으로 정의
- Task metadata 확장 방향으로 `org_unit`, `team`, `team_lead`, `target_role`, `blocks`, `parallel_group` 초안 추가
- vNext 중심 흐름을 Need -> Direction -> Coordination -> Execution -> Verification -> Completion -> Learning / Ops Improvement로 정의
- `scoped`, `verification_ready`, `verification_in_progress`, `verification_passed`, `completion_review` 상태 체계 추가

### Changed

- README를 vNext 조직형 운영체계 진입점으로 개정
- README를 프로젝트 소개, Quick Start, 안전 규칙, 사용 트리거 중심으로 개편
- README를 CLI 기반 seed / doctor / bootstrap 흐름으로 개편
- `aiops doctor`에 strict 모드, adapter drift, `.ai_project` 필수 문서, Task 검증 상태 점검 추가
- 문서 읽기 순서에서 `constitution.md`를 최우선 기준으로 추가
- `org_model.md`를 Division과 조직 책임 중심으로 정리하고 Team 상세 구성은 `team_model.md`로 분리
- `project_bootstrap_policy.md`에 단계별 질문 형식, 선택값 기록 규칙, bootstrap 완료 기준 추가
- `bootstrap_runbook.md`에 짧은 bootstrap trigger와 템플릿 저장소/대상 프로젝트 구분 기준 추가
- `install_runbook.md`와 `bootstrap_runbook.md`를 별도 실행 단계로 분리
- 시드 구성 단계의 산출물에 루트 `AGENTS.md` 생성을 명시
- bootstrap 첫 응답에 기준 runbook, `.ai/`, `AGENTS.md`, `.ai_project/`, 자동화 스크립트 여부를 보고하도록 보강
- bootstrap Discovery를 일괄 Draft 제안 방식에서 단계별 질문과 Decision Stack 누적 방식으로 변경
- 최종 Operating Model Draft 전에 Decision Stack Review 단계를 추가
- 빈 프로젝트 첫 세션에서 ai-agent-ops 원본 경로를 알려주는 cold start 기준 추가
- Codex skill-installer 오인을 피하기 위해 사용자 입력 트리거를 `AI Ops 시드 구성해줘`로 변경
- Codex용 `AGENTS.md` 템플릿에서 install trigger와 bootstrap trigger를 분리
- PM/Development/QA Agent를 고정 조직 구조가 아니라 bootstrap Role로 재정의
- `workflow.md`를 PM -> Development -> QA 흐름에서 책임 단계 기반 흐름으로 개정
- `task_queue.md`, `workflows/`, Task 템플릿, Task Board 템플릿을 vNext 상태 체계로 개정
- `capabilities.md`를 Role 기반 capability 체계로 개정
- `agent_registry.md`와 프로젝트 agent registry 템플릿의 capability 매핑을 vNext 기준으로 정리
- project task board 템플릿에 Team Summary, Role Summary, Ownership / Coordination 섹션 추가
- 기존 Development 전용 보고 템플릿을 제거하고 공통 `task_report.md`를 Role 기반 보고로 개편
- QA 템플릿을 QA Agent 고정에서 Verification Role 기준으로 개편
- Team별 운영 구성을 위한 `templates/ai_project/team_context.md` 추가
- `.ai_project` 템플릿을 프로젝트별 선택값과 Team/Role placeholder 중심으로 개편
- 루트 운영 문서를 `core/`, `models/`, `policies/`, `runtime/`, `bootstrap/`으로 재분류
- 프로젝트 bootstrap 앞단에 Start Context와 Readiness Level 분류 흐름 추가

## 0.5.1 - 2026-07-09

### Changed

- Agent Role은 세션 시작 시 부여하고, Task 실행 가능 여부는 Role, workflow, status, target_agent 조합으로 확인하도록 기준 정리
- 프로젝트 디렉토리 구조는 고정하지 않고, 실제 작업 범위는 `allowed_paths`, 기준 문서는 `source_of_truth`가 결정하도록 문구 보강
- PM/Development/QA는 기본 Role 예시이며 프로젝트별 workflow에 따라 Role을 추가/삭제할 수 있음을 명시

## 0.5.0 - 2026-07-07

### Added

- `.ai_project/tasks/active/`, `backlog/`, `archive/YYYY-MM/` Task 보관 구조 기준 추가
- 기존 `.ai_project/tasks/` 루트 Task를 legacy Task로 인정하는 호환 규칙 추가

### Changed

- PM/Development/QA Agent의 Task 탐색 기준을 active 우선, legacy 호환, backlog/archive 제한 탐색으로 정리

## 0.4.1 - 2026-07-03

### Changed

- 기본 workflow에서 `rework_requested`는 PM Agent가 재개 여부와 범위를 확인하는 상태로 정리
- PM Agent가 사용자 승인 또는 기존 승인 범위 내 재개 판단을 반영해 `approved`로 전환하면 담당 Agent가 실행하는 기준 추가
- 특정 workflow가 직접 재작업 전이를 명시하면 해당 workflow를 따를 수 있도록 예외 가능성 유지

## 0.4.0 - 2026-07-03

### Added

- `VERSION` 파일 추가
- 중앙 `CHANGELOG.md` 추가
- 공통 작업 완료 보고 템플릿 `templates/reports/task_report.md` 추가

### Changed

- `.ai_project/reports/`의 기본 보고를 Development 전용 보고에서 공통 Task Report로 일반화
- Task 템플릿의 `report_to` 기본값을 `T-..._dev-report.md`에서 `T-..._task-report.md`로 변경
- QA Agent의 보고 확인 기준을 Development Agent 보고서가 아니라 `report_to` 경로의 작업 보고서로 변경
- QA 인계 기준을 Agent 문서의 고정 규칙이 아니라 `workflow`, `status`, `target_agent` 조합 기준으로 일반화
- 기본 workflow에서는 한 번에 한 단계씩 상태 전이를 수행하고, workflow가 명시적으로 허용한 경우에만 연속 전이를 허용하도록 정리

### Fixed

- PM Agent가 직접 처리한 Task도 공통 작업 보고를 남길 수 있게 보고 기준 보강
- QA Agent가 다른 Agent 명의의 상태 전이 기록을 작성하지 않도록 운영 기준 명확화
- `dev_report.md`를 기본 양식이 아니라 Development Agent 전용 상세 참고 양식으로 재분류

## 0.3.0 - 2026-07-02

### Added

- `workflow`, `status`, `target_agent` 기반 Task 라우팅 기준 추가
- PM Agent가 다음 작업 후보를 안내할 때 담당 Agent, 담당 근거, 열 세션, 사용자 요청 문장을 함께 표시하는 기준 추가

### Changed

- `target_agent`의 의미를 "현재 상태에서 이 Task를 처리할 Agent"로 정리
- Agent별 고정 권한보다 workflow별 상태 전이와 전이 후 `target_agent`를 우선하도록 운영 기준 변경
- Task 실행 기준을 `approved` 여부만이 아니라 `workflow`, `status`, `target_agent`, `required_capabilities` 조합으로 판단하도록 정리

### Fixed

- `target_agent`가 다른 Agent인 Task를 capability만 보고 실행할 수 있는 문제 방지
- QA 통과 후 PM 확정 대기 단계와 `done` 확정 단계를 문서상 분리

## 0.2.0 - 2026-07-01

### Added

- AI Ops Agent 역할과 책임 추가
- 새 프로젝트 또는 기존 프로젝트에 AI Agent 운영 체계를 도입하는 `ops_migration` workflow 추가
- 요구사항 접수 시 기존 Task Queue와 비교해 priority, 의존성, Queue 영향을 먼저 정리하는 기준 추가

### Changed

- AI 운영 마이그레이션 주체를 PM Agent가 아니라 AI Ops Agent로 정리
- `.ai_project/` 초기화와 운영 문서 구조 점검 책임을 AI Ops Agent 중심으로 분리

### Fixed

- 운영 프로세스 관리 책임이 PM Agent와 섞이는 문제를 줄이기 위해 AI Ops Agent를 제품 Task 실행 라인 밖으로 분리

## 0.1.0 - 2026-06-29

### Added

- AI Agent 운영 템플릿 초기 구조 추가
- PM Agent, Development Agent, QA Agent 기본 역할 문서 추가
- Agent registry, capabilities, workflow, task queue 정책 추가
- `.ai_project/` 프로젝트 협업 문서 구조와 템플릿 추가
- Codex용 `AGENTS.md` 어댑터 템플릿 추가
- 프로젝트 핵심 문서 템플릿 추가
- AI Agent 운영 튜토리얼 추가
- 커밋 정책과 문서 거버넌스 기준 추가

### Changed

- 복사/붙여넣기 지시 중심 운영에서 `.ai_project/tasks/` Task Queue 중심 운영으로 방향 정리
- `.ai/`는 템플릿 저장소, `.ai_project/`는 프로젝트 종속 협업 상태로 분리

### Fixed

- 초기 운영에서 Agent별 역할과 산출물, 금지사항, 승인 게이트가 섞이지 않도록 기본 경계 설정

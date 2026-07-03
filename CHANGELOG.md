# Changelog

이 문서는 `ai-agent-ops` 템플릿의 버전별 변경 이력을 기록한다.

버전은 아래 기준으로 관리한다.

- Major: 기존 프로젝트 적용 방식과 호환되지 않는 운영 구조 변경
- Minor: 새 Agent, workflow, 템플릿, 운영 규칙 추가 또는 기본 흐름 변경
- Patch: 문구 정리, 충돌 제거, 설명 보강, 누락 수정

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

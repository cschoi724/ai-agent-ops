# Project Dashboard Follow-up Implementation Plan

상태: 진행 중 / 1~6차 완료
대상: `aiops project dashboard` HTML/CLI 사용성 확장
기준 버전: v0.13.0
작성일: 2026-08-10

진행 현황:

- 1차 User Command Layer: 구현 완료, PR #28~#29로 main 반영 완료
- 2차 Help UX / Localized Command Guide: 구현 완료, PR #30~#31로 main 반영 완료
- 3차 User CLI Visualization: 구현 완료, PR #32~#35로 main 반영 완료
- 4차 Large Graph Explorer: 구현·독립 검증 완료, PR #36으로 main 반영 완료
- 5차 Local Serve / Refresh: 구현·독립 검증 완료, PR #38로 main 반영 완료
- 6차 Dashboard Presets: 구현·독립 검증 완료, PR #40으로 main 반영 완료

이 문서는 v0.13.0에서 완료된 Project Dashboard의 후속 개선 후보를 실제 구현 가능한 차수로 정리한다.

v0.13.0의 목표는 dashboard/work map을 사용할 수 있는 형태로 완성하고 Homebrew로 배포하는 것이었다. 이 후속 계획의 목표는 큰 프로젝트에서 대시보드를 더 오래, 더 자주, 더 적은 명령으로 사용할 수 있게 만드는 것이다.

## 현재 기준

이미 완료된 기능:

- `aiops project dashboard`
- `--view main|work|risk|agents|release`
- `--level compact|standard|detail`
- `--format terminal|tree|mermaid|html`
- `--map summary|dependencies|swimlane|critical-path|workflow|agents|blockers`
- `--focus TASK_ID --depth N`
- `--group-by agent|role|status|workflow|area`
- `--json`
- `aiops.project_dashboard.v1` schema
- HTML Mermaid rendering, map section collapse, zoom control, source detail
- 사용자용 label catalog 기반 표시명

현재 한계:

- 사용자용 명령과 Agent/자동화용 명령이 같은 `project dashboard` 하위 옵션에 섞여 있다.
- 사용자 입장에서는 `--view`, `--format`, `--map`, `--group-by`, `--focus` 조합이 길고 어렵다.
- `aiops help`가 너무 많은 명령을 한 번에 보여주며, 어떤 명령을 언제 써야 하는지 설명이 부족하다.
- Agent/자동화용 명령이 기본 help에 노출되어 사용자용 명령 선택을 방해한다.
- help 설명 문구가 지역화된 사용자 언어 catalog로 관리되지 않는다.
- CLI 기본 화면은 기계 판독 상태어를 일부 그대로 노출하며, HTML만큼 사용자용 언어/시각화가 충분하지 않다.
- HTML은 정적 스냅샷이라 운영 데이터가 바뀌면 다시 생성해야 한다.
- HTML 운영 데이터는 정적 스냅샷이며, 브라우저를 열어 둔 상태에서 자동 갱신되지 않는다.
- 자주 쓰는 dashboard 조합을 매번 긴 명령으로 입력해야 한다.
- release view는 로컬 상태 중심이며 GitHub PR/CI 상태를 직접 읽지 않는다.
- locale catalog는 내부 기본값 중심이고 외부 확장 지점이 약하다.
- HTML 시각 배치는 E2E 계약 검증 위주이며 브라우저 visual regression은 없다.
- Mermaid map을 이미지 파일로 바로 공유할 수 없다.

## 우선순위

| 순위 | 후보 | 이유 |
|---|---|---|
| 1 | 사용자용 명령 계층 | 긴 옵션 조합을 숨기고 사람이 바로 쓰는 entrypoint 제공 |
| 2 | Help UX / 지역화 설명 | 기본 help를 사용자용으로 줄이고 AI용 명령은 명시 요청 시만 노출 |
| 3 | 사용자용 CLI 시각화 | HTML 없이도 터미널에서 가볍게 상태를 이해 |
| 4 | 큰 graph 탐색 개선 | CookLog 같은 실제 프로젝트에서 가장 즉시 체감되는 사용성 문제 |
| 5 | 로컬 서버 / 새로고침 | 운영 중 HTML을 계속 다시 생성해야 하는 불편 제거 |
| 6 | Dashboard preset | 반복 명령을 줄이고 프로젝트별 운영 화면을 표준화 |
| 7 | GitHub PR/CI release view | 배포 판단에 필요한 외부 상태 연결 |
| 8 | Locale 확장 | 사용자 표시명 체계화와 다국어 확장 기반 |
| 9 | HTML visual regression | 브라우저 렌더링 안정성 강화 |
| 10 | SVG/PNG export | 보고/공유용 산출물 생성 |

## 설계 원칙

- Dashboard는 계속 source of truth가 아니다. `.ai_project`, snapshot, health, policy, action plan projection을 읽어 표시한다.
- HTML/serve/watch는 target project 파일을 수정하지 않는다.
- `.ai_project/.runtime/status_ref`는 로컬 cache이며 commit 대상으로 안내하지 않는다.
- 외부 네트워크가 필요한 기능은 기본 동작에 섞지 않고 명시 옵션으로 둔다.
- CLI terminal/json 계약은 가능한 한 안정적으로 유지한다.
- 사용자용 명령은 사용자 언어, 짧은 명령, 색상/진행률/요약을 기본값으로 삼는다.
- Agent/자동화용 명령은 machine contract와 raw key를 유지한다.
- 기본 help는 사용자용 entrypoint만 보여준다.
- AI/자동화용 명령은 `aiops help ai`, `aiops help machine`, `aiops help all`, `aiops --help --all`처럼 명시 요청 시 노출한다.
- help 설명 문구는 locale catalog로 관리한다.
- 큰 graph는 전체를 한 번에 보여주기보다 focus, filter, grouping, summary를 우선한다.

## 상태 projection 동작 기준

현재 CLI dashboard는 실행할 때마다 최신 상태를 읽는다.

동작 흐름:

```text
aiops project dashboard 실행
-> aiops project snapshot --json 재계산
-> aiops project health --json 재계산
-> dashboard projection 생성
-> terminal/tree/mermaid/html/json 출력
```

따라서 CLI 출력은 요청 시점 기준의 동적 projection이다. 별도 snapshot 파일을 저장해 재사용하지 않는다.

반면 `--format html --output dashboard.html`은 생성 시점의 정적 HTML이다. 브라우저가 파일을 새로고침해도 로컬 `.ai_project`를 다시 읽지 않는다. 동적 HTML을 원하면 로컬 서버가 필요하다.

후속 계획에서는 이를 아래처럼 구분한다.

- CLI: 실행할 때마다 현재 상태를 읽는 동적 화면
- HTML file: 공유/보관용 정적 스냅샷
- HTML serve: 브라우저 새로고침마다 server가 현재 projection과 HTML을 다시 만드는 동적 화면 (`/dashboard.json`은 별도 machine endpoint)
- JSON: Agent/자동화/테스트용 machine contract

## 1차. User Command Layer

목표:

- 사람이 쓰는 짧은 명령과 Agent가 쓰는 기계 계약 명령을 분리한다.
- 기존 `project dashboard` 고급 옵션은 유지하되, 사용자용 alias/entrypoint를 제공한다.

후보 명령:

```sh
aiops status
aiops work
aiops map
aiops dashboard
aiops dashboard open
aiops dashboard serve
aiops risks
aiops agents
aiops release
```

명령 매핑:

| 사용자용 명령 | 내부 매핑 |
|---|---|
| `aiops status` | `aiops project dashboard --view main --level compact` |
| `aiops work` | `aiops project dashboard --view work --level standard` |
| `aiops map` | `aiops project dashboard --format html --map summary --output <temp>` |
| `aiops dashboard` | `aiops project dashboard --format html --output <temp>` |
| `aiops dashboard open` | HTML 생성 후 기본 브라우저 열기 |
| `aiops dashboard serve` | 로컬 serve mode |
| `aiops risks` | `aiops project dashboard --view risk` |
| `aiops agents` | `aiops project dashboard --view agents` |
| `aiops release` | `aiops project dashboard --view release` |

Agent/자동화용 명령:

```sh
aiops project snapshot --json
aiops project health --json
aiops project dashboard --json
aiops project context --role ROLE --task TASK_ID
aiops policy evaluate --json
```

구현 범위:

- top-level command routing 추가
- 사용자용 명령에서는 기본 color auto 적용
- 사용자용 명령에서는 machine key 대신 display label 우선 표시
- `--target DIR`는 사용자용 명령에서도 지원

비범위:

- 기존 `project dashboard` 옵션 제거
- JSON 출력의 raw key 변경
- Task 상태 변경

검증:

- `aiops status`, `aiops work`, `aiops risks`, `aiops agents`, `aiops release` smoke
- 사용자용 명령과 내부 매핑 명령의 핵심 projection 값 일치
- Agent/자동화용 JSON 출력은 byte-level 의미 회귀 없음

## 2차. Help UX / Localized Command Guide

목표:

- 기본 help에서 사용자가 바로 쓸 명령만 보여준다.
- AI/자동화용 명령은 숨기되, 명시 옵션으로 접근 가능하게 한다.
- 각 명령에 "언제 쓰는지", "예시", "비슷한 명령"을 지역화된 설명으로 제공한다.

후보 명령:

```sh
aiops help
aiops --help
aiops help work
aiops help dashboard
aiops help ai
aiops help machine
aiops help all
aiops --help --all
aiops help --locale ko
aiops help work --locale en
```

기본 help 노출 정책:

```text
AI Ops

자주 쓰는 명령어

  aiops status       프로젝트 상태와 다음 추천 작업을 봅니다
  aiops work         현재 일감과 담당자를 봅니다
  aiops dashboard    브라우저용 대시보드를 만듭니다
  aiops open         대시보드를 만들고 브라우저로 엽니다
  aiops sync         협업 기준 상태를 동기화합니다
  aiops doctor       프로젝트 설정 문제를 점검합니다

더 보기

  aiops help work       work 명령 자세히 보기
  aiops help dashboard  dashboard 명령 자세히 보기
  aiops help ai         Agent/자동화용 명령 보기
  aiops help all        전체 명령 보기
```

명령별 help 예시:

```text
aiops work

현재 활성 일감, 상태, 담당 역할/에이전트를 보여줍니다.

사용 예:
  aiops work
  aiops work --detail
  aiops work --target ./CookLog

비슷한 명령:
  aiops status       전체 상태 요약
  aiops dashboard    브라우저 대시보드 생성
```

기본 help에서 숨길 AI/자동화용 명령:

```sh
aiops project snapshot --json
aiops project health --json
aiops project dashboard --json
aiops project context --role ROLE --task TASK_ID
aiops policy evaluate --json
aiops action plan --json
aiops validate project-dashboard FILE
```

구현 범위:

- 기본 help를 사용자용 quick help로 교체
- `help ai` / `help machine` / `help all` 추가
- `--help --all` 추가
- 명령별 help 라우팅 추가
- help 문구 locale catalog 설계
- 기본 locale은 `ko`
- 환경변수 `AIOPS_LOCALE` 검토
- `--locale ko|en` 옵션 검토
- 사용자용 help와 AI용 help의 목적 차이를 문서화

locale catalog 후보:

```text
runtime/help_catalog.ko.json
runtime/help_catalog.en.json
```

초기 구현에서는 shell 유지보수 비용을 낮추기 위해 내장 catalog helper로 시작할 수 있다. 단, 문구 key와 lookup helper를 분리해 나중에 JSON catalog로 옮길 수 있게 한다.

비범위:

- 모든 기존 명령의 장문 매뉴얼화
- JSON schema 설명 전체 번역
- AI/자동화용 명령 삭제
- 기본 help에서 모든 고급 옵션 표시

검증:

- `aiops help`가 사용자용 명령만 짧게 표시
- `aiops help ai`가 machine contract 명령을 표시
- `aiops help all`이 전체 명령을 표시
- `aiops help work`가 설명, 예시, 비슷한 명령을 표시
- 기본 help에 `project snapshot --json` 같은 AI용 명령이 직접 노출되지 않음
- locale fallback이 동작
- 기존 `aiops help` 호출 exit code 회귀 없음

## 3차. User CLI Visualization

목표:

- HTML을 열지 않아도 터미널에서 프로젝트 상태를 가볍게 이해한다.
- 사용자용 CLI 화면은 한국어 라벨, 색상, 진행률, 요약 중심으로 보여준다.

구현 명령:

```sh
aiops status
aiops work
aiops work --format tree
aiops risks
aiops agents
aiops release
```

구현 범위:

- 진행률 bar
- readiness/status color badge
- warning/blocker compact list
- 현재 일감 column 또는 section view
- 상태별/담당자별 count bar
- next action을 사용자용 문장으로 표시
- 내부 용어 치환
  - `target_role` -> 담당 역할
  - `target_agent` -> 담당 에이전트
  - `status_ref_sha` -> 기준 SHA
  - `workflow_policy` -> 작업 흐름 정책
  - `canonical_status_ref` -> 공용 기준 브랜치
- terminal label catalog를 HTML label catalog와 공유하거나 공통 catalog로 승격

구현 결과:

- `aiops status`는 진행률, 운영 readiness, 현재 일감, 주의 항목, 다음 추천을 한국어 요약으로 표시한다.
- `aiops work`는 상태 요약, 일감 목록, 담당 역할/에이전트, 다음 조치를 사용자용 라벨로 표시한다.
- `aiops work --format tree`는 큰 일감 목록을 상태별 트리로 접어서 표시한다.
- `aiops risks`는 차단/주의 항목과 공용 기준 상태, 미해결 결정, 메타데이터 누락, 기준 SHA 누락, 에이전트 drift를 표시한다.
- `aiops agents`는 에이전트 활성 상태, 팀, 역할, 담당 일감 수를 표시한다.
- `aiops release`는 출시 readiness, 공용 기준 상태, 차단 항목, release-check 명령을 표시한다.
- `--color always|never|auto`를 사용자용 CLI 출력에도 적용한다.
- 고급 `aiops project dashboard` terminal/tree 출력은 기존 진단형 출력으로 유지하고, 사용자용 top-level 명령만 별도 표시층을 사용한다.

예상 출력:

```text
CookLog 상태

진행률    47 / 68 완료  [███████████████░░░░░]
작업 가능  가능, 주의 3개
협업 상태  준비됨
마이그레이션 완료

현재 일감
승인됨  1개  iOS Audio Guide 구현
범위정리 2개  iOS CI 기본 파이프라인, iOS 디자인 적용
제안됨 17개  앱 정보/오프라인/장애 상태 외 16개

다음 추천
- aiops work
- aiops dashboard open
```

비범위:

- full TUI
- ncurses/interactive terminal app
- Mermaid terminal rendering

검증:

- color always/never/auto 처리
- 좁은 터미널에서도 text overflow가 과하지 않음
- CLI 사용자용 라벨이 HTML 라벨과 충돌하지 않음
- terminal dashboard 기존 출력과 새 사용자용 출력이 서로 역할을 침범하지 않음

## 4차. Large Graph Explorer

목표:

- Task가 많은 프로젝트에서도 dependency/work map을 탐색 가능한 크기로 만든다.
- 전체 dependency map을 기본으로 강제하지 않고, 검색/필터/focus 중심 UX를 제공한다.

후보 명령:

```sh
aiops project dashboard --format html --output dashboard.html
aiops project dashboard --format html --map dependencies --focus TASK_ID --depth 2 --output dashboard.html
aiops project dashboard --format html --filter-status approved,scoped --output dashboard.html
aiops project dashboard --format html --filter-agent "iOS Agent" --output dashboard.html
```

구현 범위:

- HTML client-side task search
- status / agent / role / workflow filter
- focus task 선택 UI
- depth 1~4 선택 UI
- done/proposed/scoped/approved toggle
- dependency graph section에서 collapsed group 우선 표시
- 큰 graph 경고와 추천 view 안내
- filtered graph의 Mermaid source 재생성 또는 precomputed map set 선택

비범위:

- Task 상태 변경
- source of truth 수정
- 외부 graph layout engine 도입

검증:

- CookLog 규모 fixture에서 HTML 기본 화면이 summary map으로 열림
- dependencies map에서 focus/depth 적용 시 노드 수가 줄어듦
- filter UI label이 locale catalog를 사용함
- JSON projection은 필터 때문에 의미가 바뀌지 않음
- dashboard 실행 후 target project git status가 dirty가 아님

## 5차. Local Serve / Refresh

목표:

- HTML 파일을 매번 다시 생성하지 않고 브라우저에서 최신 projection을 볼 수 있게 한다.
- 로컬 개발자 환경에서만 동작하는 가벼운 서버를 제공한다.

후보 명령:

```sh
aiops project dashboard --serve
aiops project dashboard --serve --port 8765
aiops project dashboard --serve --refresh 10
aiops project dashboard --serve --open
```

구현 범위:

- localhost HTTP server
- `/` HTML dashboard
- `/dashboard.json` projection endpoint
- `/maps/<name>.mmd` Mermaid source endpoint
- browser auto-refresh interval
- server startup message에 target, port, refresh interval 표시
- `--open`은 macOS `open` 사용 가능 시 브라우저 실행

비범위:

- 외부 배포
- 원격 접속 보안 모델
- 장기 daemon 관리
- 파일 watcher 기반 자동 task 변경

검증:

- 지정 port에서 HTML 응답
- `/dashboard.json`이 schema validation 통과
- refresh interval meta/script 포함
- 서버 실행 중 target project 파일 불변
- port 충돌 시 명확한 오류 또는 다음 port 제안

## 6차. Dashboard Presets

목표:

- 긴 dashboard 명령을 프로젝트별 짧은 이름으로 저장하고 재사용한다.
- 반복 운영 화면을 팀 표준으로 만들 수 있게 한다.

구현 명령:

```sh
aiops project dashboard --preset overview
aiops project dashboard preset list
aiops project dashboard preset show work-current
aiops project dashboard preset add team-live --view work --format html --map dependencies --serve --port 0 --refresh 10
aiops project dashboard --preset team-live --open
```

완료 범위:

- 기본 built-in preset
  - `overview`
  - `work-current`
  - `risk-review`
  - `agent-load`
  - `release-readiness`
- 프로젝트 local preset 파일: `.ai_project/dashboard_presets.json`
- `aiops.dashboard_presets.v1` schema와 semantic validation
- local preset list/show/add 및 `--force` 교체
- `dashboard 기본값 < preset < 명시적 CLI 옵션` 우선순위
- preset 기반 localhost serve, port, refresh, open 연동
- preset은 기존 dashboard 옵션으로만 확장하며 source data를 수정하지 않음
- 잘못된 이름·옵션·범위·실행 불가능한 조합을 저장·검증 단계에서 차단
- 예상 가능한 JSON·파일 시스템 오류를 stack trace 없는 사용자 오류로 표시

비범위:

- preset 실행 결과 저장
- dashboard HTML을 source of truth로 보관

검증:

- built-in/local preset list/show/add/실행과 명시 옵션 override 통과
- preset 실행과 명시 옵션 실행의 JSON projection 동일
- 기존 terminal/tree/Mermaid/JSON 및 사용자 단축 명령 machine contract 유지
- local serve HTTP endpoint와 종료 후 port 해제 통과
- 잘못된 이름·schema·serve/format 조합·파일 오류 negative E2E 통과
- 독립 검증 High/Medium/Low 이슈 없음
- `scripts/test.sh` 및 strict release check 통과

## 7차. GitHub PR / CI Release View

목표:

- release view에서 로컬 readiness뿐 아니라 GitHub PR/CI 상태까지 확인한다.
- 배포 판단에 필요한 외부 상태를 한 화면에 모은다.

후보 명령:

```sh
aiops project dashboard --view release --github
aiops project dashboard --view release --github --repo owner/name
aiops project dashboard --format html --view release --github --output release.html
```

구현 범위:

- `gh` CLI 존재 여부와 인증 상태 확인
- 현재 repo, branch, open PR 감지
- required checks / latest check conclusion 표시
- mergeable state 표시
- 최신 release tag와 local VERSION 비교
- GitHub 데이터는 unavailable 상태를 정상 표시

비범위:

- PR 생성/머지/태그/릴리즈 실행
- GitHub API 없을 때 dashboard 실패 처리
- required check 정책을 독자 판단으로 대체

검증:

- `--github` 없이는 네트워크/API 호출 없음
- `gh` 미인증 시 release view에 unavailable warning 표시
- JSON projection에 GitHub section은 optional
- HTML release card가 로컬 상태와 GitHub 상태를 구분 표시

## 8차. Locale Extension

목표:

- 사용자 표시명 catalog를 CLI/HTML에서 확장 가능하게 만든다.
- 기본 `ko` catalog를 유지하면서 `en` 또는 프로젝트별 label override를 지원한다.

후보 명령:

```sh
aiops project dashboard --locale ko
aiops project dashboard --locale en
aiops project dashboard --locale-file .ai_project/dashboard_labels.ko.json
```

구현 범위:

- locale option parser
- built-in `ko`, `en` catalog
- external locale file schema 검토
- unknown key readable fallback 유지
- terminal 출력 적용 여부는 별도 결정

비범위:

- 전체 문서 번역
- source task metadata 번역
- dashboard가 원본 machine key를 제거

검증:

- `ko`와 `en` HTML label snapshot
- unknown key fallback
- Mermaid internal id는 locale과 무관하게 stable
- JSON projection 기본 machine value 보존

## 9차. HTML Visual Regression

목표:

- HTML dashboard가 브라우저에서 실제로 깨지지 않는지 검증한다.
- Mermaid CDN 로딩, map section, zoom controls, 색상 범례를 최소 시각 기준으로 확인한다.

구현 범위:

- Playwright 또는 lightweight browser smoke test 검토
- fixture HTML 생성
- desktop/mobile viewport screenshot
- Mermaid rendered node 존재 확인
- 주요 UI text overflow 확인

비범위:

- pixel-perfect 디자인 승인
- 모든 프로젝트 fixture 스크린샷 보관

검증:

- HTML 렌더링 후 Mermaid SVG 존재
- zoom button 동작 smoke
- collapse/expand smoke
- screenshot artifact 생성
- CI 비용 증가가 과하면 optional job으로 분리

## 10차. SVG / PNG Export

목표:

- dashboard map을 PR, 문서, 회의에 바로 붙일 수 있는 이미지로 내보낸다.

후보 명령:

```sh
aiops project dashboard --format svg --map summary --output dashboard.svg
aiops project dashboard --format png --map dependencies --focus TASK_ID --depth 2 --output dashboard.png
```

구현 범위:

- Mermaid source -> SVG/PNG 렌더링 경로 검토
- local dependency 없이 가능한 경로 우선
- 실패 시 Mermaid source fallback 안내
- export metadata 주석 또는 sidecar JSON 검토

비범위:

- Figma 자동 생성
- 원격 렌더링 서비스 의존

검증:

- SVG/PNG 파일 생성
- 빈 프로젝트와 큰 프로젝트 fixture 처리
- output 파일 외 target project 불변
- export 실패 시 non-zero와 복구 가능한 안내

## 차수별 권장 PR

| 차수 | 브랜치 | PR 범위 |
|---|---|---|
| 1차 | `feature/user-command-layer` | `aiops status/work/dashboard` 같은 사용자용 명령 계층 |
| 2차 | `feature/help-ux-localized-guide` | 사용자용 기본 help, AI용 숨김 help, 명령별 지역화 설명 |
| 3차 | `feature/user-cli-visualization` | 사용자용 CLI 진행률/색상/요약 화면 |
| 4차 | `feature/dashboard-graph-explorer` | HTML graph 검색/필터/focus/depth |
| 5차 | `feature/dashboard-serve-refresh` | localhost serve와 refresh |
| 6차 | `feature/dashboard-presets` | built-in preset과 local preset 계약 |
| 7차 | `feature/dashboard-github-release-view` | optional GitHub release/PR/CI projection |
| 8차 | `feature/dashboard-locale-extension` | locale option과 external catalog |
| 9차 | `feature/dashboard-visual-regression` | browser smoke/visual test |
| 10차 | `feature/dashboard-export` | SVG/PNG export |

## 공통 검증 게이트

각 차수 PR은 최소 아래를 통과해야 한다.

```sh
git diff --check
sh scripts/test.sh
bin/aiops release-check --strict --allow-pending-release
```

Dashboard 변경 차수는 추가로 아래를 확인한다.

- CookLog 대상 HTML 생성
- 생성 명령 실행 후 CookLog 작업 트리 불변
- JSON schema validation
- terminal dashboard 회귀 없음
- Mermaid internal id 안정성
- 사용자 표시 라벨이 machine key를 과도하게 노출하지 않음
- 사용자용 명령이 machine contract 명령을 대체한다고 안내하지 않음
- 기본 help가 AI/자동화용 명령을 과도하게 노출하지 않음
- help 설명이 locale fallback을 가진 사용자용 문장으로 표시됨

외부 상태를 읽는 차수는 추가로 아래를 확인한다.

- 옵션을 켜지 않으면 네트워크 호출 없음
- 인증 실패 또는 네트워크 실패가 dashboard 전체 실패로 번지지 않음
- API 결과를 source of truth처럼 저장하지 않음

## 추천 시작점

5차 독립 검증과 main 반영이 끝났으므로 6차 `Dashboard Presets`를 진행한다.

이유:

- 1~3차에서 사용자 명령, help, CLI 표시 계층을 분리했고 4차에서 큰 그래프 탐색 문제를 줄였다.
- 5차에서 브라우저 새로고침마다 최신 projection을 만드는 localhost serve 흐름을 추가했다.
- 다음 사용성 문제는 반복해서 사용하는 긴 dashboard 옵션 조합이므로, 6차에서 프로젝트별 preset 저장·조회·재사용 흐름을 제공한다.

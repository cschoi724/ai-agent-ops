# Project Dashboard Follow-up Implementation Plan

상태: 제안 / v0.13.0 이후 후속 개선 계획
대상: `aiops project dashboard` HTML/CLI 사용성 확장
기준 버전: v0.13.0
작성일: 2026-08-10

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

- HTML은 정적 스냅샷이라 운영 데이터가 바뀌면 다시 생성해야 한다.
- 큰 dependency graph는 여전히 한 화면에서 복잡하다.
- 자주 쓰는 dashboard 조합을 매번 긴 명령으로 입력해야 한다.
- release view는 로컬 상태 중심이며 GitHub PR/CI 상태를 직접 읽지 않는다.
- locale catalog는 내부 기본값 중심이고 외부 확장 지점이 약하다.
- HTML 시각 배치는 E2E 계약 검증 위주이며 브라우저 visual regression은 없다.
- Mermaid map을 이미지 파일로 바로 공유할 수 없다.

## 우선순위

| 순위 | 후보 | 이유 |
|---|---|---|
| 1 | 큰 graph 탐색 개선 | CookLog 같은 실제 프로젝트에서 가장 즉시 체감되는 사용성 문제 |
| 2 | 로컬 서버 / 새로고침 | 운영 중 HTML을 계속 다시 생성해야 하는 불편 제거 |
| 3 | Dashboard preset | 반복 명령을 줄이고 프로젝트별 운영 화면을 표준화 |
| 4 | GitHub PR/CI release view | 배포 판단에 필요한 외부 상태 연결 |
| 5 | Locale 확장 | 사용자 표시명 체계화와 다국어 확장 기반 |
| 6 | HTML visual regression | 브라우저 렌더링 안정성 강화 |
| 7 | SVG/PNG export | 보고/공유용 산출물 생성 |

## 설계 원칙

- Dashboard는 계속 source of truth가 아니다. `.ai_project`, snapshot, health, policy, action plan projection을 읽어 표시한다.
- HTML/serve/watch는 target project 파일을 수정하지 않는다.
- `.ai_project/.runtime/status_ref`는 로컬 cache이며 commit 대상으로 안내하지 않는다.
- 외부 네트워크가 필요한 기능은 기본 동작에 섞지 않고 명시 옵션으로 둔다.
- CLI terminal/json 계약은 가능한 한 안정적으로 유지한다.
- 큰 graph는 전체를 한 번에 보여주기보다 focus, filter, grouping, summary를 우선한다.

## 1차. Large Graph Explorer

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

## 2차. Local Serve / Refresh

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

## 3차. Dashboard Presets

목표:

- 긴 dashboard 명령을 프로젝트별 짧은 이름으로 저장하고 재사용한다.
- 반복 운영 화면을 팀 표준으로 만들 수 있게 한다.

후보 명령:

```sh
aiops project dashboard --preset ios-current
aiops project dashboard preset list
aiops project dashboard preset show ios-current
aiops project dashboard preset add ios-current --view work --map swimlane --group-by agent --filter-area ios
```

구현 범위:

- 기본 built-in preset
  - `overview`
  - `work-current`
  - `risk-review`
  - `agent-load`
  - `release-readiness`
- 프로젝트 local preset 파일 검토
  - 후보: `.ai_project/dashboard_presets.json`
- preset은 명령 옵션으로 expand만 하고 source data를 수정하지 않음
- preset schema 추가 여부 검토

비범위:

- preset 실행 결과 저장
- dashboard HTML을 source of truth로 보관

검증:

- preset list/show 출력
- preset 실행이 명시 옵션과 같은 projection을 생성
- 잘못된 preset 이름은 non-zero와 추천 목록 출력
- local preset schema 오류가 명확히 표시됨

## 4차. GitHub PR / CI Release View

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

## 5차. Locale Extension

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

## 6차. HTML Visual Regression

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

## 7차. SVG / PNG Export

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
| 1차 | `feature/dashboard-graph-explorer` | HTML graph 검색/필터/focus/depth |
| 2차 | `feature/dashboard-serve-refresh` | localhost serve와 refresh |
| 3차 | `feature/dashboard-presets` | built-in preset과 local preset 계약 |
| 4차 | `feature/dashboard-github-release-view` | optional GitHub release/PR/CI projection |
| 5차 | `feature/dashboard-locale-extension` | locale option과 external catalog |
| 6차 | `feature/dashboard-visual-regression` | browser smoke/visual test |
| 7차 | `feature/dashboard-export` | SVG/PNG export |

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

외부 상태를 읽는 차수는 추가로 아래를 확인한다.

- 옵션을 켜지 않으면 네트워크 호출 없음
- 인증 실패 또는 네트워크 실패가 dashboard 전체 실패로 번지지 않음
- API 결과를 source of truth처럼 저장하지 않음

## 추천 시작점

바로 진행한다면 1차 `Large Graph Explorer`부터 시작한다.

이유:

- 사용자가 실제로 체감한 문제는 큰 dependency map의 복잡도다.
- 서버/watch나 export보다 먼저 graph 자체를 읽기 쉽게 만들어야 한다.
- HTML 정적 파일 안에서 대부분 해결 가능해 배포/보안 부담이 작다.
- 이후 serve mode에서도 같은 filter/focus UI를 재사용할 수 있다.

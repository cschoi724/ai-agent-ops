# History Policy

작성일: 2026-11-20  
상태: Active (0.20.0)  
범위: `.ai_project/history/` 기록보관소

## 1. 목적

디스크 공간 때문에 worktree, Task 보고서, 실험 산출물, 빌드 폴더, 끝난 Task는 계속 정리해야 한다. 정리하면 "왜 그렇게 했는지"(배경, Owner가 한 말, 판단 근거, 실험 결과)가 같이 사라진다. 나중에 같은 실험을 다시 하거나 배경을 잘못 기억하지 않도록, 지우기 전에 이 내용을 작은 텍스트 기록으로 남긴다.

## 2. 위치와 역할 구분

| 위치 | 담는 것 |
|---|---|
| `.ai_knowledge/` (Wiki) | 지금 제품이 어떻게 되어 있는가 (현재 사실, 구조, 용어) |
| `.ai_project/history/` (기록보관소) | 왜 이렇게 되었는가 (지운 것, 결정의 배경, Owner 발언, 판단 근거, 실험 결과, 복원 방법) |
| `.ai_project/ops_decisions.md` | 운영 결정 한 줄 요약. 자세한 배경은 history 기록으로 링크한다 |

Wiki와 운영 문서는 필요한 곳에서 history 기록으로 링크만 건다. 내용을 복사하지 않는다.

## 3. 구조

```text
.ai_project/history/
  INDEX.md                         # 한 줄에 기록 하나: 날짜 | 분류 | 제목 | Task | 요약 | 기록
  2026-11-19-disk-cleanup/
    README.md                      # 본문 (aiops.history.v1 front matter)
    worktrees.patch                # 필요하면 작은 텍스트 첨부
```

- 폴더 이름은 `YYYY-MM-DD-<주제>`다. 주제는 영어 소문자, 숫자, `-`만 쓴다.
- 분류는 폴더가 아니라 INDEX의 `분류` 칸과 front matter `category`로 한다: `cleanup`(정리·삭제), `decision`(결정), `experiment`(실험), `task-archive`(Task 보관), `structure`(구조 변경), `other`.
- 찾을 때는 INDEX.md를 먼저 grep하고(Task ID, 분류, 낱말) 필요한 기록만 연다.

## 4. 언제 기록하는가

아래 작업은 **하기 전에** 기록을 먼저 쓴다.

- worktree, Task 보고서·QA·실험 폴더, 빌드 산출물처럼 다시 만들기 어렵거나 판단 근거가 들어 있는 것을 지울 때
- 끝난 Task를 `tasks/archive/`로 옮기면서 보고서를 지우거나 줄일 때
- 운영 구조(팀, 작업 폴더, 규칙)를 바꾸는 큰 결정을 했을 때
- 시간이 많이 든 실험의 결론을 남겨야 할 때

캐시처럼 근거가 없고 언제든 다시 만들 수 있는 것은 기록하지 않아도 된다. 다만 크기가 크면 한 줄이라도 남긴다.

## 5. 기록 내용

`aiops history new <주제> --category <분류> --task <Task ID> --title "<제목>" --summary "<한 줄 요약>"`이 템플릿으로 파일을 만들고 INDEX에 한 줄을 넣는다.

| 항목 | 쓰는 법 |
|---|---|
| 배경 (필수) | 왜 이 일이 생겼는지, 그때 숫자와 상태 |
| Owner 발언 | 결정에 쓰인 Owner의 말을 날짜와 함께 **그대로** 인용한다. 요약하거나 바꾸지 않는다 |
| 판단과 이유 (필수) | 무엇을 하기로 했고 왜 |
| 검토했다가 버린 방법 | 다른 방법과 버린 이유 |
| 실험·확인 결과 | 돌린 명령, 핵심 숫자, 결론. 다시 실험하지 않아도 될 만큼 |
| 지운 것과 남긴 것 | 대상, 크기, 처리, 이유 |
| 복원 방법 | 커밋, patch, 다시 만드는 명령 |
| 관련 자료 | Task, 커밋, 남은 보고서 경로 |

## 6. 크기와 형식

- 텍스트만 넣는다: `md`, `txt`, `patch`, `diff`, `csv`, `tsv`.
- 로그 원본, json 덤프, 이미지, 압축 파일, 빌드 산출물은 넣지 않는다. 필요한 줄과 숫자만 옮긴다.
- 기록 하나는 기본 1024 KB를 넘기지 않는다. 운영 모델 front matter `history_record_max_kb`로 바꿀 수 있다.
- 비밀번호, 토큰, 개인정보, 고객 데이터는 넣지 않는다.

## 7. 검사

- `aiops history lint`: INDEX와 실제 기록이 맞는지, 링크가 살아 있는지, 새 형식 기록의 분류·필수 항목·크기·파일 형식을 검사한다. front matter가 없는 예전 기록은 note만 출력하고 막지 않는다.
- `aiops history index`: INDEX.md를 만들고 아직 목록에 없는 기록에 한 줄을 붙인다. 기존 줄과 기록 파일은 바꾸지 않는다. `aiops migrate --apply`가 같이 실행한다.
- `aiops doctor`: history lint 오류와 "보고서가 지워졌는데 어떤 history 기록에도 Task ID가 나오지 않는 끝난 Task"를 경고한다.

## 8. 권한

- 기록은 그 정리·결정을 맡은 Task의 Agent가 쓴다. `.ai_project/` 아래라 Task의 `allowed_paths`에 넣지 않아도 범위 검사에 걸리지 않는다.
- 이미 쓴 기록은 고치지 않고 덧붙인다. 잘못된 내용은 "정정" 항목으로 날짜와 함께 추가한다.
- 기록 삭제는 Owner 승인이 필요하다. Owner가 자기 터미널에서 직접 지운다.

## 9. guard 보호

Agent 세션에서는 guard가 지난 기록을 지킨다.

| 대상 | Agent가 할 수 있는 것 |
|---|---|
| 오늘 만든 기록, `(작성 전)`이 남은 초안 | 자유롭게 고치기, 지우기 |
| 지난 기록 파일 | 덧붙이기만(기존 줄을 모두 그대로 두는 Edit·Write·apply_patch, `>>`, `tee -a`). 고치기, 덮어쓰기, `sed -i`, 지우기, 옮기기는 막는다 |
| 지난 기록 폴더, `history/` 폴더, 그 위 폴더 | `rm`, `mv`, `git rm`, `find -delete`, apply_patch Delete를 막는다 |
| 지난 기록 폴더 안의 새 파일, 새 기록 | 만들 수 있다 |
| `INDEX.md` | 고칠 수 있다(분류·요약 정리). `aiops history lint`가 목록을 검사한다 |

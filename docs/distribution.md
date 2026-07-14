# Distribution

작성일: 2026-07-13
상태: Draft

## 1. 목표

AI Agent Ops는 최종적으로 아래 방식으로 설치할 수 있게 한다.

```bash
brew install cschoi724/tap/ai-agent-ops
aiops version
aiops seed --adapter both --target ./YourProject
aiops doctor --target ./YourProject --strict
```

현재 단계에서는 Homebrew 배포를 바로 활성화하지 않고, release와 Formula가 요구하는 구조를 먼저 준비한다.

## 2. 설치 채널

| 채널 | 상태 | 용도 |
|---|---|---|
| 로컬 git checkout | 현재 지원 | 개발자/운영자가 직접 repo를 받아 사용 |
| 전역 symlink | 현재 지원 | Homebrew 전까지 `aiops`를 전역 명령처럼 사용 |
| Homebrew Formula | 준비 중 | 일반 사용자 설치 |
| 복사 설치 | 지원 | 외부 업데이트를 받지 않는 고정 snapshot |

License: MIT

## 3. 전역 명령 등록

Homebrew 전에는 로컬 checkout의 `bin/aiops`를 PATH 안에 symlink로 둔다.

예:

```bash
mkdir -p ~/.local/bin
ln -s /path/to/ai-agent-ops/bin/aiops ~/.local/bin/aiops
```

쉘 설정에 `~/.local/bin`이 없으면 추가한다.

```bash
export PATH="$HOME/.local/bin:$PATH"
```

확인:

```bash
aiops version
aiops update --check
```

`aiops`는 symlink로 실행되어도 실제 core 위치를 따라가야 한다. 따라서 전역 symlink를 쓰더라도 `.ai` seed 대상은 `/path/to/ai-agent-ops` core를 바라봐야 한다.

## 4. Release 구조

릴리스 전 확인 항목:

1. `VERSION` 값 갱신
2. `CHANGELOG.md` 갱신
3. `bin/aiops release-check --strict` 확인
4. `bin/aiops doctor --target <seeded test project> --strict` 확인
5. `bin/aiops update --check` 확인
6. license 결정과 `LICENSE` 파일 확인
7. git tag 생성: `vX.Y.Z`
8. GitHub release tarball SHA256 계산
9. `Formula/ai-agent-ops.rb`의 `url`, `sha256` 갱신
10. `bin/aiops release-check --strict` 재확인
11. Homebrew tap 저장소에 Formula 반영

권장 tag:

```text
v0.6.1
```

## 5. Homebrew Formula 초안

Formula 위치:

```text
Formula/ai-agent-ops.rb
```

Formula는 GitHub release tarball URL과 `sha256`으로 버전을 고정한다. 저장소가 private이면 tarball 접근이 실패하므로 public release 접근을 먼저 확인한다.

예상 설치 구조:

```text
$(brew --prefix)/bin/aiops
$(brew --prefix)/opt/ai-agent-ops/libexec/
```

대상 프로젝트 seed 결과:

```text
YourProject/.ai -> $(brew --prefix)/opt/ai-agent-ops/libexec
```

## 6. Update 흐름

현재 지원:

```bash
aiops update --check
aiops update
```

동작:

- git checkout core면 `git pull --ff-only`로 갱신한다.
- core에 local changes가 있으면 중단한다.
- packaged/copy 설치면 직접 수정하지 않고 Homebrew 또는 reseed 안내만 출력한다.

Homebrew 배포 이후 권장:

```bash
brew upgrade ai-agent-ops
aiops doctor --target ./YourProject --strict
```

업데이트 후에도 `.ai_project/`는 덮어쓰지 않는다. 프로젝트별 반영은 Ops Governance Role이 `.ai/policies/update_policy.md` 기준으로 점검한다.

## 7. Release Check

릴리스 전에는 아래 명령으로 배포 차단 항목을 확인한다.

```bash
aiops release-check
aiops release-check --strict
```

확인 항목:

- `VERSION` 형식
- `CHANGELOG.md`의 현재 버전 섹션
- 필수 문서와 adapter 템플릿 존재 여부
- Formula URL과 VERSION 일치 여부
- Formula tag/revision 또는 tarball SHA256 상태
- Formula Ruby 문법
- `LICENSE` 존재 여부
- git working tree clean 여부

`--strict`는 경고를 실패로 처리한다. 초기 public Homebrew 배포 전에는 반드시 strict 모드를 통과해야 한다.

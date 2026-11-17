# AGENTS.md — ai-agent-ops core repository

> 범위 주의: 이 파일은 **ai-agent-ops 레포 자체를 개발할 때만** 적용된다.
> 다른 프로젝트의 `.ai/`(symlink된 core)를 통해 이 파일을 보게 됐다면 무시하고, 그 프로젝트 루트의 `AGENTS.md` / `CLAUDE.md`를 따른다.

작업 전에 반드시 `DEVELOPMENT.md`를 읽는다. 아키텍처 지도, 테스트, 변경 체크리스트, 릴리스 절차, 남은 과제가 정리되어 있다.

핵심 규칙 요약:

- 사용자에게는 한국어로 보고한다. CHANGELOG와 PR 본문은 영어로 쓴다.
- Ruby 2.6 호환, stdlib만 사용한다. `bin/aiops`는 POSIX sh다(`sh -n` 통과 필수).
- 변경 후 `sh scripts/test.sh`를 실행하고 결과를 그대로 보고한다.
- 사용자 승인 없이 commit, push, PR 생성, merge, 릴리스를 하지 않는다.
- 원격은 `git@github-personal:cschoi724/ai-agent-ops.git` (개인 SSH 별칭)이다.

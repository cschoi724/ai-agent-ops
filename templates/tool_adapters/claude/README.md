# Claude Adapter

작성일: 2026-07-10  
상태: Draft vNext

## 1. 목적

이 폴더는 Claude 프로젝트에 선택적으로 추가할 지침 파일 템플릿을 제공한다.

## 2. 파일

| 파일 | 용도 |
|---|---|
| `CLAUDE.md` | Claude가 프로젝트에서 먼저 읽을 운영 지침 |

## 3. 적용 방식

대상 프로젝트 루트에서 아래 명령을 실행한다.

```text
aiops seed --adapter claude
```

Codex와 Claude를 함께 쓰려면 아래 명령을 사용한다.

```text
aiops seed --adapter both
```

기본 운영 기준은 `.ai/runtime/workflow.md`와 `.ai_project/` 문서를 따른다.

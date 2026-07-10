# Codex Adapter

작성일: 2026-06-29  
상태: Draft vNext

## 1. 목적

이 폴더는 Codex 프로젝트에 선택적으로 추가할 지침 파일 템플릿을 제공한다.

## 2. 파일

| 파일 | 용도 |
|---|---|
| `AGENTS.md` | Codex가 프로젝트에서 먼저 읽을 운영 지침 |

## 3. 적용 방식

사용자가 명시적으로 요청한 경우에만 대상 프로젝트 루트에 `AGENTS.md`를 생성한다.

기본 운영 기준은 `.ai/runtime/workflow.md`와 `.ai_project/` 문서를 따른다.

프로젝트 자체의 핵심 문서가 필요하면 `.ai/templates/project_docs/` 템플릿을 사용하고, 선택한 위치는 `.ai_project/source_of_truth.md`에 기록한다.

# Knowledge Policy

작성일: 2026-07-21  
상태: Draft vNext

## 1. 목적

이 문서는 `.ai_knowledge/`를 생성, 갱신, 검증할 때 지켜야 할 운영 정책을 정의한다.

## 2. Source Of Truth 규칙

- `.ai_knowledge/`는 요약과 연결을 위한 Wiki다.
- 코드, 공식 제품 문서, 기술 계약 문서, ADR, 사용자 승인 기록이 source of truth다.
- Wiki가 원본과 다르면 원본을 우선한다.
- 충돌을 발견한 Agent는 원본을 임의 수정하지 않고 `.ai_project/ops_issues.md`에 기록한다.

## 3. 갱신 권한

| Role | 가능 작업 |
|---|---|
| Direction Role | 제품 방향, 대상 사용자, 성공 기준 요약 갱신 |
| Lead Role | Task와 source of truth 연결, 결정 요약 갱신 |
| Execution Role | 구현 중 확인한 기술 사실 후보 기록 |
| Verification Role | Wiki와 원본 충돌, 검증 결과, 리스크 기록 |
| Ops Governance Role | Knowledge 구조와 정책 충돌 점검 |

## 4. 금지사항

- Wiki만 근거로 제품/기술 결정을 확정하지 않는다.
- 원본 문서에 없는 사실을 확정된 사실처럼 쓰지 않는다.
- 사용자 승인 없이 source of truth를 바꾸지 않는다.
- `.ai_knowledge/`를 Task source of truth의 유일한 기준으로 지정하지 않는다.

## 5. 갱신 기록

Knowledge 문서를 갱신하면 `.ai_knowledge/log.md`에 아래 형식으로 남긴다.

```text
날짜:
Agent / Role:
갱신 문서:
참조 원본:
변경 요약:
미확인 사항:
```

## 6. 검증 기준

Knowledge lint는 최소한 아래를 확인한다.

- `README.md`, `index.md`, `log.md`, `project_brief.md` 존재 여부
- Wiki 문서에 source reference가 있는지 여부
- open question이 source of truth 또는 Task와 연결되는지 여부

## 7. 변경 이력

| 날짜 | 변경 내용 |
|---|---|
| 2026-07-21 | `.ai_knowledge/` 운영 정책 초안 추가 |

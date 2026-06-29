# Handoff Templates

작성일: 2026-06-29  
상태: Draft v1  
범위: `.ai_project/handoffs/`에서 사용할 인수인계 템플릿

## 1. 목적

이 문서는 Agent 간 인수인계 문서의 템플릿을 정의한다.

실제 프로젝트별 인수인계 문서는 `.ai_project/handoffs/`에 생성한다. `.ai/templates/handoffs/`에는 진행 기록을 누적하지 않는다.

## 2. 파일명 규칙

```text
YYYY-MM-DD_[task-name]_[handoff-type].md
```

예시:

```text
2026-06-29_social-login_dev-request.md
2026-06-29_social-login_dev-report.md
2026-06-29_social-login_qa-report.md
2026-06-29_social-login_rework-request.md
```

## 3. 공통 메타데이터

모든 handoff 문서는 아래 항목을 포함한다.

```text
작성일:
작성 Agent:
대상 Task:
Workflow:
Active Agents:
Active Capabilities:
상태:
```

## 4. 템플릿 파일

| 파일 | 용도 |
|---|---|
| `pm_to_dev.md` | PM Agent가 Development Agent에게 작업을 넘길 때 |
| `dev_report.md` | Development Agent가 구현 완료를 보고할 때 |
| `qa_report.md` | QA Agent가 PM Agent에게 검증 결과를 보고할 때 |
| `rework_request.md` | QA Agent가 Development Agent에게 재작업을 요청할 때 |

## 5. PM to Development

```text
# Development Request

## 배경

## 작업 범위

## 제외 범위

## 구현 상세

## 검증 기준

## 완료 후 갱신할 프로젝트 문서

## QA Agent 확인 필요 항목

## 주의사항
```

## 6. Development to QA

```text
# Development Report

## 변경 파일

## 구현 내용

## 문서 갱신

## 검증 결과

## 실패하거나 생략한 검증

## 남은 리스크

## QA Agent 확인 필요 항목
```

## 7. QA to PM

```text
# QA Report

## QA 결과

## 확인 범위

## 확인 결과

## 발견 이슈

## 문서 일치성

## 검증 결과

## 잔여 리스크

## PM Agent 권장 조치
```

## 8. QA to Development

```text
# Rework Request

## 재작업이 필요한 이유

## 수정 범위

## 제외 범위

## 재검증 기준

## 완료 후 보고할 내용
```

## 9. 변경 이력

| 날짜 | 변경 내용 |
|---|---|
| 2026-06-29 | Handoff 템플릿 v1 작성 |

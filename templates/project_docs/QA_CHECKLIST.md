# QA Checklist

작성일: {{DATE}}  
프로젝트: {{PROJECT_NAME}}  
상태: Draft

## 1. 목적

이 문서는 QA Agent와 Development Agent가 공통으로 확인해야 할 검증 기준을 정의한다.

## 2. 기본 검증

| 항목 | 기준 | 결과 | 비고 |
|---|---|---|---|
| 빌드 | {{BUILD_COMMAND}} 성공 | Not Run | |
| 테스트 | {{TEST_COMMAND}} 성공 | Not Run | |
| 정적 검사 | {{LINT_COMMAND}} 성공 | Not Run | |
| 주요 흐름 | 핵심 사용자 흐름 정상 동작 | Not Run | |
| 로그/민감정보 | 민감정보 출력 없음 | Not Run | |

결과 값은 `PASS`, `PASS_WITH_RISK`, `FAIL`, `BLOCKED`, `NOT_RUN` 중 하나를 사용한다.

## 3. 기능별 체크리스트

| 기능 | 확인 항목 | 결과 | 증거 |
|---|---|---|---|
|  |  | NOT_RUN |  |

## 4. 회귀 확인

| 영역 | 확인 내용 | 결과 |
|---|---|---|
|  |  | NOT_RUN |

## 5. QA 결과 기록

```text
날짜:
대상 버전/커밋:
검증 범위:
결과:
주요 이슈:
남은 리스크:
```

## 6. 변경 이력

| 날짜 | 변경 내용 |
|---|---|
| {{DATE}} | QA 체크리스트 문서 초기화 |

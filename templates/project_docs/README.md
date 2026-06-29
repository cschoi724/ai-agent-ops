# Project Docs Templates

작성일: {{DATE}}  
상태: Draft

## 1. 목적

이 디렉토리는 새 프로젝트에 복사할 프로젝트 핵심 문서 템플릿을 제공한다.

`.ai/`는 Agent 운영 가이드북이고, `.ai_project/`는 Agent 협업 상태다. 아래 문서들은 제품과 개발 프로젝트 자체의 source of truth로 사용한다.

## 2. 권장 문서

| 템플릿 | 역할 |
|---|---|
| `CURRENT_STATUS.md` | 현재 진행 상태와 최신 기준 |
| `IMPLEMENTATION_PLAN.md` | 단계별 구현 계획과 완료 조건 |
| `ARCHITECTURE.md` | 시스템 구조와 모듈 경계 |
| `DECISIONS.md` | 제품/기술/프로젝트 결정 기록 |
| `CHANGELOG.md` | 사용자 영향과 개발 변경 이력 |
| `QA_CHECKLIST.md` | QA 기준과 회귀 확인 목록 |
| `PENDING_QUESTIONS.md` | 사용자/정책/외부 확인 필요 항목 |
| `UNIMPLEMENTED_FEATURES.md` | 미구현, 보류, 부분 구현 기능 목록 |

## 3. 적용 위치

프로젝트 형태에 맞춰 문서 위치를 선택한다.

```text
docs/
  CURRENT_STATUS.md
  IMPLEMENTATION_PLAN.md
  ARCHITECTURE.md
  DECISIONS.md
  CHANGELOG.md
  QA_CHECKLIST.md
  PENDING_QUESTIONS.md
  UNIMPLEMENTED_FEATURES.md
```

플랫폼별 프로젝트라면 `ios/App/Docs/`, `android/App/Docs/`처럼 플랫폼 내부 문서 폴더에 둘 수 있다.

선택한 위치는 `.ai_project/source_of_truth.md`에 반드시 기록한다.

## 4. 운영 원칙

- 프로젝트 상태 판단은 이 문서들과 실제 코드 상태를 함께 확인한다.
- 구현 변경 후 관련 문서를 갱신한다.
- 사용자 결정이 필요한 항목은 `PENDING_QUESTIONS.md`에 남긴다.
- 완료/보류/제외 범위는 `IMPLEMENTATION_PLAN.md`와 `UNIMPLEMENTED_FEATURES.md`에 분리해 기록한다.

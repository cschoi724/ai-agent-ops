# 사용자 시각화 다음 단계 논의 메모

상태: 논의 메모
대상: 프로젝트 상태 안정화 기반 배포 이후

이 문서는 AI Ops의 사용자용 시각화 방향을 다음 단계에서 논의하기 위해 남기는 메모다. 아직 구체적인 구현 계획이 아니다.

현재 우선순위는 프로젝트 상태를 더 정확하고 안정적으로 읽을 수 있는 기반을 만드는 것이다. Dashboard나 시각화는 그 기반이 준비된 뒤 별도 범위로 확정한다.

## 시각화를 나중에 하는 이유

Dashboard는 신뢰할 수 있는 상태 데이터를 기반으로 해야 의미가 있다.

먼저 아래 기반이 필요하다.

- 정규화된 project inspect 출력
- 문서 간 관계 검증
- canonical status ref 확인
- Task 상태별 필수 조건
- Agent context 출력
- Project health 요약

이 기반이 안정화되면, Dashboard는 별도의 수동 문서가 아니라 같은 상태 데이터를 사람이 보기 쉽게 표현하는 계층이 될 수 있다.

## 논의한 방향

사용자용 시각화는 아래 질문에 쉽게 답할 수 있어야 한다.

- 현재 프로젝트는 어떤 운영 모드인가?
- 어떤 Role이 활성화되어 있는가?
- 어떤 Agent 또는 Role이 어떤 Task를 맡고 있는가?
- 현재 workflow 단계가 실제로 무슨 의미인가?
- 무엇이 blocked, stale, 승인 대기 상태인가?
- AI Ops 업데이트 또는 migration 이후 무엇이 바뀌었는가?
- 사용자는 다음에 무엇을 하면 되는가?

중요한 점은 technical field를 그대로 보여주는 것이 아니다. AI Ops 용어를 실제 프로젝트 운영 의미로 번역해서 보여줘야 한다.

## 다음 단계 후보

추후 검토할 수 있는 후보는 아래와 같다.

- Project overview dashboard
- Task board 상태 보기
- Role / handoff map
- Workflow state map
- Project health view
- Migration impact view
- "이제 무엇을 해야 하나?" 안내
- 용어 설명 패널

이 목록은 후보일 뿐이며, 실제 구현 범위는 다시 확정해야 한다.

## 출력 방식 후보

나중에 다시 선택할 수 있는 방식:

- `.ai_project/` 아래 Markdown dashboard 생성
- 로컬 static HTML dashboard 생성
- JSON-first 출력 후 외부 도구에서 시각화
- 우선 terminal summary만 강화

아직 어떤 방식도 확정하지 않는다.

## 중요한 제약

시각화 결과물은 새로운 source of truth가 되면 안 된다.

Dashboard는 project state foundation에서 생성되는 파생 결과물이어야 한다. 언제든 다시 만들 수 있어야 하고, 수동으로 고쳐야 하는 운영 문서가 되어서는 안 된다.

## 다음에 다시 결정할 질문

- 첫 Dashboard는 Markdown이 좋은가, HTML이 좋은가?
- 생성된 Dashboard 파일을 프로젝트 저장소에 커밋해야 하는가?
- 한글 중심 설명을 기본으로 둘 것인가?
- 초보자에게 어느 정도까지 세부 정보를 숨길 것인가?
- update와 migration 영향도는 별도 화면으로 보여줄 것인가?

이 질문들은 프로젝트 상태 안정화 기반 작업이 끝난 뒤 다시 논의한다.

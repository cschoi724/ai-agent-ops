---
name: aiops-next
description: 지금 어떤 일감을 누가 진행해야 하는지 알려준다. 사용자가 "다음에 뭐 해?", "다음 할 일", "이 Task 시작해도 돼?"처럼 물을 때 사용한다.
---

# AI Ops 다음 할 일

읽기 전용 명령만 사용한다.

1. `aiops project snapshot --json`으로 활성 Task와 상태를 확인한다.
2. 특정 Task가 있으면 `aiops project context --role ROLE --task TASK_ID --json`과 `aiops task accept TASK_ID --check` 또는 `aiops task advance TASK_ID --check`로 진행 가능 여부를 확인한다.
3. 어떤 Role 세션을 열어야 할지 불명확하면 `aiops session-guide`를 확인한다.

## 사용자에게 보고하는 형식
- 다음 일감: Task ID + 제목 + workflow + 현재 상태
- 담당: Agent 이름 / Role과 그렇게 판단한 근거
- 진행 가능 여부: 가능 / 불가와 이유
- 사용자 결정이 필요한 항목

Task 이름만 말하지 말고 ID, 상태, 담당을 함께 말한다.

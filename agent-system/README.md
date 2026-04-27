# Agent System

이 디렉터리는 `MD 파일로 정의한 에이전트`와 `파일 기반 하네스`를 함께 관리한다.

목표:

- 에이전트 역할을 코드가 아니라 문서로 먼저 정의
- 태스크를 JSON으로 관리
- 하네스가 태스크 상태를 관리하고 다음 에이전트에게 작업 패킷을 전달
- 나중에 실제 LLM 어댑터를 붙여도 구조를 바꾸지 않도록 설계

## 구조

- `agents/`: 역할 정의 문서
- `tasks/`: 실행할 태스크 정의
- `harness/`: 실행 스크립트
- `runs/`: 실행 상태와 산출물

## 기본 흐름

1. 태스크 JSON을 작성한다.
2. `init`으로 run을 생성한다.
3. `dispatch`가 현재 단계의 에이전트에게 작업 패킷을 만든다.
4. 에이전트가 결과를 작성한다.
5. `submit`이 결과를 반영하고 다음 단계로 넘긴다.
6. 모든 단계가 끝나면 run이 완료된다.

## 단계 모델

기본 단계는 아래 3개다.

1. `planner`
2. `builder`
3. `reviewer`

필요하면 이후 `operator`, `analyst`, `qa` 같은 역할을 추가할 수 있다.

## 사용 예시

```powershell
./agent-system/harness/run-harness.ps1 init `
  -TaskFile ./agent-system/tasks/moneyflow-bootstrap.json `
  -RunId demo-001

./agent-system/harness/run-harness.ps1 dispatch -RunId demo-001
./agent-system/harness/run-harness.ps1 status -RunId demo-001

./agent-system/harness/run-harness.ps1 submit `
  -RunId demo-001 `
  -Agent planner `
  -OutputFile ./some-output.md
```

주의:

- 같은 `RunId`에 대해 `dispatch`, `submit`, `status`를 동시에 병렬 호출하지 않는 편이 안전하다.
- 현재 버전은 단일 상태 파일을 쓰는 최소 하네스이므로 제어 명령은 직렬로 실행하는 것을 전제로 한다.

## 실제 멀티 에이전트로 확장하는 법

현재 하네스는 `에이전트 역할`, `태스크`, `상태머신`, `산출물 기록`에 집중한다.

실제 자동화를 붙일 때는 아래 둘 중 하나로 확장하면 된다.

- Codex/CUA 기반 워커가 각 agent packet을 읽고 자동 응답
- 외부 API 워커가 `mailbox`를 폴링하고 결과를 `submit`

즉 지금 만든 것은 장난감이 아니라, 나중에 실제 자동 에이전트 런타임을 붙이기 위한 제어면이다.

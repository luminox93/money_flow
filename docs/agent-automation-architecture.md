# Agent Automation Architecture

이 문서는 이 저장소의 문서형 멀티 에이전트 하네스를 자동 순환 구조로 확장하는 설계 근거를 정리한다.

## 목표

- 사용자의 아이디어를 입력으로 받는다.
- `기획자 -> 디자이너 -> 개발자 -> 리뷰어` 순서로 자동 전달한다.
- 리뷰어가 반려하면 개발 단계로 되돌린다.
- 각 단계 산출물을 다음 단계 입력 컨텍스트로 넘긴다.
- 향후 실제 LLM 워커를 붙여도 상태 관리 구조를 바꾸지 않도록 한다.

## 참고한 패턴

### 1. OpenAI Agents SDK: Orchestrator + Specialists

OpenAI Agents SDK 예제는 `orchestrator`가 전문 에이전트를 도구처럼 호출하고, 마지막에 별도 정리 에이전트가 결과를 합치는 패턴을 보여준다. 이 저장소에서는 그 아이디어를 파일 기반 하네스에 맞춰 `packet dispatch -> specialist output -> next stage` 흐름으로 바꾼다.

- 예제: `agents_as_tools.py`
- 링크: https://github.com/openai/openai-agents-python/blob/main/examples/agent_patterns/agents_as_tools.py

### 2. CrewAI: Sequential / Hierarchical Process

CrewAI 공식 문서는 작업을 순차적으로 흘려보내는 `Sequential`과 관리자가 위임하는 `Hierarchical`를 분리한다. 여기서는 아이디어를 하나의 선형 설계 파이프라인으로 처리하므로 우선 `Sequential`에 가깝게 구성하고, 리뷰 반려 루프만 추가한다.

- 링크: https://docs.crewai.com/en/learn/sequential-process
- 링크: https://docs.crewai.com/en/concepts/processes

### 3. LangGraph / LangChain: Supervisor + Subagents

LangChain과 LangGraph 문서는 중앙 supervisor가 전문 subagent를 호출하는 패턴과, 반복 가능한 상태 그래프를 강조한다. 특히 supervisor 패턴은 전문 역할을 명확히 분리하고, 이전 대화 전체를 모든 역할에 중복 주입하지 않는 것이 장점이다.

- 링크: https://docs.langchain.com/oss/python/langchain/multi-agent/subagents
- 링크: https://docs.langchain.com/oss/python/langchain/supervisor
- 링크: https://www.langchain.com/blog/langgraph-multi-agent-workflows

## 이 저장소에서 채택한 방식

### 선택: 파일 기반 Supervisor Harness

실제 모델 런타임이 아직 고정되지 않았으므로, 하네스는 아래 역할만 책임진다.

- 현재 단계 결정
- packet 생성
- mailbox 배달
- 결과 수신
- 승인/반려 상태 전이
- 실행 이력 기록

실제 LLM 호출기는 나중에 붙인다. 이 구조는 프레임워크 종속성이 적고, 로컬/원격 환경 모두에서 동일하게 동작시킬 수 있다.

## 단계 정의

1. `product-planner`
2. `designer`
3. `developer`
4. `reviewer`

### 단계별 산출물

- `product-planner`: MVP 요구사항 명세
- `designer`: 화면 구조와 UX 흐름
- `developer`: DB/워크플로우/구현 계획
- `reviewer`: `approve` 또는 `revise`

## 상태 전이

정상 흐름:

`plan -> design -> build -> review -> complete`

반려 흐름:

`review(revise) -> build -> review`

이 루프는 여러 번 반복될 수 있어야 한다.

## packet 설계 원칙

각 packet에는 아래가 들어간다.

- 현재 단계
- 목표
- 제약
- 참고 입력 파일
- 이전 단계 산출물 경로
- 현재 단계 완료 조건

이 방식은 LangChain subagent 패턴의 "컨텍스트 분리" 장점을 파일 기반으로 흉내 내는 것이다.

## reviewer 판정 규칙

리뷰어 산출물에는 반드시 아래 한 줄이 포함되어야 한다.

`Verdict: approve`

또는

`Verdict: revise`

하네스는 이 값을 파싱해서 다음 상태를 결정한다.

## 왜 이 구조가 맞는가

- 단일 에이전트보다 역할 책임이 명확하다.
- 각 산출물을 문서로 남겨 재현성이 높다.
- 실패 시 어느 단계에서 품질이 무너졌는지 추적이 쉽다.
- `n8n` 프로젝트처럼 요구사항, 화면, 데이터 흐름이 모두 필요한 작업에 잘 맞는다.

## 다음 확장

1. mailbox를 폴링하는 실제 LLM 워커 추가
2. reviewer가 세부 코멘트를 남기면 developer packet에 자동 주입
3. GitHub Actions나 원격 runner에서 같은 하네스 실행
4. 태스크 템플릿을 `idea -> mvp`, `mvp -> workflow`, `workflow -> implementation`으로 세분화

# 아키텍처

## 목표

- 수동 입력, CSV, 향후 API 연동으로 금융 데이터를 받아온다.
- 원본 데이터와 정규화 데이터를 분리 저장한다.
- 일별 현금흐름과 잔액 스냅샷을 만든다.
- 휴대폰에서도 접근 가능한 운영 구성을 유지한다.

## 권장 흐름

1. `raw_transactions`에 원본 수집
2. `normalized_transactions`에 카테고리/유형 정규화
3. `recurring_transactions`를 기준으로 미래 고정지출 생성
4. 배치 워크플로우가 `daily_cashflow` 업데이트
5. 대시보드 레이어가 `daily_cashflow`, `account_balance_snapshots` 조회

## n8n 워크플로우 분리

### 1. ingestion workflow

- 트리거: 수동 실행, 파일 업로드, 이메일, 클라우드 스토리지
- 역할: 카드/은행 CSV 파싱 후 `raw_transactions` 적재

### 2. normalization workflow

- 트리거: 신규 `raw_transactions` 감지 또는 ingestion 후 호출
- 역할:
  - 입출금/이체 분류
  - 카테고리 매핑
  - 중복 제거
  - `normalized_transactions` 적재

### 3. recurring expansion workflow

- 트리거: 하루 1회
- 역할: 정기 지출/수입을 기준으로 앞으로의 예상 흐름 생성

### 4. daily snapshot workflow

- 트리거: 하루 1회 새벽
- 역할:
  - 일별 순유입 계산
  - 자산 잔액 스냅샷 결합
  - `daily_cashflow` 업데이트

### 5. notification workflow

- 트리거: 스냅샷 완료 후
- 역할: Telegram, Slack, 이메일로 요약 전송

## 대시보드 방향

1차는 `n8n` 자체를 오케스트레이션 계층으로 두고, 조회는 DB 기반으로 분리하는 편이 낫다.

- 빠른 MVP: `Metabase` 또는 `Grafana` 연결
- 커스텀 UI: `Next.js` 또는 `React` 대시보드 추가

`n8n`을 시각화 UI의 중심으로 삼기보다는 데이터 파이프라인의 중심으로 두는 편이 유지보수에 유리하다.

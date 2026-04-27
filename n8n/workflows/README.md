# n8n 워크플로우 가이드

이 디렉터리에는 실제 import 가능한 워크플로우 JSON을 점진적으로 추가한다.

처음에는 아래 3개부터 만드는 것이 맞다.

## 1. CSV 수집 워크플로우

- 시작 노드: `Manual Trigger` 또는 `Webhook`
- 파일 입력: 카드사 CSV 업로드
- 처리:
  - 헤더 정리
  - 금액/일자 파싱
  - `raw_transactions` upsert

## 2. 정규화 워크플로우

- 시작 노드: `Execute Workflow` 또는 `Cron`
- 처리:
  - 결제 수단 판별
  - merchant/category 매핑
  - `normalized_transactions` insert

## 3. 일별 스냅샷 워크플로우

- 시작 노드: `Cron` 매일 06:00
- 처리:
  - 당일 수입/지출/이체 집계
  - 전일 잔액과 합산
  - `daily_cashflow` 업데이트

## 추천 노드

- `Postgres`
- `Schedule Trigger`
- `Webhook`
- `Code`
- `IF`
- `Execute Workflow`

## 구현 순서

1. 수동 CSV 업로드로 원본 적재
2. 카테고리 정규화
3. 일별 집계
4. 알림 전송
5. 외부 서비스 연동 자동화

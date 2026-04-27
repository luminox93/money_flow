# money_flow

현재 재산, 정기 지출, 카드 사용내역을 수집해 일별 현금흐름을 시각화하는 `n8n` 기반 프로젝트의 기본 세팅이다.

기본 목표:

- 자산 계좌, 카드, 정기지출 데이터를 한 곳으로 적재
- 매일 기준의 현금흐름 스냅샷 생성
- 외부 네트워크에서 휴대폰으로 접속 가능한 운영 환경 구성
- 이후 `n8n` 워크플로우와 대시보드 레이어를 붙이기 쉬운 구조 유지

## 구성

- `n8n`: 수집/정규화/집계 워크플로우 실행
- `Postgres`: 원본 거래내역, 정규화 거래, 일별 현금흐름 저장
- `Caddy`: HTTPS 종단 및 리버스 프록시
- `cloudflared`(선택): 집이나 로컬 머신에서 직접 포트 개방 없이 외부 공개

## 디렉터리

- `docker-compose.yml`: 기본 실행 스택
- `.env.example`: 환경 변수 샘플
- `infra/caddy/Caddyfile`: 외부 공개용 프록시 설정
- `sql/init/001_money_flow_schema.sql`: 초기 스키마
- `docs/architecture.md`: 권장 아키텍처와 데이터 흐름
- `n8n/workflows/README.md`: 첫 워크플로우 설계 가이드

## 빠른 시작

1. `.env.example`을 복사해 `.env` 생성
2. `N8N_HOST`, `N8N_EDITOR_BASE_URL`, `WEBHOOK_URL`, `POSTGRES_PASSWORD` 수정
3. 도메인이 있으면 DNS를 서버 IP로 연결
4. Docker 실행 후 스택 기동

```powershell
Copy-Item .env.example .env
docker compose up -d
```

기본 접속:

- `https://{N8N_HOST}`: `n8n` 편집기

## 외부 접속 방식

### 1. 서버/VPS 배포

권장 방식이다.

- 공인 IP가 있는 서버에 배포
- 도메인 DNS를 서버로 연결
- `Caddy`가 자동으로 HTTPS 인증서 발급

### 2. 로컬 PC + Cloudflare Tunnel

로컬 머신에서 실행하되 휴대폰으로 외부 접속하려면 이 방식이 가장 단순하다.

- Cloudflare Zero Trust에서 Tunnel 생성
- `CLOUDFLARE_TUNNEL_TOKEN` 발급
- `docker compose --profile tunnel up -d`

이 경우 포트 포워딩 없이도 외부 접속이 가능하다.

## 추천 1차 워크플로우

1. 수동/파일 업로드로 카드 사용내역 CSV 적재
2. 정기 지출 마스터 테이블 등록
3. 자산 잔액 스냅샷 입력
4. 매일 새벽 일별 현금흐름 집계 실행
5. 집계 결과를 대시보드용 API/테이블로 노출

## 다음 단계

- 카드사/은행별 CSV 파서 워크플로우 추가
- Telegram 또는 Slack으로 일일 요약 발송
- 월간 예산 대비 분석
- 별도 대시보드 레이어 추가
  - 빠르게 가려면 `Metabase` 또는 `Grafana`
  - 커스텀 UI가 필요하면 `Next.js` 프론트엔드 추가

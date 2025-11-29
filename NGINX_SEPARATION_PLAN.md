# Nginx 분리 계획서

## 개요

`basketball-scoreboard` 프로젝트에서 Nginx를 분리하여 독립적인 리버스 프록시 서버로 구성합니다.
이를 통해 여러 도메인(`basketball-scoreboard.duckdns.org`, `commuzz.duckdns.org`)을 중앙에서 관리합니다.

**실행 서버:** `yongk.duckdns.org` (SSH 접속)

## 현재 서버 상태 (2024-11-29 확인)

### 실행 중인 컨테이너
| 컨테이너 | 이미지 | 상태 | 포트 |
|----------|--------|------|------|
| basketball-nginx | nginx:alpine | Up 6 days | 80, 443 |
| basketball-frontend | basketball-scoreboard-frontend | Up 6 days | - |
| basketball-backend | basketball-scoreboard-backend | Up 6 days (unhealthy) | 3000 |
| basketball-certbot | basketball-scoreboard-certbot | Exited | - |

### 네트워크
- `basketball-scoreboard_basketball-network` (bridge)

### 볼륨
- `basketball-scoreboard_frontend-build` (프론트엔드 빌드 파일)

## 현재 구조

```
~/workspace/basketball-scoreboard/
├── docker-compose.yml      # nginx, certbot 포함
├── nginx.conf              # basketball 전용 설정
├── certbot/
│   └── conf/               # SSL 인증서
└── ...
```

**문제점:**
- Nginx가 basketball 프로젝트에 종속됨
- 새 도메인 추가 시 basketball 프로젝트 수정 필요
- 여러 프로젝트에서 80/443 포트 충돌

## 목표 구조

```
nginx-proxy-yongk/          # 새로운 중앙 Nginx 프로젝트
├── docker-compose.yml
├── nginx.conf              # 모든 도메인 설정
├── certbot/
│   ├── Dockerfile
│   └── conf/               # 모든 SSL 인증서
└── sites/                  # 도메인별 설정 (선택사항)

basketball-scoreboard/      # Nginx 제거됨
├── docker-compose.yml      # backend, frontend만 포함
└── ...

commuzz/                    # 추후 추가될 프로젝트
├── docker-compose.yml
└── ...
```

## 지원 도메인

| 도메인 | 용도 | 상태 |
|--------|------|------|
| basketball-scoreboard.duckdns.org | 농구 스코어보드 | 기존 |
| commuzz.duckdns.org | Commuzz 서비스 | 신규 추가 예정 |

---

## 서버 실행 계획 (yongk.duckdns.org)

> **서버 중단 예상 시간:** 약 1-2분

### 1단계: nginx-proxy-yongk 프로젝트 배포 (로컬 완료 ✅)

**로컬에서 완료된 작업:**
- `docker-compose.yml` 생성
- `nginx.conf` 생성 (두 도메인 지원)
- `certbot/` 디렉토리 및 Dockerfile 생성

**서버로 배포:**
```bash
# 로컬에서 실행
scp -r ~/workspace/nginx-proxy-yongk yongk.duckdns.org:~/workspace/
```

### 2단계: 공유 Docker Network 생성 (서버)

```bash
ssh yongk.duckdns.org
docker network create shared-network
```

### 3단계: 기존 인증서 마이그레이션 (서버)

```bash
# SSL 인증서 복사
cp -r ~/workspace/basketball-scoreboard/certbot/conf ~/workspace/nginx-proxy-yongk/certbot/

# DuckDNS 토큰 복사
cp ~/workspace/basketball-scoreboard/certbot/duckdns.ini ~/workspace/nginx-proxy-yongk/certbot/
mkdir -p ~/workspace/nginx-proxy-yongk/certbot/conf/.secrets
cp ~/workspace/nginx-proxy-yongk/certbot/duckdns.ini ~/workspace/nginx-proxy-yongk/certbot/conf/.secrets/
```

### 4단계: basketball-scoreboard docker-compose.yml 수정 (서버)

**변경 사항:**
- `nginx` 서비스 제거
- `certbot` 서비스 제거
- 네트워크를 `shared-network` (external)로 변경

```bash
# 수정된 docker-compose.yml 배포 (로컬에서)
scp ~/workspace/basketball-scoreboard/docker-compose.yml yongk.duckdns.org:~/workspace/basketball-scoreboard/
```

### 5단계: 서비스 전환 (서버) ⚠️ 서비스 중단 구간

```bash
# 1. 기존 서비스 중지 (모든 컨테이너 정지)
cd ~/workspace/basketball-scoreboard
docker-compose down

# 2. 공유 네트워크가 생성되었는지 확인
docker network ls | grep shared-network

# 3. basketball-scoreboard 재시작 (nginx 없이)
docker-compose up -d

# 4. nginx-proxy 시작
cd ~/workspace/nginx-proxy-yongk
docker-compose up -d

# 5. 상태 확인
docker ps
```

### 6단계: 검증

```bash
# 컨테이너 상태 확인
docker ps

# Nginx 로그 확인
docker logs nginx-proxy

# 외부에서 접속 테스트
curl -I https://basketball-scoreboard.duckdns.org
```

- [ ] https://basketball-scoreboard.duckdns.org 접속 확인
- [ ] SSL 인증서 유효성 확인
- [ ] API 동작 확인 (/games, /players)

### 7단계: commuzz.duckdns.org SSL 인증서 발급 (추후)

```bash
docker exec -it nginx-certbot certbot certonly \
  --dns-duckdns \
  -d commuzz.duckdns.org \
  --agree-tos \
  --email your@email.com
```

---

## 빠른 실행 스크립트

서버에서 한 번에 실행할 수 있는 스크립트:

```bash
#!/bin/bash
set -e

echo "=== 1. 공유 네트워크 생성 ==="
docker network create shared-network || true

echo "=== 2. 인증서 마이그레이션 ==="
cp -r ~/workspace/basketball-scoreboard/certbot/conf ~/workspace/nginx-proxy-yongk/certbot/
cp ~/workspace/basketball-scoreboard/certbot/duckdns.ini ~/workspace/nginx-proxy-yongk/certbot/
mkdir -p ~/workspace/nginx-proxy-yongk/certbot/conf/.secrets
cp ~/workspace/nginx-proxy-yongk/certbot/duckdns.ini ~/workspace/nginx-proxy-yongk/certbot/conf/.secrets/

echo "=== 3. 기존 서비스 중지 ==="
cd ~/workspace/basketball-scoreboard
docker-compose down

echo "=== 4. basketball-scoreboard 재시작 ==="
docker-compose up -d

echo "=== 5. nginx-proxy 시작 ==="
cd ~/workspace/nginx-proxy-yongk
docker-compose up -d

echo "=== 6. 상태 확인 ==="
docker ps

echo "=== 완료! ==="
```

---

## 네트워크 구성도

```
                    ┌─────────────────────────────────────────┐
                    │           shared-network                │
                    │                                         │
   Internet         │  ┌─────────────┐                        │
       │            │  │   nginx     │                        │
       │            │  │   :80/:443  │                        │
       ▼            │  └──────┬──────┘                        │
   ┌───────┐        │         │                               │
   │ :80   │◄───────┼─────────┤                               │
   │ :443  │        │         │                               │
   └───────┘        │         ▼                               │
                    │  ┌──────────────┐    ┌──────────────┐   │
                    │  │ basketball-  │    │  commuzz-    │   │
                    │  │ backend:3000 │    │  backend     │   │
                    │  └──────────────┘    └──────────────┘   │
                    │                                         │
                    │  ┌──────────────┐    ┌──────────────┐   │
                    │  │ basketball-  │    │  commuzz-    │   │
                    │  │ frontend     │    │  frontend    │   │
                    │  └──────────────┘    └──────────────┘   │
                    │                                         │
                    └─────────────────────────────────────────┘
```

## 롤백 방법

문제 발생 시 기존 상태로 복구:

```bash
# 1. nginx-proxy 중지
cd ~/workspace/nginx-proxy-yongk
docker-compose down

# 2. basketball-scoreboard의 docker-compose.yml 원복 (git checkout)
cd ~/workspace/basketball-scoreboard
git checkout docker-compose.yml

# 3. 기존 방식으로 재시작
docker-compose up -d
```

---

## 파일 변경 요약

| 파일 | 작업 |
|------|------|
| `nginx-proxy-yongk/docker-compose.yml` | 신규 생성 |
| `nginx-proxy-yongk/nginx.conf` | 신규 생성 |
| `nginx-proxy-yongk/certbot/Dockerfile` | 복사 |
| `basketball-scoreboard/docker-compose.yml` | nginx, certbot 제거 |
| `basketball-scoreboard/nginx.conf` | 삭제 가능 (백업 권장) |

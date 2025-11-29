# Nginx 분리 완료 보고서

## 개요

`basketball-scoreboard` 프로젝트에서 Nginx를 분리하여 독립적인 리버스 프록시 서버로 구성했습니다.
이를 통해 여러 도메인(`basketball-scoreboard.duckdns.org`, `commuzz.duckdns.org`)을 중앙에서 관리합니다.

**실행 서버:** `yongk.duckdns.org` (SSH 접속)
**완료일:** 2025-11-29

## 현재 서버 상태

### 실행 중인 컨테이너
| 컨테이너 | 이미지 | 역할 | 포트 |
|----------|--------|------|------|
| nginx-proxy | nginx:alpine | 리버스 프록시 | 80, 443 |
| nginx-certbot | nginx-proxy-yongk-certbot | SSL 인증서 갱신 | - |
| basketball-backend | basketball-scoreboard-backend | API 서버 | 3000 (internal) |
| basketball-frontend | basketball-scoreboard-frontend | 정적 파일 빌드 | - |

### 네트워크
- `shared-network` (external, bridge)

### 볼륨
| 볼륨 | 용도 |
|------|------|
| `basketball-scoreboard_frontend-build` | 프론트엔드 빌드 파일 |
| `basketball-scoreboard_uploads` | 플레이어 사진 업로드 |

## 현재 구조

```
nginx-proxy-yongk/              # 중앙 Nginx 프록시
├── docker-compose.yml
├── nginx.conf                  # 모든 도메인 설정
├── certbot/
│   ├── Dockerfile
│   ├── duckdns.ini
│   └── conf/                   # SSL 인증서
└── NGINX_SEPARATION_PLAN.md

basketball-scoreboard/          # Nginx 제거됨
├── docker-compose.yml          # backend, frontend만 포함
├── nginx.conf                  # (사용 안함, 백업용)
└── ...
```

## 지원 도메인

| 도메인 | 용도 | 상태 |
|--------|------|------|
| basketball-scoreboard.duckdns.org | 농구 스코어보드 | ✅ 운영 중 |
| commuzz.duckdns.org | Commuzz 서비스 | 🔜 추가 예정 |

---

## 완료된 작업 내역

### 1단계: nginx-proxy-yongk 프로젝트 생성 ✅

**로컬에서 완료:**
- `docker-compose.yml` 생성
- `nginx.conf` 생성 (API prefix `/api/` 지원, uploads 경로 포함)
- `certbot/` 디렉토리 및 Dockerfile 생성

**서버 배포:**
```bash
cd ~/workspace
git clone git@github.com:tturbs/nginx-proxy-yongk.git
```

### 2단계: 공유 Docker Network 생성 ✅

```bash
docker network create shared-network
```

### 3단계: 기존 인증서 마이그레이션 ✅

```bash
# SSL 인증서 복사 (sudo 필요)
sudo cp -r ~/workspace/basketball-scoreboard/certbot/conf ~/workspace/nginx-proxy-yongk/certbot/
sudo chown -R $USER:$USER ~/workspace/nginx-proxy-yongk/certbot/conf

# DuckDNS 토큰 복사
cp ~/workspace/basketball-scoreboard/certbot/duckdns.ini ~/workspace/nginx-proxy-yongk/certbot/
mkdir -p ~/workspace/nginx-proxy-yongk/certbot/conf/.secrets
cp ~/workspace/nginx-proxy-yongk/certbot/duckdns.ini ~/workspace/nginx-proxy-yongk/certbot/conf/.secrets/
```

### 4단계: basketball-scoreboard docker-compose.yml 수정 ✅

**변경 사항:**
- `nginx` 서비스 제거
- `certbot` 서비스 제거
- 네트워크를 `shared-network` (external)로 변경
- `uploads` 볼륨 유지

**배포 방법:**
```bash
# 로컬에서 수정 후 push
git add docker-compose.yml
git commit -m "refactor: separate nginx into external proxy project"
git push

# 서버에서 pull
ssh yongk.duckdns.org
cd ~/workspace/basketball-scoreboard
git checkout master
git pull
```

### 5단계: 서비스 전환 ✅

```bash
# 1. 기존 서비스 중지
cd ~/workspace/basketball-scoreboard
docker-compose down

# 2. 기존 nginx/certbot 컨테이너 제거
docker stop basketball-nginx basketball-certbot
docker rm basketball-nginx basketball-certbot

# 3. basketball-scoreboard 재시작 (nginx 없이)
docker-compose up -d

# 4. nginx-proxy 시작
cd ~/workspace/nginx-proxy-yongk
docker-compose up -d
```

### 6단계: 검증 ✅

```bash
# 컨테이너 상태 확인
docker ps

# Nginx 로그 확인
docker logs nginx-proxy

# 외부에서 접속 테스트
curl -I https://basketball-scoreboard.duckdns.org
curl -s https://basketball-scoreboard.duckdns.org/api/games | head
```

**검증 결과:**
- [x] https://basketball-scoreboard.duckdns.org 접속 확인 (HTTP/2 200)
- [x] SSL 인증서 유효성 확인
- [x] API 동작 확인 (/api/games, /api/players)

---

## 새 도메인 추가 방법 (commuzz.duckdns.org)

### 1. SSL 인증서 발급

```bash
docker exec -it nginx-certbot certbot certonly \
  --dns-duckdns \
  -d commuzz.duckdns.org \
  --agree-tos \
  --email your@email.com
```

### 2. nginx.conf 수정

`nginx.conf`에서 commuzz 섹션 주석 해제 및 설정

### 3. docker-compose.yml 수정

필요한 볼륨 추가 (예: commuzz-frontend)

### 4. Nginx 재시작

```bash
docker-compose restart nginx
```

---

## 네트워크 구성도

```
                    ┌─────────────────────────────────────────┐
                    │           shared-network                │
                    │                                         │
   Internet         │  ┌─────────────┐                        │
       │            │  │ nginx-proxy │                        │
       │            │  │  :80/:443   │                        │
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

# 2. basketball-scoreboard의 docker-compose.yml 원복
cd ~/workspace/basketball-scoreboard
git checkout HEAD~1 -- docker-compose.yml

# 3. 기존 방식으로 재시작
docker-compose up -d
```

---

## 파일 변경 요약

| 파일 | 작업 |
|------|------|
| `nginx-proxy-yongk/docker-compose.yml` | 신규 생성 |
| `nginx-proxy-yongk/nginx.conf` | 신규 생성 |
| `nginx-proxy-yongk/certbot/Dockerfile` | 신규 생성 |
| `basketball-scoreboard/docker-compose.yml` | nginx, certbot 제거 |
| `basketball-scoreboard/nginx.conf` | 사용 안함 (백업용) |

## 관련 커밋

- **basketball-scoreboard:** `refactor: separate nginx into external proxy project`
- **nginx-proxy-yongk:** `feat: add uploads volume and update nginx config`

# 배포·잔여 작업 체크리스트 (분신)

Phase 1 **A~C** 이후 실행 트랙. 작업 단위를 하나씩 처리한다.
권위 문서: [`roadmap.md`](./roadmap.md) · [`decision-log.md`](./decision-log.md) · [`AGENTS.md`](../AGENTS.md).

**사람 PoC(D)와 Phase 1 §3 기본값은 맨 마지막.** 추측으로 채우지 않는다.

---

## 0. 통합 현황 (Claude + Cursor)

### DONE — Claude (`claude/project-planning-approach-ukdz31` 계열)

- [x] 기획 문서 세트 (`PLANNING`, vision/PRD/tech-design/risk/roadmap, decision-log 초안)
- [x] PoC #1/#3 계획·모집/역할극 자료·Q3 인터뷰 가이드·프로토타입 앵커
- [x] `poc/tone-corpus/` 파이프라인 (전처리·draft·escalation·retrieve·blind_eval)
- [x] 스택 확정: Flutter + Go core + Python AI
- [x] `core-backend/` · `ai-service/` · 하드게이트·거부권·초대·되돌리기·L0~L2 QA
- [x] Flutter UI 테마 폴리시 (`app_theme` + 화면별 시각 개선)

### DONE — Cursor 후속

- [x] A1/A2 API · A3 Flutter 메신저 연결 · API E2E (`scripts/e2e_a3.py`)
- [x] Phase 1 B (drift/SQLCipher, FCM 골격, sessions, metrics, data-flow, identity)
- [x] Phase 1 C (Q1~Q7 **확정**, invite-ops, Android release 경로)
- [x] Flutter Web SQLCipher stub · Twin Shadow UI · CORS · `DEMO-BUNSIN`
- [x] GitHub + Gitea 듀얼 리모트 (`scripts/push-both.sh`)

### NOW

- 앱 코드는 클로즈드 베타 직전 수준
- **프로덕션 Docker / `msn.iykyka.com` 배포는 미착수**
- 실 FCM · Android UI 수동 QA · 사람 PoC 실행은 남음

### NEXT 순서

```
N1 스모크 → N2 Docker(msn.iykyka.com) → N3 배포 안정화
         → N4 FCM·Android QA 등 → N5 사람 PoC(D) → 실제 베타 오픈
```

### LOCKED

- [ ] Phase 2+ (L3 / OS 레이어 / L4 / B2B) — Phase 1 게이트 전 구현 금지
- [ ] PoC §3 기본값(자율성 시작 레벨, 화이트리스트 기본 주제, 신뢰 UX 최종 카피) 추측 금지

---

## 항목 템플릿

각 ID를 처리할 때 아래로 상태를 갱신한다.

```text
Status: todo | doing | done | blocked
Depends on:
Acceptance: (체크리스트)
Notes:
```

---

## N1 — 배포 전 스모크

| ID | 작업 | Status | 완료 조건 |
|----|------|--------|-----------|
| **N1-1** | 서비스 기동 | todo | `8080` core-backend, `8001` ai-service, (옵션) `5555` Flutter web 헬스 OK |
| **N1-2** | API E2E | todo | `ADMIN_API_TOKEN` 설정 후 `python3 scripts/e2e_a3.py` 16/16 |
| **N1-3** | Web 가입 스모크 | todo | `DEMO-BUNSIN` → 표시명 → 가입 → 세션/다음 화면 |
| **N1-4** | 말투 온보딩 스모크 | todo | 샘플 저장 또는 스킵 후 대화 목록 진입 |
| **N1-5** | 핵심 메신저 스모크 | todo | 연락처·대화·메시지 또는 초안/L1 중 최소 1경로 UI 왕복 |
| **N1-6** | 프로덕션 CORS/API 메모 | todo | `msn.iykyka.com`용 origins / `CORE_API_BASE` 변경 목록 작성 |

로컬 포트 참고: 앱 **5555**, 코어 **8080**, AI **8001**. Dart VM Service 고포트(예: 39369)는 디버그용 — 무시 가능.

---

## N2 — Docker 배포 (`https://msn.iykyka.com`) — Plan A

### N2-A. 착수 전 결정 (Master 확인)

| ID | 결정 | 제안 기본값 | Status |
|----|------|-------------|--------|
| **N2-A1** | 구 Node MSN 교체 | 교체(Plan A) | todo |
| **N2-A2** | DB | 1차 SQLite 파일 볼륨 (PostgreSQL은 이후) | todo |
| **N2-A3** | AI 서비스 노출 | 내부망만 (외부 포트 미공개) | todo |
| **N2-A4** | 클라이언트 제공 | Web 컨테이너 ± 내부 APK (둘 다/웹만 결정) | todo |
| **N2-A5** | 시크릿 관리 | Portainer/호스트 env — **git 금지** | todo |
| **N2-A6** | 데모 초대 | 프로덕션 `ALLOW_DEMO_INVITE` on/off | todo |

### N2-B. 이미지·compose

| ID | 작업 | Status | 완료 조건 |
|----|------|--------|-----------|
| **N2-B1** | `core-backend` Dockerfile | todo | `docker build` 성공, migrate/기동 |
| **N2-B2** | `ai-service` Dockerfile | todo | `docker build` 성공 |
| **N2-B3** | Flutter web 빌드/서빙 | todo | `flutter build web` + nginx(또는 Caddy)로 `/` 로딩 |
| **N2-B4** | `docker-compose.yml` | todo | `up` 후 서비스 healthy |
| **N2-B5** | env 템플릿 | todo | `.env.example`에 키만: `GEMINI_API_KEY`, `ADMIN_API_TOKEN`, `AI_SERVICE_URL`, DB, `ALLOW_DEMO_INVITE`, CORS/origins, `FCM_*` |
| **N2-B6** | 데이터 볼륨 | todo | 재시작 후 SQLite(및 필요 경로) 유지 |
| **N2-B7** | 내부 DNS | todo | Go → `http://ai-service:…` draft/escalate 동작 |
| **N2-B8** | CORS + API base | todo | `https://msn.iykyka.com`에서 브라우저 가입 성공 |
| **N2-B9** | 리버스 프록시 | todo | HTTPS로 도메인 접속 |
| **N2-B10** | Portainer 스택 | todo | 스택 Up, 절차를 Notes에 기록 |
| **N2-B11** | 구 MSN 컷오버 | todo | 새 스택이 도메인 응답 + 롤백 메모 |
| **N2-B12** | 배포 스모크 | todo | N1-3~N1-5를 프로덕션 URL로 재실행 |
| **N2-B13** | 운영 runbook | todo | 로그·재시작·SQLite 백업·초대 발급 1페이지 (`docs/` 또는 본 파일 Notes) |

관련: Portainer `https://portainer.iykyka.com/`, 호스트 SSH는 인프라 메모 참고(시크릿은 커밋 금지).

---

## N3 — 배포 직후 안정화

| ID | 작업 | Status | 완료 조건 |
|----|------|--------|-----------|
| **N3-1** | 헬스/로그 | todo | OOM·CORS·502 없음 |
| **N3-2** | 초대 발급 리허설 | todo | `docs/invite-ops.md` 절차 1회 |
| **N3-3** | admin metrics | todo | `/admin/metrics`·`/admin/dashboard` 토큰 조회 |
| **N3-4** | Gemini | todo | draft 1회 실호출 또는 mock 정책 명시 |
| **N3-5** | 백업 리허설 | todo | SQLite 볼륨 복사/복구 1회 |
| **N3-6** | 테스터 안내 | todo | URL + 초대(`DEMO-BUNSIN` 또는 개인 코드) + 주의사항 |

---

## N4 — 베타 품질 잔여

### FCM

| ID | 작업 | Status | 완료 조건 |
|----|------|--------|-----------|
| **N4-1** | Firebase + `google-services.json` | todo | Android 앱 연결 |
| **N4-2** | 실 FCM registration token | todo | install-id 플레이스홀더 제거 |
| **N4-3** | 서버 FCM 자격증명 | todo | env만 (`FCM_SERVER_KEY` 또는 HTTP v1) |
| **N4-4** | 푸시 수신 | todo | `/admin/push-test` + 에스컬레이션 수신 |

### Android UI 탭 (`mobile/README.md`)

| ID | 작업 | Status |
|----|------|--------|
| **N4-5** | 가입 → 말투 저장 | todo |
| **N4-6** | 연락처 → 대화 → 메시지·히스토리 | todo |
| **N4-7** | L1 초안 수정/버리기/승인·뱃지 | todo |
| **N4-8** | 에스컬레이션 → 사후알림 함 | todo |
| **N4-9** | 되돌리기·거부권 | todo |
| **N4-10** | 자율성 L0~L2 + 화이트리스트 | todo |

### 후순위

| ID | 작업 | Status | 비고 |
|----|------|--------|------|
| **N4-11** | 오프라인 메시지 큐 | todo | 멀티디바이스 고도화 |
| **N4-12** | 자연스러움 피드백 UI | todo | vision 지표 |
| **N4-13** | `prototype.md` `SHARE_URL` | todo | Master 기입 |
| **N4-14** | 내부 release APK | todo | `docs/android-release.md` |
| **N4-15** | roadmap/`[~]` 동기화 | todo | 완료 시 체크 |

---

## N5 — 사람 PoC (D) — **지금 열지 않음**

N1~N4(배포·품질에 필요한 최소분) 이후에만 착수. `roadmap.md` Phase 1 §3과 동일.

| ID | 작업 | Status |
|----|------|--------|
| **N5-1** | PoC #1/#3 참가자 모집·실행 | locked |
| **N5-2** | Q3 인터뷰 → 자율성 기본값 | locked |
| **N5-3** | 화이트리스트 기본 주제 | locked |
| **N5-4** | 신뢰 UX 문구/위치 확정 | locked |
| **N5-5** | vision 게이트 → 실제 클로즈드 베타 오픈 | locked |

자료: [`poc-plan.md`](./poc-plan.md) · [`poc-materials.md`](./poc-materials.md) · [`user-interview-guide.md`](./user-interview-guide.md).

---

## 바로 다음 5개 (권장)

1. **N2-A1~A6** 결정 체크  
2. **N1-1~N1-5** 스모크  
3. **N2-B1~B4** Dockerfile + compose  
4. **N2-B8~B12** 도메인·Portainer·컷오버·스모크  
5. **N3-6** 테스터 안내  

완료 시 본 표의 Status를 `done`으로 바꾸고, [`roadmap.md`](./roadmap.md) §4/§5의 대응 `[~]`/`[ ]`도 같이 갱신한다.

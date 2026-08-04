# 와카뷰 mobile (Flutter)

Phase 1 클라이언트 (`docs/roadmap.md` §2.3 / A3).  
**릴리즈 타깃(암호화 DB·OS 알림):** Android.  
**데모/프리뷰 1차 표면:** Flutter **Web** (`https://msn.iykyka.com`) —
고도화 설계·단계: [`docs/web-upgrade.md`](../docs/web-upgrade.md) (W0~W7).

## 지금 있는 것

- 초대 코드 가입 (`POST /auth/signup`) + Bearer 세션
- 말투 샘플 온보딩(기기 로컬 저장; 최종 카피는 PoC 이후)
- 대화방 목록/생성 (`GET`/`POST /conversations`) — 수동 ID 입력 제거
- 연락처 CRUD + 대화 시작 (`/users/:id/contacts`)
- 채팅 히스토리 로드 + WebSocket 수신
- 와카뷰 초안 / L1 승인(수정·버리기·재초안·승인 발송)
- 와카뷰 뱃지 · 거부권 · 되돌리기
- 사후 알림 함 (`GET /users/:id/escalation-logs`)
- 자율성 L0~L2 + 화이트리스트 CRUD UI

## 실행

```bash
# core-backend + ai-service 가 떠 있어야 실제 호출이 된다
cd mobile
flutter pub get

# Android 에뮬레이터 → 호스트의 core-backend(기본 8080)
flutter run --dart-define=CORE_API_BASE=http://10.0.2.2:8080

# 실기기/로컬 네트워크
flutter run --dart-define=CORE_API_BASE=http://<your-lan-ip>:8080
```

## E2E

**API 레벨 (클라우드/CI에서 실행 가능)**

```bash
# core-backend :8080 + ai-service :8001 기동 후
export ADMIN_API_TOKEN=dev-admin-token
python3 scripts/e2e_a3.py
```

A3 체크리스트(가입·연락처·대화·히스토리·draft/L1·에스컬레이션·되돌리기·거부권·화이트리스트)를
HTTP로 검증한다.

**에뮬레이터/실기기 UI 탭 (Android SDK 필요)**

1. 초대 코드로 가입 → 말투 샘플 저장(또는 나중에)
2. 연락처에 상대 사용자 ID 등록 → 대화 시작
3. 메시지 전송 · 새로고침 후 히스토리 유지
4. 초안 요청 → L1 패널에서 수정/버리기/승인 발송 → 와카뷰 뱃지 확인
5. 민감 문장으로 에스컬레이션 → 사후 알림 함 진입
6. 와카뷰 메시지 되돌리기 · 거부권
7. 자율성 L0~L2 + 화이트리스트 추가/삭제

## 로컬 DB (drift + SQLCipher)

말투 샘플·온보딩 플래그는 `lib/db/` 암호화 SQLite에 저장한다. 패스프레이즈는
`flutter_secure_storage`. Linux 개발 호스트에 `libsqlcipher.so`가 없으면 메모리 폴백으로
기동한다(Android 릴리즈 경로에서는 SQLCipher 사용).

```bash
# Linux에서 drift 테스트/암호화 DB를 쓰려면
sudo apt-get install -y libsqlite3-dev libsqlcipher1
```

## 웹 (데모/프리뷰)

- 로컬 DB: `lib/db/app_database_web.dart` — **W1 done**: SharedPreferences 지속성(비암호화 프리뷰)
- 스누즈 OS 알림: 웹 no-op → **W3** Notification API / 인앱
- 푸시: 프로덕션은 `FIREBASE_*` + VAPID 주입됨 · 로컬은 dart-define 없으면 `install:` ([`docs/fcm-setup.md`](../docs/fcm-setup.md) Web 절)
- PWA: **W5 done** — manifest 테마·설치·셸 캐시
- **Q9**(수신 자동응대)는 웹 트랙 비범위

```bash
# 웹 로컬 (core-backend 기동 후)
cd mobile && flutter run -d chrome --dart-define=CORE_API_BASE=http://localhost:8080
```

## 푸시 (FCM)

- 코드: `lib/services/push_token_service.dart` — Firebase 가능 시 실 토큰, 아니면 `install:`
- Android: [`docs/fcm-setup.md`](../docs/fcm-setup.md) (`google-services.json`)
- Web: [`docs/web-upgrade.md`](../docs/web-upgrade.md) W4 + 동일 `fcm-setup` Web 절

## 아직 없는 것

- 웹 W4 **accept** — 브라우저 실 FCM 토큰·`/admin/push-test` (코드·`:web:` 배포는 완료, [`web-upgrade.md`](../docs/web-upgrade.md))
- Android: `google-services.json` PC 배치 후 실기기 푸시 스모크 (N4-1/4; 서버 SA는 N4-3 done)
- 멀티디바이스 실시간 설정 동기화 고도화
- 온보딩 말투 UX 디테일 (PoC #1 결과는 맨 마지막에 반영)
- iOS 빌드 (v1 범위 밖)

# FCM 설정 (N4-1 ~ N4-4 · N4-W4)

서버·클라이언트의 푸시 **코드 경로는 준비됨**.  
새 Firebase 프로젝트는 **레거시 서버 키가 비활성**인 경우가 많아, **HTTP v1 + 서비스 계정 JSON**을 쓴다.

## 이미 된 것 (코드 · 프로덕션)

| 계층 | 동작 |
|------|------|
| Flutter | `PushTokenService` — Firebase 가능하면 실 FCM 토큰, 아니면 `install:` 플레이스홀더 |
| Android | `google-services.json`이 있을 때만 Google Services 플러그인 적용 |
| Web (N4-W4) | `FirebaseWebConfig` + 프로덕션 `.env` `FIREBASE_*`/`VAPID` 주입 · SW populated (`:web:` APP_ID) |
| core-backend | `notifyUser` + `POST /admin/push-test` — **FCM HTTP v1**(서비스 계정) 우선 |
| 서버 SA (N4-3) | 프로덕션 `secrets/firebase-service-account.json` 마운트 **done** |

## Master가 할 일

### N4-1 — Firebase Android 앱

1. [Firebase Console](https://console.firebase.google.com/) → Android 앱 추가  
   package: **`com.ykavu.ykavu_mobile`**
2. `google-services.json`을 **Android 빌드 PC**에만 배치 (git 금지):

```bash
cp ~/Downloads/google-services.json mobile/android/app/google-services.json
```

### N4-3 — 서비스 계정 JSON (HTTP v1) — **프로덕션 done**

레거시 **서버 키**가 Cloud Messaging 탭에서 `사용 중지됨`이면 정상이다.

프로덕션 호스트에 이미 배치됨:

```bash
# ~/project/ykavu/secrets/firebase-service-account.json
# compose: ./secrets → /secrets, FCM_SERVICE_ACCOUNT_FILE=/secrets/firebase-service-account.json
```

새 환경에 다시 놓을 때:

```bash
mkdir -p secrets
mv ~/Downloads/iykyka-*.json secrets/firebase-service-account.json
chmod 600 secrets/firebase-service-account.json
docker compose up -d --build core-backend
```

**git / 채팅에 JSON 내용을 붙여넣지 않는다.**

### N4-2 / N4-4 — Android 실기기 스모크

```bash
cd mobile
flutter run --release --dart-define=CORE_API_BASE=https://msn.iykyka.com
# 로그: device token registered (FCM)
```

```bash
curl -sS -X POST https://msn.iykyka.com/admin/push-test \
  -H "Authorization: Bearer $ADMIN_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"user_id": <USER_ID>, "title":"와카뷰","body":"push smoke"}'
```

기대: `sent >= 1`.  
`only_placeholder_tokens` → Android에 `google-services.json` 넣고 재설치.  
`fcm_not_configured` → 서비스 계정 경로 확인.

## Web (N4-W4)

설계·수락: [`web-upgrade.md`](./web-upgrade.md) §N4-W4 · 실행 표: [`deploy-checklist.md`](./deploy-checklist.md) §N4-W.

**프로덕션:** Firebase Web config + VAPID + `:web:` APP_ID가 서버 `.env`에 있고 `web` 이미지에 빌드 주입됨.  
SW(`firebase-messaging-sw.js`) populated. 서버 SA는 Android와 공유.

### 남은 accept (브라우저)

1. `https://msn.iykyka.com` **하드 리프레시** (또는 사이트 데이터 삭제)
2. 알림 **허용** → 로그인
3. device_tokens에 실 토큰(`platform=web`, `install:` 아님)
4. `/admin/push-test` → `sent >= 1` (탭 백그라운드에서도 알림)

로컬/스테이징에서 define이 비어 있으면 웹은 `install:`만 등록 → `only_placeholder_tokens`가 정상.

### 새 환경에 Web 시크릿을 넣을 때

배포 호스트 **`~/project/ykavu/.env`**(클라우드 에이전트 `/workspace/.env`와 별개):

```bash
FIREBASE_API_KEY=
FIREBASE_AUTH_DOMAIN=          # 비우면 {projectId}.firebaseapp.com
FIREBASE_PROJECT_ID=
FIREBASE_STORAGE_BUCKET=       # 비우면 {projectId}.appspot.com
FIREBASE_MESSAGING_SENDER_ID=
FIREBASE_APP_ID=               # must be 1:…:web:…  (not :android:)
FIREBASE_VAPID_KEY=
```

```bash
docker compose up -d --build web
```

### 로컬 Flutter web

```bash
cd mobile
flutter run -d chrome \
  --dart-define=CORE_API_BASE=http://localhost:8080 \
  --dart-define=FIREBASE_API_KEY=... \
  --dart-define=FIREBASE_APP_ID=... \
  --dart-define=FIREBASE_MESSAGING_SENDER_ID=... \
  --dart-define=FIREBASE_PROJECT_ID=... \
  --dart-define=FIREBASE_VAPID_KEY=...
```

### 구현 위치

- `mobile/lib/config/firebase_web_config.dart`
- `mobile/lib/services/push_token_service.dart` (`_tryFirebaseWebToken`)
- `mobile/web/firebase-messaging-sw.js` (+ `.template`, `scripts/docker_build_web.sh`)
- `mobile/Dockerfile` / `docker-compose.yml` build-args

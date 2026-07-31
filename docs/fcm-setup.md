# FCM 설정 (N4-1 ~ N4-4)

서버·클라이언트의 푸시 **코드 경로는 준비됨**. 실제 전송은 Master가 Firebase 시크릿을
넣기 전까지 soft-skip 한다 (`install:` 토큰·`FCM_SERVER_KEY` 없음).

## 이미 된 것 (코드)

| 계층 | 동작 |
|------|------|
| Flutter | `PushTokenService` — Firebase 가능하면 실 FCM 토큰, 아니면 `install:` 플레이스홀더 |
| Android | `google-services.json`이 있을 때만 Google Services 플러그인 적용 |
| core-backend | `notifyUser` + `POST /admin/push-test` — `FCM_SERVER_KEY` + 실 토큰일 때만 전송 |

## Master가 할 일

### N4-1 — Firebase 앱

1. [Firebase Console](https://console.firebase.google.com/)에서 프로젝트 생성 (또는 기존 사용).
2. Android 앱 추가 — package name: **`com.ykavu.ykavu_mobile`**
3. 받은 `google-services.json`을 로컬에만 배치 (git 금지):

```bash
cp ~/Downloads/google-services.json mobile/android/app/google-services.json
```

템플릿: `mobile/android/app/google-services.json.example`

### N4-3 — 서버 키 (env only)

Cloud Messaging **레거시 서버 키**(또는 호환 서버 키)를 호스트 `.env`에만 설정:

```bash
# 서버 ~/project/ykavu/.env
FCM_SERVER_KEY=AAAA...
```

```bash
cd ~/project/ykavu
docker compose up -d core-backend
```

**git / 이미지에 키를 넣지 않는다** (N2-A5).

> 레거시 HTTP API가 Console에서 비활성이면 HTTP v1 마이그레이션이 필요하다.
> 그 전까지는 레거시 키가 있는 프로젝트로 N4-4 스모크를 완료한다.

### N4-2 / N4-4 — 실기기 스모크

```bash
cd mobile
flutter run --release --dart-define=CORE_API_BASE=https://msn.iykyka.com
# 가입 → 로그에 "device token registered (FCM)" 확인
```

```bash
curl -sS -X POST https://msn.iykyka.com/admin/push-test \
  -H "Authorization: Bearer $ADMIN_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"user_id": <USER_ID>, "title":"와카뷰","body":"push smoke"}'
```

기대: `sent >= 1`, `skipped_reason` 없음. 기기에 알림 표시.

`only_placeholder_tokens` / `fcm_not_configured` 이면 위 N4-1·N4-3을 다시 확인.

## Web

현재 프로덕션 UI는 Flutter Web. Web 푸시는 Firebase Web 설정 + VAPID가 추가로 필요하며
이번 N4 범위에서는 **Android 실푸시**를 우선한다. Web은 계속 `install:` 플레이스홀더를 등록한다.

# FCM 설정 (N4-1 ~ N4-4)

서버·클라이언트의 푸시 **코드 경로는 준비됨**.  
새 Firebase 프로젝트는 **레거시 서버 키가 비활성**인 경우가 많아, **HTTP v1 + 서비스 계정 JSON**을 쓴다.

## 이미 된 것 (코드)

| 계층 | 동작 |
|------|------|
| Flutter | `PushTokenService` — Firebase 가능하면 실 FCM 토큰, 아니면 `install:` 플레이스홀더 |
| Android | `google-services.json`이 있을 때만 Google Services 플러그인 적용 |
| core-backend | `notifyUser` + `POST /admin/push-test` — **FCM HTTP v1**(서비스 계정) 우선, 레거시 `FCM_SERVER_KEY`는 폴백 |

## Master가 할 일

### N4-1 — Firebase Android 앱

1. [Firebase Console](https://console.firebase.google.com/) → Android 앱 추가  
   package: **`com.ykavu.ykavu_mobile`**
2. `google-services.json`을 로컬에만 배치 (git 금지):

```bash
cp ~/Downloads/google-services.json mobile/android/app/google-services.json
```

### N4-3 — 서비스 계정 JSON (HTTP v1)

레거시 **서버 키**가 Cloud Messaging 탭에서 `사용 중지됨`이면 정상이다. 아래를 쓴다.

1. Google Cloud → 사용자 인증 정보 → 서비스 계정 만들기  
   (API: Firebase Cloud Messaging API, 데이터: **애플리케이션 데이터**)
2. 역할: **Firebase Cloud Messaging Admin** (없으면 Firebase 관리자 / 임시 소유자)
3. 키 유형 **JSON** 다운로드
4. 서버(또는 이 워크스페이스)에 배치:

```bash
# 파일명 고정
mkdir -p secrets
mv ~/Downloads/iykyka-*.json secrets/firebase-service-account.json
chmod 600 secrets/firebase-service-account.json
```

5. 프로덕션 호스트에도 동일 파일:

```bash
# 예: scp 후
cd ~/project/ykavu
# secrets/firebase-service-account.json 존재 확인
docker compose up -d --build core-backend
```

`docker-compose.yml`이 `./secrets` → 컨테이너 `/secrets`로 마운트하고  
`FCM_SERVICE_ACCOUNT_FILE=/secrets/firebase-service-account.json`을 읽는다.

**git / 채팅에 JSON 내용을 붙여넣지 않는다.**

### N4-2 / N4-4 — 실기기 스모크

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
`fcm_not_configured` → 서버에 서비스 계정 파일 경로 확인.

## Web

Web 푸시는 별도 VAPID 설정이 필요하며 이번 N4는 **Android 실푸시** 우선.

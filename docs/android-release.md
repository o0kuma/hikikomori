# Android 릴리즈·내부 배포 경로 (Phase 1 C)

v1은 **Android만** 대상 (`tech-design.md` §8). Play 스토어 공개가 아니라
**지인 클로즈드 베타용 내부 APK/AAB** 경로를 먼저 고정한다.

## 산출물

| 산출물 | 명령 | 용도 |
|--------|------|------|
| 내부 APK | `./scripts/build_release_apk.sh` | 직접 설치·메신저 공유 |
| AAB | `./scripts/build_release_aab.sh` | Play 내부 테스트 트랙 (선택) |

## 서명 키 (Master 로컬 전용)

1. 키스토어는 **절대 git에 넣지 않는다** (`mobile/android/key.properties`, `*.jks`, `*.keystore`는 gitignore).
2. Master 머신에서 한 번 생성:

```bash
keytool -genkey -v -keystore ~/ykavu-release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias ykavu
```

3. `mobile/android/key.properties.example`을 복사해 `mobile/android/key.properties` 작성:

```
storePassword=...
keyPassword=...
keyAlias=ykavu
storeFile=/absolute/path/to/ykavu-release.jks
```

4. `key.properties`가 없으면 release 빌드는 **디버그 서명으로 폴백**하며 경고를 낸다
   (내부 스모크용). 베타 배포본은 반드시 release keystore로 서명한다.

## 빌드

```bash
cd mobile
flutter pub get
../scripts/build_release_apk.sh
# → build/app/outputs/flutter-apk/app-release.apk

../scripts/build_release_aab.sh   # Play 내부 테스트용 (선택)
```

API 베이스 URL은 배포 대상 서버에 맞게:

```bash
flutter build apk --release \
  --dart-define=CORE_API_BASE=https://api.example.com
```

## 배포 채널 (권장 순서)

1. **직접 APK** — 초대받은 지인에게만 파일 전달 (1차 클로즈드 베타)
2. **Play 내부 테스트** — 규모가 커지면 AAB + 테스터 이메일 목록
3. 공개 트랙 — Phase 게이트(`vision.md`) 통과 전 금지

## 체크리스트

- [ ] `key.properties` + jks가 Master 백업에만 존재
- [ ] `CORE_API_BASE`가 베타 서버를 가리킴
- [ ] `ADMIN_API_TOKEN` / `GEMINI_API_KEY` / `FCM_SERVER_KEY`가 서버에만 설정
- [ ] 초대 코드 운영 (`docs/invite-ops.md`) 숙지
- [ ] 실기기에서 `mobile/README.md` E2E UI 체크 1회

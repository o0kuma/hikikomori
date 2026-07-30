# 분신 mobile (Flutter)

Phase 1 클라이언트 골격 (`docs/roadmap.md` §2.3). **v1은 Android 빌드만** 대상으로 한다
(`docs/tech-design.md` §8).

## 지금 있는 것

- 초대 코드 가입 (`POST /auth/signup`)
- 대화방 입장(임시: 대화방 ID 직접 입력 — 목록 API는 아직 core-backend에 없음)
- 채팅 전송 + WebSocket 수신
- 분신 초안 요청 / L1 승인 발송
- 분신 뱃지(점선 + 라벨) · 거부권 · 되돌리기
- 자율성 L0~L2 설정 + 화이트리스트 CRUD UI

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

## 아직 없는 것

- 대화방/연락처 목록 API 연동 (서버에 엔드포인트 추가 필요)
- 온보딩 말투 학습 UX 디테일 (PoC #1 결과는 맨 마지막에 반영)
- drift + SQLCipher 온디바이스 저장
- 푸시 알림
- iOS 빌드 (v1 범위 밖)

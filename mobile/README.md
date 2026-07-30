# 분신 mobile (Flutter)

Phase 1 클라이언트 (`docs/roadmap.md` §2.3 / A3). **v1은 Android 빌드만** 대상으로 한다
(`docs/tech-design.md` §8).

## 지금 있는 것

- 초대 코드 가입 (`POST /auth/signup`) + Bearer 세션
- 말투 샘플 온보딩(기기 로컬 저장; 최종 카피는 PoC 이후)
- 대화방 목록/생성 (`GET`/`POST /conversations`) — 수동 ID 입력 제거
- 연락처 CRUD + 대화 시작 (`/users/:id/contacts`)
- 채팅 히스토리 로드 + WebSocket 수신
- 분신 초안 / L1 승인(수정·버리기·재초안·승인 발송)
- 분신 뱃지 · 거부권 · 되돌리기
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
4. 초안 요청 → L1 패널에서 수정/버리기/승인 발송 → 분신 뱃지 확인
5. 민감 문장으로 에스컬레이션 → 사후 알림 함 진입
6. 분신 메시지 되돌리기 · 거부권
7. 자율성 L0~L2 + 화이트리스트 추가/삭제

## 아직 없는 것 (B 이후)

- FCM 푸시 · drift + SQLCipher · 멀티 디바이스
- 온보딩 말투 UX 디테일 (PoC #1 결과는 맨 마지막에 반영)
- iOS 빌드 (v1 범위 밖)

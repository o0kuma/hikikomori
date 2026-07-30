# 초대 코드 운영 절차 (Phase 1 C)

클로즈드 베타 가입은 **미리 발급된 1회용 초대 코드**로만 가능하다
(`POST /auth/signup` → `InviteCode` 검증).

## 발급자 권한

| 역할 | 권한 |
|------|------|
| **발급자 (Issuer)** | Master(또는 Master가 지정한 1명). `ADMIN_API_TOKEN`을 가진 주체만 발급·목록·회수 |
| 일반 사용자 | 초대 발급 불가. 받은 코드로 가입만 가능 |
| CI / 에이전트 | 프로덕션 `ADMIN_API_TOKEN`을 저장·공유하지 않음 |

토큰은 서버 환경변수 `ADMIN_API_TOKEN`으로만 주입한다. 레포·채팅·커밋에 넣지 않는다.

## 발급 규칙

1. **용도 메모 필수 권장** — `note`에 수신자/채널(예: `지인-김ㅇㅇ`, `PoC#3-참가자3`)을 남긴다.
2. **만료** — 기본 14일. 장기 코드는 만들지 않는다 (`expires_in_days`).
3. **배치** — 한 번에 최대 20개 (`count`). 대량 발급 전 Master 확인.
4. **1코드 = 1가입**. 재사용 불가. 계정 삭제 후에도 코드는 “사용됨”으로 남는다.
5. **회수** — 전달 전 유출·오배포 시 `POST /invites/:code/revoke`. 이미 사용된 코드는 회수 불가.

## 운영 커맨드

```bash
export ADMIN_API_TOKEN=...   # 로컬/서버에만
export CORE=http://127.0.0.1:8080

# 단일 발급 (14일, 메모)
curl -sS -X POST "$CORE/invites" \
  -H "Authorization: Bearer $ADMIN_API_TOKEN" \
  -H 'Content-Type: application/json' \
  -d '{"note":"지인-테스트","expires_in_days":14}'

# 배치 5개
curl -sS -X POST "$CORE/invites" \
  -H "Authorization: Bearer $ADMIN_API_TOKEN" \
  -H 'Content-Type: application/json' \
  -d '{"note":"베타-1차","expires_in_days":14,"count":5}'

# 목록
curl -sS "$CORE/invites" -H "Authorization: Bearer $ADMIN_API_TOKEN"

# 회수
curl -sS -X POST "$CORE/invites/<CODE>/revoke" \
  -H "Authorization: Bearer $ADMIN_API_TOKEN"
```

사용 현황은 `GET /admin/metrics`의 `invites_minted` / `invites_used`와 목록의
`status`(`unused`|`used`|`expired`|`revoked`)로 본다.

## 배포 전 체크

- [ ] 프로덕션 `ADMIN_API_TOKEN` 회전·길이 충분(≥32자 권장)
- [ ] 초대 코드를 공개 채널(SNS/이슈)에 올리지 않음
- [ ] 만료·회수된 코드로 가입이 거절되는지 스모크 테스트

# 와카뷰 테스터 안내 (N3-6 / Track B)

## 접속

- 웹: **https://msn.iykyka.com**
- 공용 데모 초대 코드: **`DEMO-YKAVU`**
- 표시 이름 예시: `테스터` (원하는 이름으로 변경 가능)

같은 코드를 여러 명이 쓸 수 있습니다 (`ALLOW_DEMO_INVITE=1`).

API 메타: `GET https://msn.iykyka.com/demo` — `pairing_steps` / `notes` 포함.

## 권장 페어링 플로우 (5~10분)

두 명(또는 시크릿 창 두 개)으로 진행합니다. **대화는 닉네임이 아니라 숫자 사용자 ID로 연결됩니다.**

1. **가입** — 초대 코드 `DEMO-YKAVU` 입력 (각자 다른 표시 이름 권장)
2. **말투 샘플** — 몇 줄 적거나 스킵
3. **내 ID 복사** — 대화 목록 상단「내 사용자 ID」칩을 탭해 복사하고 상대에게 전달
4. **연락처 추가** — 상대 표시 이름 + **상대의 숫자 ID(필수)** → 추가 → 「대화」
5. **메시지** — 사람 모드로 한두 줄 주고받기
6. **와카뷰 초안** — 메뉴 → 자율성에서 **L1** → 초안이 뜨면 수정/승인하고 보내기
7. (선택) L0에서는「입력창으로 옮기기」만 됩니다. L2·거부권·사후알림 함도 눌러 보세요.

### ID 없는 옛 연락처

이름만 넣고 ID를 비운 연락처는 대화가 안 됩니다. 연락처 화면에서 **「ID 입력」**으로 숫자 ID를 채우면 됩니다 (삭제 후 재추가 불필요).

## 알아둘 점

- **초안(AI)**: Gemini 키가 서버에 설정되어 있어 **실제 초안**이 생성됩니다.
- **L0(비서)**: 와카뷰 발송이 서버에서 막혀 있습니다. 초안 → 입력창 → 직접 전송.
- 푸시(FCM)는 아직 플레이스홀더 단계일 수 있습니다.
- 문제/스크린샷은 Master에게 전달해 주세요.
- 민감 정보·실명 대화는 베타 특성상 최소화해 주세요.

## 개인 초대 (운영자)

공용 코드 대신 1회용 코드가 필요하면:

```bash
curl -sS -X POST https://msn.iykyka.com/invites \
  -H "Authorization: Bearer $ADMIN_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"note":"테스터-이름","expires_in_days":14}'
```

절차 상세: [`invite-ops.md`](./invite-ops.md)

## 장애 시 운영자 체크

```bash
cd ~/project/ykavu
docker compose ps
curl -sS https://msn.iykyka.com/health
docker compose logs --tail=100 core-backend ai-service web
```

백업: `./scripts/backup-postgres.sh` (호스트에서)

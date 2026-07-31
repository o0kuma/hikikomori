# 와카뷰 테스터 안내 (N3-6)

## 접속

- 웹: **https://msn.iykyka.com**
- 공용 데모 초대 코드: **`DEMO-YKAVU`**
- 표시 이름 예시: `테스터` (원하는 이름으로 변경 가능)

같은 코드를 여러 명이 쓸 수 있습니다 (`ALLOW_DEMO_INVITE=1`).

## 권장 플로우 (5분)

1. 가입 — 초대 코드 `DEMO-YKAVU` 입력  
2. 말투 샘플 온보딩 — 몇 줄 적거나 스킵  
3. 연락처에 상대 유저 등록 → 대화 시작  
4. 메시지 전송 · 분신 초안(L1) 한 번 시도  
5. (선택) 자율성 L0~L2 / 거부권 / 사후알림 함 확인  

## 알아둘 점

- **초안(AI)**: Gemini 키가 서버에 설정되어 있어 **실제 초안**이 생성됩니다. (이전에 `no_key`이던 상태는 해소됨)
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

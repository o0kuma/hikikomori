# Postgres 백업·복구 (N3-5)

서버 path: `~/project/ykavu`  
덤프 위치: `~/backups/ykavu/ykavu-YYYYMMDDThhmmssZ.sql.gz`

## 백업

```bash
cd ~/project/ykavu
./scripts/backup-postgres.sh
# 또는
docker compose exec -T postgres pg_dump -U ykavu ykavu | gzip > ~/backups/ykavu/ykavu-$(date -u +%Y%m%dT%H%M%SZ).sql.gz
```

리허설(2026-07-31): 덤프 → `ykavu_restore_test` DB로 복구 → `\dt` 11테이블 · users count 확인 → 테스트 DB 삭제 OK.

## 복구 (주의: 운영 DB 덮어쓰기)

```bash
cd ~/project/ykavu
# 1) 서비스 중지 권장
docker compose stop core-backend web
# 2) 기존 DB 드롭/재생성 또는 새 DB로 검증 후 전환
gunzip -c ~/backups/ykavu/ykavu-XXXX.sql.gz | docker compose exec -T postgres psql -U ykavu -d ykavu
docker compose start core-backend web
```

권장: 먼저 별도 DB(`ykavu_restore_test`)에 복구해 검증한 뒤 컷오버.

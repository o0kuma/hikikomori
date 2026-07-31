#!/usr/bin/env bash
# Run on the deploy host from the compose project directory (e.g. ~/project/ykavu).
# Creates gzipped pg_dump under ~/backups/ykavu and prunes older than keep-count.
set -euo pipefail

KEEP="${BACKUP_KEEP:-10}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
OUT_DIR="${BACKUP_DIR:-$HOME/backups/ykavu}"
mkdir -p "$OUT_DIR"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
DUMP="$OUT_DIR/ykavu-$STAMP.sql.gz"

docker compose exec -T postgres pg_dump -U "${POSTGRES_USER:-ykavu}" "${POSTGRES_DB:-ykavu}" | gzip >"$DUMP"
ls -lh "$DUMP"
ls -1t "$OUT_DIR"/ykavu-*.sql.gz | tail -n +"$((KEEP + 1))" | xargs -r rm -f
echo "OK $DUMP"

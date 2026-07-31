#!/usr/bin/env bash
# Run ON the iykyka host (SSH or Portainer host shell) after cloning this repo.
# Does not commit secrets. Requires Docker Compose v2 + .env filled.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if [[ ! -f .env ]]; then
  echo "Missing .env — copy from .env.example and set ADMIN_API_TOKEN, POSTGRES_PASSWORD, GEMINI_API_KEY"
  exit 1
fi

# shellcheck disable=SC1091
set -a
source .env
set +a

: "${ADMIN_API_TOKEN:?ADMIN_API_TOKEN required}"
: "${POSTGRES_PASSWORD:?POSTGRES_PASSWORD required}"
: "${PUBLIC_API_BASE:=https://msn.iykyka.com}"
: "${WEB_HOST_PORT:=8088}"

export PUBLIC_API_BASE WEB_HOST_PORT

echo "==> Building & starting stack (PUBLIC_API_BASE=$PUBLIC_API_BASE WEB_HOST_PORT=$WEB_HOST_PORT)"
docker compose pull postgres || true
docker compose up -d --build --remove-orphans

echo "==> Waiting for web health on localhost:${WEB_HOST_PORT}"
for i in $(seq 1 60); do
  if curl -fsS "http://127.0.0.1:${WEB_HOST_PORT}/health" >/dev/null 2>&1; then
    echo "OK health"
    curl -fsS "http://127.0.0.1:${WEB_HOST_PORT}/health"; echo
    curl -fsS "http://127.0.0.1:${WEB_HOST_PORT}/demo"; echo
    exit 0
  fi
  sleep 5
done

echo "Timed out waiting for /health — check: docker compose ps && docker compose logs"
docker compose ps
exit 1

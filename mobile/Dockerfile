# Flutter Web → nginx. Build from repository root:
#   docker build -f mobile/Dockerfile --build-arg CORE_API_BASE=https://msn.iykyka.com .
# Optional Web Push (N4-W4) — pass FIREBASE_* / FIREBASE_VAPID_KEY as build-args
# (never commit real values; see .env.example and docs/fcm-setup.md).
ARG FLUTTER_IMAGE=ghcr.io/cirruslabs/flutter:3.32.7
FROM ${FLUTTER_IMAGE} AS build

WORKDIR /app
ARG CORE_API_BASE=https://msn.iykyka.com
ARG FIREBASE_API_KEY=
ARG FIREBASE_AUTH_DOMAIN=
ARG FIREBASE_PROJECT_ID=
ARG FIREBASE_STORAGE_BUCKET=
ARG FIREBASE_MESSAGING_SENDER_ID=
ARG FIREBASE_APP_ID=
ARG FIREBASE_VAPID_KEY=

COPY mobile/pubspec.yaml mobile/pubspec.lock ./
RUN flutter pub get

COPY mobile/ .

# Populate firebase-messaging-sw.js when Web config is present; keep stub otherwise.
RUN set -eu; \
    if [ -n "${FIREBASE_API_KEY}" ] && [ -n "${FIREBASE_APP_ID}" ] && \
       [ -n "${FIREBASE_MESSAGING_SENDER_ID}" ] && [ -n "${FIREBASE_PROJECT_ID}" ]; then \
      AUTH_DOMAIN="${FIREBASE_AUTH_DOMAIN:-${FIREBASE_PROJECT_ID}.firebaseapp.com}"; \
      STORAGE_BUCKET="${FIREBASE_STORAGE_BUCKET:-${FIREBASE_PROJECT_ID}.appspot.com}"; \
      sed \
        -e "s|__FIREBASE_API_KEY__|${FIREBASE_API_KEY}|g" \
        -e "s|__FIREBASE_AUTH_DOMAIN__|${AUTH_DOMAIN}|g" \
        -e "s|__FIREBASE_PROJECT_ID__|${FIREBASE_PROJECT_ID}|g" \
        -e "s|__FIREBASE_STORAGE_BUCKET__|${STORAGE_BUCKET}|g" \
        -e "s|__FIREBASE_MESSAGING_SENDER_ID__|${FIREBASE_MESSAGING_SENDER_ID}|g" \
        -e "s|__FIREBASE_APP_ID__|${FIREBASE_APP_ID}|g" \
        web/firebase-messaging-sw.js.template > web/firebase-messaging-sw.js; \
      echo "firebase-messaging-sw.js: populated for project ${FIREBASE_PROJECT_ID}"; \
    else \
      echo "firebase-messaging-sw.js: stub (FIREBASE_* build-args empty)"; \
    fi

RUN flutter build web --release \
      --dart-define=CORE_API_BASE=${CORE_API_BASE} \
      --dart-define=FIREBASE_API_KEY=${FIREBASE_API_KEY} \
      --dart-define=FIREBASE_AUTH_DOMAIN=${FIREBASE_AUTH_DOMAIN} \
      --dart-define=FIREBASE_PROJECT_ID=${FIREBASE_PROJECT_ID} \
      --dart-define=FIREBASE_STORAGE_BUCKET=${FIREBASE_STORAGE_BUCKET} \
      --dart-define=FIREBASE_MESSAGING_SENDER_ID=${FIREBASE_MESSAGING_SENDER_ID} \
      --dart-define=FIREBASE_APP_ID=${FIREBASE_APP_ID} \
      --dart-define=FIREBASE_VAPID_KEY=${FIREBASE_VAPID_KEY}

FROM nginx:1.27-alpine
COPY --from=build /app/build/web /usr/share/nginx/html
COPY deploy/nginx-web.conf /etc/nginx/conf.d/default.conf
EXPOSE 80
HEALTHCHECK --interval=10s --timeout=3s --retries=5 \
  CMD wget -qO- http://127.0.0.1/ >/dev/null || exit 1

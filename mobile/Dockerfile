# Flutter Web → nginx. Build from repository root:
#   docker build -f mobile/Dockerfile --build-arg CORE_API_BASE=https://msn.iykyka.com .
# Optional Web Push (N4-W4) — pass FIREBASE_* / FIREBASE_VAPID_KEY as build-args
# (never commit real values; see .env.example and docs/fcm-setup.md).
#
# Secrets are copied into ENV for the build stage only (not the final nginx image).
# The RUN line calls a script so values are not expanded into Docker build logs.
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

ENV CORE_API_BASE=${CORE_API_BASE} \
    FIREBASE_API_KEY=${FIREBASE_API_KEY} \
    FIREBASE_AUTH_DOMAIN=${FIREBASE_AUTH_DOMAIN} \
    FIREBASE_PROJECT_ID=${FIREBASE_PROJECT_ID} \
    FIREBASE_STORAGE_BUCKET=${FIREBASE_STORAGE_BUCKET} \
    FIREBASE_MESSAGING_SENDER_ID=${FIREBASE_MESSAGING_SENDER_ID} \
    FIREBASE_APP_ID=${FIREBASE_APP_ID} \
    FIREBASE_VAPID_KEY=${FIREBASE_VAPID_KEY}

COPY mobile/pubspec.yaml mobile/pubspec.lock ./
RUN flutter pub get

COPY mobile/ .
RUN chmod +x scripts/docker_build_web.sh && ./scripts/docker_build_web.sh

FROM nginx:1.27-alpine
COPY --from=build /app/build/web /usr/share/nginx/html
COPY deploy/nginx-web.conf /etc/nginx/conf.d/default.conf
EXPOSE 80
HEALTHCHECK --interval=10s --timeout=3s --retries=5 \
  CMD wget -qO- http://127.0.0.1/ >/dev/null || exit 1

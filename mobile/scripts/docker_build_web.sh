#!/usr/bin/env bash
# Runs inside the Flutter build stage. Reads FIREBASE_* from the environment
# (set via Dockerfile ENV from build-args) so secret values are not expanded
# into the Dockerfile RUN instruction / build logs.
set -euo pipefail

CORE_API_BASE="${CORE_API_BASE:-https://msn.iykyka.com}"
FIREBASE_API_KEY="${FIREBASE_API_KEY:-}"
FIREBASE_AUTH_DOMAIN="${FIREBASE_AUTH_DOMAIN:-}"
FIREBASE_PROJECT_ID="${FIREBASE_PROJECT_ID:-}"
FIREBASE_STORAGE_BUCKET="${FIREBASE_STORAGE_BUCKET:-}"
FIREBASE_MESSAGING_SENDER_ID="${FIREBASE_MESSAGING_SENDER_ID:-}"
FIREBASE_APP_ID="${FIREBASE_APP_ID:-}"
FIREBASE_VAPID_KEY="${FIREBASE_VAPID_KEY:-}"

if [[ -n "${FIREBASE_API_KEY}" && -n "${FIREBASE_APP_ID}" && \
      -n "${FIREBASE_MESSAGING_SENDER_ID}" && -n "${FIREBASE_PROJECT_ID}" ]]; then
  AUTH_DOMAIN="${FIREBASE_AUTH_DOMAIN:-${FIREBASE_PROJECT_ID}.firebaseapp.com}"
  STORAGE_BUCKET="${FIREBASE_STORAGE_BUCKET:-${FIREBASE_PROJECT_ID}.appspot.com}"
  # Detect common misconfiguration: Android app id used for web build.
  if [[ "${FIREBASE_APP_ID}" == *":android:"* ]]; then
    echo "WARN: FIREBASE_APP_ID looks like an Android app id (:android:)."
    echo "WARN: Web Push needs a Firebase Web app id (:web:). Token registration may fail."
  fi
  sed \
    -e "s|__FIREBASE_API_KEY__|${FIREBASE_API_KEY}|g" \
    -e "s|__FIREBASE_AUTH_DOMAIN__|${AUTH_DOMAIN}|g" \
    -e "s|__FIREBASE_PROJECT_ID__|${FIREBASE_PROJECT_ID}|g" \
    -e "s|__FIREBASE_STORAGE_BUCKET__|${STORAGE_BUCKET}|g" \
    -e "s|__FIREBASE_MESSAGING_SENDER_ID__|${FIREBASE_MESSAGING_SENDER_ID}|g" \
    -e "s|__FIREBASE_APP_ID__|${FIREBASE_APP_ID}|g" \
    web/firebase-messaging-sw.js.template > web/firebase-messaging-sw.js
  echo "firebase-messaging-sw.js: populated for project ${FIREBASE_PROJECT_ID}"
else
  echo "firebase-messaging-sw.js: stub (FIREBASE_* build-args empty)"
fi

flutter build web --release \
  --dart-define="CORE_API_BASE=${CORE_API_BASE}" \
  --dart-define="FIREBASE_API_KEY=${FIREBASE_API_KEY}" \
  --dart-define="FIREBASE_AUTH_DOMAIN=${FIREBASE_AUTH_DOMAIN}" \
  --dart-define="FIREBASE_PROJECT_ID=${FIREBASE_PROJECT_ID}" \
  --dart-define="FIREBASE_STORAGE_BUCKET=${FIREBASE_STORAGE_BUCKET}" \
  --dart-define="FIREBASE_MESSAGING_SENDER_ID=${FIREBASE_MESSAGING_SENDER_ID}" \
  --dart-define="FIREBASE_APP_ID=${FIREBASE_APP_ID}" \
  --dart-define="FIREBASE_VAPID_KEY=${FIREBASE_VAPID_KEY}"

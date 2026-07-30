#!/usr/bin/env bash
# Internal closed-beta APK (docs/android-release.md).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT/mobile"

if [[ ! -f android/key.properties ]]; then
  echo "WARN: android/key.properties missing — release APK will use debug signing." >&2
  echo "      Copy android/key.properties.example for a real beta build." >&2
fi

flutter pub get
flutter build apk --release "$@"
echo
echo "APK: $ROOT/mobile/build/app/outputs/flutter-apk/app-release.apk"

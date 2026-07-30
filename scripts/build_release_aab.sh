#!/usr/bin/env bash
# Optional Play internal-testing bundle (docs/android-release.md).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT/mobile"

if [[ ! -f android/key.properties ]]; then
  echo "WARN: android/key.properties missing — AAB will use debug signing." >&2
fi

flutter pub get
flutter build appbundle --release "$@"
echo
echo "AAB: $ROOT/mobile/build/app/outputs/bundle/release/app-release.aab"

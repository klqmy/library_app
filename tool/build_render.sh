#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

sdk="$PWD/.render/flutter-3.35.4"
if [ ! -x "$sdk/bin/flutter" ]; then
  mkdir -p "$(dirname "$sdk")"
  git clone --depth 1 --branch 3.35.4 https://github.com/flutter/flutter.git "$sdk"
fi
export PATH="$sdk/bin:$PATH"
export CI=true
flutter config --no-analytics
flutter pub get
dart format --output=none --set-exit-if-changed lib test tool
flutter analyze --no-pub
flutter test --no-pub
node --test api/*.test.js
flutter build web --release --no-pub --base-href / \
  --dart-define=API_BASE_URL=/api \
  --no-web-resources-cdn --pwa-strategy=none
dart run tool/prepare_web.dart build/web --optimize

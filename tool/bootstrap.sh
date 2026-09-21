#!/usr/bin/env bash
set -e
command -v flutter >/dev/null || { echo "Flutter is not in PATH"; exit 1; }
cd "$(dirname "$0")/.."
if [ ! -d android ] || [ ! -d ios ]; then
  flutter create --platforms=android,ios,web --org com.scrptaty --project-name mundas .
fi
python3 tool/configure_platforms.py
flutter pub get
dart run flutter_launcher_icons
flutter run -d chrome --web-browser-flag="--disable-web-security"

#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

if ! command -v flutter >/dev/null 2>&1; then
  echo "Flutter is not installed or is not available in PATH."
  exit 1
fi

if [ ! -f android/app/build.gradle ] && [ ! -f android/app/build.gradle.kts ]; then
  flutter create --platforms=android --org com.driverent .
fi

if [ -f android/app/build.gradle.kts ]; then
  sed -i.bak 's/compileSdk = flutter.compileSdkVersion/compileSdk = 36/g' android/app/build.gradle.kts
  sed -i.bak 's/compileSdk = [0-9][0-9]*/compileSdk = 36/g' android/app/build.gradle.kts
fi
if [ -f android/app/build.gradle ]; then
  sed -i.bak 's/compileSdkVersion flutter.compileSdkVersion/compileSdkVersion 36/g' android/app/build.gradle
  sed -i.bak 's/compileSdkVersion [0-9][0-9]*/compileSdkVersion 36/g' android/app/build.gradle
fi

flutter clean
flutter pub get
flutter build apk --release --no-pub

echo "APK created at: build/app/outputs/flutter-apk/app-release.apk"

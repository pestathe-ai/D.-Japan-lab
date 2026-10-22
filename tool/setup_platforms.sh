#!/usr/bin/env bash
# Crea le cartelle android/ios (non salvate nel repo) e le personalizza.
set -euo pipefail
cd "$(dirname "$0")/.."

flutter create --project-name d_japan_lab --org dev.djapanlab --platforms=android,ios . >/dev/null
rm -f test/widget_test.dart

MANIFEST=android/app/src/main/AndroidManifest.xml
# Nome visibile dell'app
sed -i.bak 's/android:label="[^"]*"/android:label="D. Japan Lab"/' "$MANIFEST"
# Internet in release (flutter create lo mette solo in debug)
if ! grep -q 'android.permission.INTERNET' "$MANIFEST"; then
  sed -i.bak 's#<application#<uses-permission android:name="android.permission.INTERNET"/>\n    <application#' "$MANIFEST"
fi
rm -f "$MANIFEST.bak"

# minSdk 24 richiesto da webview_flutter
for f in android/app/build.gradle.kts android/app/build.gradle; do
  [ -f "$f" ] || continue
  sed -i.bak -E 's/minSdk( = |Version )flutter\.minSdkVersion/minSdk\1 24/' "$f"
  sed -i.bak -E 's/minSdk = 24/minSdk = 24/' "$f"
  rm -f "$f.bak"
done

if [[ "$(uname)" == "Darwin" ]]; then
  /usr/libexec/PlistBuddy -c "Set :CFBundleDisplayName D. Japan Lab" ios/Runner/Info.plist || true
  sed -i '' "s/^# platform :ios.*/platform :ios, '13.0'/" ios/Podfile 2>/dev/null || true
fi

flutter pub get
echo "--- manifest ---"; cat "$MANIFEST" | head -20
grep -n "minSdk" android/app/build.gradle* || true

#!/usr/bin/env bash
# 打包 IPA，产物放在 dist/。
#   ./scripts/build-ipa.sh            用开发证书签名（需要 Xcode 登录开发者账号）
#   UNSIGNED=1 ./scripts/build-ipa.sh 不签名，适合用 Sideloadly / AltStore 等工具自行签名安装
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION=$(sed -nE 's/.*MARKETING_VERSION: "(.*)"/\1/p' project.yml)
BUILD=$(sed -nE 's/.*CURRENT_PROJECT_VERSION: "(.*)"/\1/p' project.yml)
ARCHIVE=build/TimeToEat.xcarchive
mkdir -p dist

xcodegen generate --quiet
rm -rf "$ARCHIVE" build/export

if [[ "${UNSIGNED:-0}" == "1" ]]; then
  xcodebuild -project TimeToEat.xcodeproj -scheme TimeToEat -configuration Release \
    -destination 'generic/platform=iOS' -archivePath "$ARCHIVE" \
    CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" archive
  rm -rf build/Payload && mkdir -p build/Payload
  cp -R "$ARCHIVE/Products/Applications/TimeToEat.app" build/Payload/
  OUT="dist/TimeToEat-${VERSION}-${BUILD}-unsigned.ipa"
  (cd build && rm -f ../"$OUT" && zip -qry ../"$OUT" Payload)
else
  xcodebuild -project TimeToEat.xcodeproj -scheme TimeToEat -configuration Release \
    -destination 'generic/platform=iOS' -archivePath "$ARCHIVE" \
    -allowProvisioningUpdates archive
  xcodebuild -exportArchive -archivePath "$ARCHIVE" -exportPath build/export \
    -exportOptionsPlist scripts/ExportOptions.plist -allowProvisioningUpdates
  OUT="dist/TimeToEat-${VERSION}-${BUILD}.ipa"
  cp build/export/TimeToEat.ipa "$OUT"
fi

echo "✅ $OUT"

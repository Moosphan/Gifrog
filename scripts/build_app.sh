#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="Gifrog"

BUILD_CONFIG="release"
CI_MODE=false
for arg in "$@"; do
  case "$arg" in
    release|debug) BUILD_CONFIG="$arg" ;;
    --ci)          CI_MODE=true ;;
    *)             echo "Usage: build_app.sh [release|debug] [--ci]" >&2; exit 1 ;;
  esac
done

APP_DIR="$ROOT_DIR/dist/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"

if $CI_MODE; then
  SIGN_IDENTITY="-"
  BUNDLE_ID="com.gifrog.${APP_NAME}"
  echo "CI mode: ad-hoc signing, bundle ID $BUNDLE_ID"
else
  SIGN_IDENTITY=$(security find-identity -v -p codesigning 2>/dev/null | grep "Apple Development" | head -1 | sed 's/.*"\(.*\)".*/\1/')
  if [[ -z "$SIGN_IDENTITY" ]]; then
    echo "Error: No Apple Development signing identity found." >&2
    echo "Open Xcode → Settings → Accounts → add your Apple ID, then try again." >&2
    exit 1
  fi
  TEAM_ID=$(echo "$SIGN_IDENTITY" | grep -o '[A-Z0-9]\{10\}' | tail -1)
  BUNDLE_ID="com.${TEAM_ID}.${APP_NAME}"
fi

echo "Signing with: $SIGN_IDENTITY"
echo "Bundle ID: $BUNDLE_ID"

cd "$ROOT_DIR"
swift build -c "$BUILD_CONFIG"

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$CONTENTS_DIR/Resources"

cp "$ROOT_DIR/.build/arm64-apple-macosx/$BUILD_CONFIG/$APP_NAME" "$MACOS_DIR/$APP_NAME"
chmod +x "$MACOS_DIR/$APP_NAME"

# Copy SPM resource bundle into Contents/Resources so codesign seals it properly
cp -R "$ROOT_DIR/.build/arm64-apple-macosx/$BUILD_CONFIG/Gifrog_Gifrog.bundle" "$CONTENTS_DIR/Resources/"

# Build app icon from PNG
ICON_SRC="$ROOT_DIR/Sources/Gifrog/Resources/GifrogIcon.png"
ICONSET_DIR="$ROOT_DIR/.build/AppIcon.iconset"
rm -rf "$ICONSET_DIR"
mkdir -p "$ICONSET_DIR"
for size in 16 32 128 256 512; do
    sips -z $size $size "$ICON_SRC" --out "$ICONSET_DIR/icon_${size}x${size}.png" >/dev/null 2>&1
    double=$((size * 2))
    sips -z $double $double "$ICON_SRC" --out "$ICONSET_DIR/icon_${size}x${size}@2x.png" >/dev/null 2>&1
done
iconutil -c icns "$ICONSET_DIR" -o "$CONTENTS_DIR/Resources/AppIcon.icns"
rm -rf "$ICONSET_DIR"

cat > "$CONTENTS_DIR/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleExecutable</key>
  <string>Gifrog</string>
  <key>CFBundleIdentifier</key>
  <string>${BUNDLE_ID}</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>Gifrog</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>0.1.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>LSMinimumSystemVersion</key>
  <string>13.0</string>
  <key>LSUIElement</key>
  <true/>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>NSHighResolutionCapable</key>
  <true/>
  <key>NSHumanReadableCopyright</key>
  <string>Copyright © 2026 Gifrog.</string>
</dict>
</plist>
PLIST

printf 'APPL????' > "$CONTENTS_DIR/PkgInfo"

# Sign app bundle (Apple Development cert locally, ad-hoc in CI)
codesign --force --deep --sign "$SIGN_IDENTITY" "$APP_DIR"

echo "Built $APP_DIR"

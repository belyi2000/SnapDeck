#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "==> Building SnapDeck (release)"
swift build -c release -Xlinker -rpath -Xlinker @executable_path/../Frameworks
BIN_DIR="$(swift build -c release --show-bin-path)"

APP="$ROOT/dist/SnapDeck.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$APP/Contents/Frameworks"

cp "$BIN_DIR/SnapDeck" "$APP/Contents/MacOS/SnapDeck"
cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"
if [[ -f "$ROOT/Resources/AppIcon.icns" ]]; then
    cp "$ROOT/Resources/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
fi
printf 'APPL????' > "$APP/Contents/PkgInfo"

SPARKLE_FRAMEWORK="$(find "$ROOT/.build/artifacts" -path '*/Sparkle.framework' -type d | head -1)"
if [[ -z "$SPARKLE_FRAMEWORK" ]]; then
    echo "error: Sparkle.framework not found; run 'swift package resolve'" >&2
    exit 1
fi
# ditto keeps the framework's Versions symlinks and executable permissions.
ditto "$SPARKLE_FRAMEWORK" "$APP/Contents/Frameworks/Sparkle.framework"

codesign --force --sign - "$APP" >/dev/null

echo "==> Built $APP"
echo "    Open with: open '$APP'"

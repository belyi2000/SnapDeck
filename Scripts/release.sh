#!/bin/zsh
set -euo pipefail

# Builds, signs and publishes a SnapDeck release on GitHub.
#
#   ./Scripts/release.sh 0.6.1
#
# The DMG is for the first install, the ZIP is what Sparkle downloads.
# The signed appcast.xml is uploaded to every release and is served through
# https://github.com/<owner>/<repo>/releases/latest/download/appcast.xml

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

VERSION="${1:-}"
if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "usage: Scripts/release.sh <version>   e.g. Scripts/release.sh 0.6.1" >&2
    exit 1
fi

if ! gh auth status >/dev/null 2>&1; then
    echo "error: GitHub CLI is not authenticated; run 'gh auth login'" >&2
    exit 1
fi

if [[ -n "$(git status --porcelain)" ]]; then
    echo "error: working tree is not clean; commit or stash changes first" >&2
    git status --short
    exit 1
fi

REPO="$(gh repo view --json nameWithOwner -q .nameWithOwner)"
TAG="v$VERSION"
if git rev-parse "$TAG" >/dev/null 2>&1; then
    echo "error: tag $TAG already exists" >&2
    exit 1
fi

PLIST="Resources/Info.plist"
CURRENT_BUILD="$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$PLIST")"
BUILD=$((CURRENT_BUILD + 1))
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$PLIST"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD" "$PLIST"

./Scripts/build-app.sh

RELEASE_DIR="$ROOT/.release"
mkdir -p "$RELEASE_DIR"

ZIP="$RELEASE_DIR/SnapDeck-$VERSION.zip"
rm -f "$ZIP"
# Keep the .app at the archive root: Sparkle and app translocation rely on it.
ditto -c -k --sequesterRsrc --keepParent "$ROOT/dist/SnapDeck.app" "$ZIP"

NOTES="$RELEASE_DIR/SnapDeck-$VERSION.md"
if [[ ! -f "$NOTES" ]]; then
    PREV_TAG="$(git describe --tags --abbrev=0 2>/dev/null || true)"
    {
        echo "## SnapDeck $VERSION"
        echo
        if [[ -n "$PREV_TAG" ]]; then
            git log --pretty=format:"- %s" "$PREV_TAG..HEAD"
        else
            git log --pretty=format:"- %s" | head -30
        fi
        echo
    } > "$NOTES"
fi

SPARKLE_BIN="$ROOT/.build/artifacts/sparkle/Sparkle/bin"
if [[ ! -x "$SPARKLE_BIN/generate_appcast" ]]; then
    echo "error: Sparkle tools not found; run 'swift package resolve'" >&2
    exit 1
fi

# Deltas are disabled: they would need to be uploaded alongside the appcast.
"$SPARKLE_BIN/generate_appcast" \
    --download-url-prefix "https://github.com/$REPO/releases/download/$TAG/" \
    --embed-release-notes \
    --maximum-deltas 0 \
    --link "https://github.com/$REPO" \
    -o "$RELEASE_DIR/appcast.xml" \
    "$RELEASE_DIR"

DMG_DIR="$RELEASE_DIR/dmg"
mkdir -p "$DMG_DIR"
DMG="$DMG_DIR/SnapDeck-$VERSION.dmg"
STAGE="$DMG_DIR/dmg-stage-$VERSION"
rm -rf "$STAGE"
mkdir -p "$STAGE"
ditto "$ROOT/dist/SnapDeck.app" "$STAGE/SnapDeck.app"
ln -s /Applications "$STAGE/Applications"
rm -f "$DMG"
hdiutil create -quiet -volname "SnapDeck" -srcfolder "$STAGE" -ov -format UDZO "$DMG"
rm -rf "$STAGE"

SHA_FILE="$RELEASE_DIR/SHA256.txt"
shasum -a 256 "$ZIP" "$DMG" | sed "s|$RELEASE_DIR/||" > "$SHA_FILE"
cat "$SHA_FILE"

git add "$PLIST"
git commit -m "Release $VERSION"
git tag -a "$TAG" -m "SnapDeck $VERSION"
git push origin HEAD
git push origin "$TAG"

gh release create "$TAG" \
    "$ZIP" \
    "$DMG" \
    "$RELEASE_DIR/appcast.xml" \
    "$SHA_FILE" \
    --title "SnapDeck $VERSION" \
    --notes-file "$NOTES"

echo
echo "Released $TAG: https://github.com/$REPO/releases/tag/$TAG"
echo "Appcast:       https://github.com/$REPO/releases/latest/download/appcast.xml"

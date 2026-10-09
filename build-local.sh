#!/bin/sh
# Build Jumpcut locally without an Apple Developer team.
#
# The app is signed ad hoc. Sparkle ships as a prebuilt framework signed by
# its own team, and the hardened runtime refuses to load a framework whose
# Team ID differs from the app's, so the whole bundle is re-signed ad hoc
# after the build.
#
# Usage: ./build-local.sh [--install]
#   --install   copy the built app to /Applications

set -eu

cd "$(dirname "$0")"

DERIVED_DATA="build"
APP="$DERIVED_DATA/Build/Products/Release/Jumpcut.app"

xcodebuild \
    -project Jumpcut/Jumpcut.xcodeproj \
    -scheme Jumpcut \
    -configuration Release \
    -derivedDataPath "$DERIVED_DATA" \
    CODE_SIGN_IDENTITY=- \
    CODE_SIGNING_REQUIRED=NO \
    DEVELOPMENT_TEAM= \
    build

codesign --force --deep --sign - --preserve-metadata=entitlements "$APP"
codesign --verify --deep --strict "$APP"

echo "Built $APP"

if [ "${1:-}" = "--install" ]; then
    rm -rf /Applications/Jumpcut.app
    cp -R "$APP" /Applications/
    echo "Installed /Applications/Jumpcut.app"
fi

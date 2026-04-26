#!/bin/sh
set -eu

PROJECT="ColimaStack.xcodeproj"
SCHEME="ColimaStack"
DEBUG_DERIVED_DATA="${DEBUG_DERIVED_DATA:-/tmp/ColimaStackVerify-Debug}"
TEST_DERIVED_DATA="${TEST_DERIVED_DATA:-DerivedData}"
RELEASE_DERIVED_DATA="${RELEASE_DERIVED_DATA:-/tmp/ColimaStackVerify-Release}"
CLEAN_DERIVED_DATA="${CLEAN_DERIVED_DATA:-0}"

if [ "$CLEAN_DERIVED_DATA" = "1" ]; then
  rm -rf "$DEBUG_DERIVED_DATA"
  rm -rf "$TEST_DERIVED_DATA"
fi
rm -rf "$DEBUG_DERIVED_DATA"
rm -rf "$RELEASE_DERIVED_DATA"

xcodebuild build \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration Debug \
  -destination 'platform=macOS' \
  -derivedDataPath "$DEBUG_DERIVED_DATA" \
  CODE_SIGNING_ALLOWED=NO

xcodebuild test \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -destination 'platform=macOS' \
  -derivedDataPath "$TEST_DERIVED_DATA" \
  CODE_SIGNING_ALLOWED=NO

xcodebuild build \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -derivedDataPath "$RELEASE_DERIVED_DATA" \
  -jobs 1 \
  CODE_SIGNING_ALLOWED=NO

APP="$RELEASE_DERIVED_DATA/Build/Products/Release/ColimaStack.app"
lipo -archs "$APP/Contents/MacOS/ColimaStack"

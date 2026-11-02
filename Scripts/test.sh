#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
[ -f Vendor/whistle.cact ] || Scripts/fetch-vendor.sh
xcodegen generate
xcodebuild test -project GiveMeSub.xcodeproj -scheme GiveMeSub -destination 'platform=macOS' \
  CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY=- DEVELOPMENT_TEAM=

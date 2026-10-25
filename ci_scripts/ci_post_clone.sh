#!/usr/bin/env bash
set -euo pipefail
cd "${CI_PRIMARY_REPOSITORY_PATH:-$(cd "$(dirname "$0")/.." && pwd)}"
HOMEBREW_NO_AUTO_UPDATE=1 brew install xcodegen
Scripts/fetch-vendor.sh
if [[ -n "${CI_TAG:-}" ]]; then
  sed -i '' "s/MARKETING_VERSION:.*/MARKETING_VERSION: \"${CI_TAG#v}\"/" project.yml
fi
xcodegen generate

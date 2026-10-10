#!/usr/bin/env bash
input=$(cat)
grep -q '"stop_hook_active": *true' <<<"$input" && exit 0
set -uo pipefail

cd "${CLAUDE_PROJECT_DIR:-.}" || exit 0
[ -f ios/project.yml ] && cd ios
[ -z "$(git status --porcelain)" ] && exit 0

failures=""

if [ -f project.yml ] && { [ -n "$(git status --porcelain -- project.yml)" ] || ! compgen -G '*.xcodeproj' >/dev/null; }; then
  if command -v xcodegen >/dev/null; then
    output=$(xcodegen generate --quiet 2>&1) || failures+="xcodegen generate failed:"$'\n'"$output"$'\n'
  else
    echo "stop-check: xcodegen not installed, skipping project generation" >&2
  fi
fi

if command -v swiftlint >/dev/null; then
  output=$(swiftlint lint --strict --quiet 2>&1) || failures+="swiftlint failed:"$'\n'"$output"$'\n'
else
  echo "stop-check: swiftlint not installed, skipping lint" >&2
fi

if [ -n "$failures" ]; then
  printf '%s' "$failures" >&2
  exit 2
fi

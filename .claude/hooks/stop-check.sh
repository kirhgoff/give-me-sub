#!/usr/bin/env bash
input=$(cat)
grep -q '"stop_hook_active": *true' <<<"$input" && exit 0
set -uo pipefail

cd "${CLAUDE_PROJECT_DIR:-.}" || exit 0
[ -z "$(git status --porcelain)" ] && exit 0

if ! command -v mise >/dev/null; then
  echo "stop-check: mise not installed, skipping checks" >&2
  exit 0
fi

failures=""

if [ -n "$(git status --porcelain -- project.yml)" ] || ! compgen -G '*.xcodeproj' >/dev/null; then
  output=$(mise exec -- xcodegen generate --quiet 2>&1) || failures+="xcodegen generate failed:"$'\n'"$output"$'\n'
fi

output=$(mise run lint 2>&1) || failures+="mise run lint failed:"$'\n'"$output"$'\n'

if [ -n "$failures" ]; then
  printf '%s' "$failures" >&2
  exit 2
fi

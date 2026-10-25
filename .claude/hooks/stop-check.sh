#!/usr/bin/env bash
input=$(cat)
grep -q '"stop_hook_active": *true' <<<"$input" && exit 0
set -uo pipefail

cd "${CLAUDE_PROJECT_DIR:-.}" || exit 0
[ -z "$(git status --porcelain)" ] && exit 0

if ! output=$(mise run lint 2>&1); then
  printf 'mise run lint failed:\n%s\n' "$output" >&2
  exit 2
fi

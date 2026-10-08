#!/bin/zsh
set -euo pipefail
root=${0:A:h:h}
mkdir -p "$root/Vendor/needle"
curl -L --fail -o "$root/Vendor/needle/libneedle.a" https://huggingface.co/Cactus-Compute/needle3/resolve/main/macos-arm64/libneedle.a
curl -L --fail -o "$root/Vendor/needle/needle.h"    https://huggingface.co/Cactus-Compute/needle3/resolve/main/macos-arm64/needle.h
curl -L --fail -o "$root/Vendor/whistle.cact"       https://huggingface.co/Cactus-Compute/whistle/resolve/main/whistle.cact
ls -la "$root/Vendor/needle" "$root/Vendor/whistle.cact"

#!/bin/zsh
set -euo pipefail
root=${0:A:h:h}
needle_base=https://huggingface.co/Cactus-Compute/needle3/resolve/93e88ede867e4311c39151285e74df513e4b835b/macos-arm64
mkdir -p "$root/Vendor/needle"
fetch() {
  curl -L --fail -o "$1" "$2"
  [[ -z ${3:-} ]] || echo "$3  $1" | shasum -a 256 -c -
}
fetch "$root/Vendor/needle/libneedle.a" "$needle_base/libneedle.a" c1b955778dcb79c92efaf5606f94e9d3a4ed85e093096b41e502bc9748a90614
fetch "$root/Vendor/needle/needle.h"    "$needle_base/needle.h"    a27dac4b3239eead91d124b7f7dbce5495c13019903fd817b68c16d39b055a99
fetch "$root/Vendor/whistle.cact"       https://huggingface.co/Cactus-Compute/whistle/resolve/main/whistle.cact
ls -la "$root/Vendor/needle" "$root/Vendor/whistle.cact"

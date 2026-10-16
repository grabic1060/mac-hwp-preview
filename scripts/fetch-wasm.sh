#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p .build/wasm
archive=.build/wasm/rhwp-core-0.8.7.tgz
hash=30e8a17400583570afec9169baeef3f0785e023e2a51344ed44eb8539a60e6a6
if ! test -f "$archive" || ! echo "$hash  $archive" | shasum -a 256 -c - >/dev/null 2>&1; then
 curl -fL --retry 2 https://registry.npmjs.org/@rhwp/core/-/core-0.8.7.tgz -o "$archive"
fi
echo "$hash  $archive" | shasum -a 256 -c -
tar -xzf "$archive" -C .build/wasm

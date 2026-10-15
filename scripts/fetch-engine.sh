#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
case "$(uname -m)" in
 arm64) arch=aarch64; hash=6ed46aa63f6d10c447842999f73abc59cf9586c5645fefc5e763bd6a6d43662d ;;
 x86_64) arch=x86_64; hash=07b1a5ea570e410d1b52b4d848a94f00c64674e84004883c62efad7daab61da4 ;;
 *) exit 1 ;;
esac
mkdir -p .build/engine
archive=.build/engine/rhwp.tar.gz
if ! test -f "$archive" || ! echo "$hash  $archive" | shasum -a 256 -c - >/dev/null 2>&1; then
 curl --fail --location --retry 2 "https://github.com/edwardkim/rhwp/releases/download/v0.8.7/rhwp-v0.8.7-macos-$arch.tar.gz" -o "$archive"
fi
echo "$hash  $archive" | shasum -a 256 -c -
tar -xzf "$archive" -C .build/engine
.build/engine/rhwp/rhwp --version

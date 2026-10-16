#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
app=${1:-"$PWD/.build/app/HWP Preview.app"}
codesign --verify --deep --strict "$app"
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$app"
for name in Preview Thumbnail; do
    pluginkit -a "$app/Contents/PlugIns/$name.appex"
done
pluginkit -e use -i org.hwp-preview.app.preview
pluginkit -e use -i org.hwp-preview.app.thumbnail

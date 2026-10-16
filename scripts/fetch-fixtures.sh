#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p .build/fixtures
# Local evaluation only: third-party documents are not redistributed with the app.
base=https://raw.githubusercontent.com/edwardkim/rhwp/v0.8.7
curl -fLsS "$base/samples/basic/BookReview.hwp" -o .build/fixtures/book.hwp
curl -fLsS "$base/rhwp-studio/public/samples/form-002.hwpx" -o .build/fixtures/form.hwpx
curl -fLsS "$base/samples/test-image.hwpx" -o .build/fixtures/image.hwpx
shasum -a 256 -c <<'HASHES'
042aeac46996c035dfb6ce83e8b383dd66f7ae5377281d9c797917ba1b1d7d8f  .build/fixtures/book.hwp
5ab8f7c368e02538f75f1cd2bd82bbd8de2f925a54ba7b38ec9395b2cdb804d4  .build/fixtures/form.hwpx
4405f89db156da688d1a10ae0c0829f0159ad24ad4ad5e083902577a8304338a  .build/fixtures/image.hwpx
HASHES

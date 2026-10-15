#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p .build/fixtures
# Local evaluation only: third-party documents are not redistributed with the app.
base=https://raw.githubusercontent.com/edwardkim/rhwp/v0.8.7
curl -fLsS "$base/samples/basic/BookReview.hwp" -o .build/fixtures/book.hwp
curl -fLsS "$base/rhwp-studio/public/samples/form-002.hwpx" -o .build/fixtures/form.hwpx

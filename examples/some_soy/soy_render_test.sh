#!/bin/bash
set -e

readonly OUT=$($TEST_SRCDIR/build_bazel_rules_typescript/examples/some_soy/some_soy)
if [ "$OUT" != "<h1>Hello, World</h1>" ]; then
  echo "Expected output '<h1>Hello, World</h1>' but was $OUT"
  exit 1
fi

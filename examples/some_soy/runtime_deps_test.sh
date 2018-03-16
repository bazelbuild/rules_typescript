#!/bin/bash
set -e

readonly OUT=$($TEST_SRCDIR/build_bazel_rules_typescript/examples/some_soy/runtime_deps)
if [ "$OUT" != "true" ]; then
  echo "Expected output 'true' but was $OUT"
  exit 1
fi

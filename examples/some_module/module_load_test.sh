#!/bin/bash
set -e

MANIFEST="$TEST_SRCDIR/MANIFEST"
if [ -e "${MANIFEST}" ]; then
  while read line; do
    declare -a PARTS=($line)
    if [ "${PARTS[0]}" == "build_bazel_rules_typescript/examples/some_module/bin" ]; then
      readonly OUT=$(${PARTS[1]})
    fi
  done < ${MANIFEST}
else
  readonly OUT=$($TEST_SRCDIR/build_bazel_rules_typescript/examples/some_module/bin)
fi

if [ "$OUT" != "hello world" ]; then
  echo "Expected output 'hello world' but was $OUT"
  exit 1
fi

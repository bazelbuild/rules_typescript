#!/bin/bash
set -e

# should not down-level ES2015 syntax, eg. `class`
readonly GREETER_JS=$(cat $TEST_SRCDIR/build_bazel_rules_typescript/examples/es6_output/es6_output_lib.prod/build_bazel_rules_typescript/examples/es6_output/greeter.js)
if [[ "$GREETER_JS" != *"class Greeter"* ]]; then
  echo "Expected greeter.js to contain 'class Greeter' but was"
  echo "$GREETER_JS"
  exit 1
fi

# should have native ES Module format
readonly MAIN_JS=$(cat $TEST_SRCDIR/build_bazel_rules_typescript/examples/es6_output/es6_output_lib.prod/build_bazel_rules_typescript/examples/es6_output/main.js)
if [[ "$MAIN_JS" != *"import { Greeter }"* ]]; then
  echo "Expected main.js to contain 'import { Greeter }' but was"
  echo "$MAIN_JS"
  exit 1
fi

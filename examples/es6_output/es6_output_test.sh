#!/bin/bash
set -e

MANIFEST="$TEST_SRCDIR/MANIFEST"
if [ -e "$MANIFEST" ]; then
  while read line; do
    declare -a PARTS=($line)
    if [ "${PARTS[0]}" == "build_bazel_rules_typescript/examples/es6_output/es6_output.es6/examples/foo.js" ]; then
      readonly FOO_JS=$(cat ${PARTS[1]})
    elif [ "${PARTS[0]}" == "build_bazel_rules_typescript/examples/es6_output/es6_output.es6/examples/some_library/library.js" ]; then
      readonly LIBRARY_JS=$(cat ${PARTS[1]})
    fi
  done < $MANIFEST
else
  readonly FOO_JS=$(cat $TEST_SRCDIR/build_bazel_rules_typescript/examples/es6_output/es6_output.es6/examples/foo.js)
  readonly LIBRARY_JS=$(cat $TEST_SRCDIR/build_bazel_rules_typescript/examples/es6_output/es6_output.es6/examples/some_library/library.js)
fi

# should not down-level ES2015 syntax, eg. `class`
if [[ "$FOO_JS" != *"class Greeter"* ]]; then
  echo "Expected foo.js to contain 'class Greeter' but was"
  echo "$FOO_JS"
  exit 1
fi

# should not down-level ES2015 syntax, eg. `class`
readonly LIBRARY_JS=$(cat $TEST_SRCDIR/build_bazel_rules_typescript/examples/es6_output/es6_output.es6/examples/some_library/library.js)
if [[ "$LIBRARY_JS" != *"export const cool = 1;"* ]]; then
  echo "Expected library.js to contain 'export const cool = 1;' but was"
  echo "$LIBRARY_JS"
  exit 1
fi

# should not down-level dynamic import
readonly BAR_JS=$(cat $TEST_SRCDIR/build_bazel_rules_typescript/examples/es6_output/es6_output.es6/examples/bar.js)
if [[ "$BAR_JS" != *"import('./foo')"* ]]; then
  echo "Expected bar.js to contain 'import('./foo')' but was"
  echo "$BAR_JS"
  exit 1
fi

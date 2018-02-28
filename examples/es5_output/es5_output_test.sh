#!/bin/bash
set -e

MANIFEST="$TEST_SRCDIR/MANIFEST"
if [ -e "$MANIFEST" ]; then
  while read line; do
    declare -a PARTS=($line)
    if [ "${PARTS[0]}" == "build_bazel_rules_typescript/examples/some_library/library.js" ]; then
      readonly LIBRARY_JS=$(cat ${PARTS[1]})
    elif [ "${PARTS[0]}" == "build_bazel_rules_typescript/examples/bar.js" ]; then
      readonly BAR_JS=$(cat ${PARTS[1]})
    elif [ "${PARTS[0]}" == "build_bazel_rules_typescript/examples/foo.js" ]; then
      readonly FOO_JS=$(cat ${PARTS[1]})
    fi
  done < $MANIFEST
else
  readonly LIBRARY_JS=$(cat $TEST_SRCDIR/build_bazel_rules_typescript/examples/some_library/library.js)
  readonly BAR_JS=$(cat $TEST_SRCDIR/build_bazel_rules_typescript/examples/bar.js)
  readonly FOO_JS=$(cat $TEST_SRCDIR/build_bazel_rules_typescript/examples/foo.js)
fi

# should produce named UMD modules
if [[ "$LIBRARY_JS" != *"define(\"build_bazel_rules_typescript/examples/some_library/library\""* ]]; then
  echo "Expected library.js to declare named module, but was"
  echo "$LIBRARY_JS"
  exit 1
fi

# should produce named UMD modules
if [[ "$BAR_JS" != *"define(\"build_bazel_rules_typescript/examples/bar\""* ]]; then
  echo "Expected bar.js to declare named module, but was"
  echo "$BAR_JS"
  exit 1
fi

# should give a name to required modules
if [[ "$BAR_JS" != *"require(\"build_bazel_rules_typescript/examples/foo\")"* ]]; then
  echo "Expected bar.js to require named module foo, but was"
  echo "$BAR_JS"
  exit 1
fi

# should give a name to required modules from other compilation unit
if [[ "$BAR_JS" != *"require(\"build_bazel_rules_typescript/examples/some_library/library\")"* ]]; then
  echo "Expected bar.js to require named module library, but was"
  echo "$BAR_JS"
  exit 1
fi

# should give a name to required generated modules without bazel-bin
if [[ "$BAR_JS" != *"require(\"build_bazel_rules_typescript/examples/generated_ts/foo\")"* ]]; then
  echo "Expected bar.js to require generated named module foo, but was"
  echo "$BAR_JS"
  exit 1
fi

# should not give a module name to external modules
if [[ "$BAR_JS" != *"require(\"typescript\")"* ]]; then
  echo "Expected bar.js to require typescript by its original name, but was"
  echo "$BAR_JS"
  exit 1
fi

# should produce named UMD modules
if [[ "$FOO_JS" != *"define(\"build_bazel_rules_typescript/examples/foo\""* ]]; then
  echo "Expected foo.js to declare named module, but was"
  echo "$FOO_JS"
  exit 1
fi

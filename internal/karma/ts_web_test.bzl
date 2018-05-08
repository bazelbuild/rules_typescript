# Copyright 2017 The Bazel Authors. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
"Unit testing in with Karma"

load("@build_bazel_rules_nodejs//internal:node.bzl",
    "sources_aspect",
    "expand_path_into_runfiles",
)
load("@build_bazel_rules_nodejs//internal/js_library:js_library.bzl", "write_amd_names_shim")

_CONF_TMPL = "//internal/karma:karma.conf.js"

def _ts_web_test_impl(ctx):
  conf = ctx.actions.declare_file(
      "%s.conf.js" % ctx.label.name,
      sibling=ctx.outputs.executable)

  files = depset(ctx.files.srcs)
  for d in ctx.attr.deps:
    if hasattr(d, "node_sources"):
      files += d.node_sources
    elif hasattr(d, "files"):
      files += d.files

  # The files in the bootstrap attribute come before the require.js support.
  # Note that due to frameworks = ['jasmine'], a few scripts will come before
  # the bootstrap entries:
  # build_bazel_rules_typescript_karma_deps/node_modules/jasmine-core/lib/jasmine-core/jasmine.js
  # build_bazel_rules_typescript_karma_deps/node_modules/karma-jasmine/lib/boot.js
  # build_bazel_rules_typescript_karma_deps/node_modules/karma-jasmine/lib/adapter.js
  # This is desired so that the bootstrap entries can patch jasmine, as zone.js does.
  bootstrap_entries = [
      expand_path_into_runfiles(ctx, f.short_path)
      for f in ctx.files.bootstrap
  ]

  amd_names_shim = ctx.actions.declare_file(
      "_%s.amd_names_shim.js" % ctx.label.name,
      sibling = ctx.outputs.executable)
  write_amd_names_shim(ctx.actions, amd_names_shim, ctx.attr.bootstrap)

  # Explicitly list the requirejs library files here, rather than use
  # `frameworks: ['requirejs']`
  # so that we control the script order, and the bootstrap files come before
  # require.js.
  # That allows bootstrap files to have anonymous AMD modules, or to do some
  # polyfilling before test libraries load.
  # See https://github.com/karma-runner/karma/issues/699
  bootstrap_entries += [
    "build_bazel_rules_typescript_karma_deps/node_modules/requirejs/require.js",
    "build_bazel_rules_typescript_karma_deps/node_modules/karma-requirejs/lib/adapter.js",
    "/".join([ctx.workspace_name, amd_names_shim.short_path]),
  ]
  # Finally we load the user's srcs and deps
  user_entries = [
      expand_path_into_runfiles(ctx, f.short_path)
      for f in files
  ]

  # root-relative (runfiles) path to the directory containing karma.conf
  config_segments = len(conf.short_path.split("/"))

  ctx.actions.expand_template(
      output = conf,
      template =  ctx.file._conf_tmpl,
      substitutions = {
          "TMPL_runfiles_path": "/".join([".."] * config_segments),
          "TMPL_bootstrap_files": "\n".join(["      '%s'," % e for e in bootstrap_entries]),
          "TMPL_user_files": "\n".join(["      '%s'," % e for e in user_entries]),
          "TMPL_workspace_name": ctx.workspace_name,
      })

  karma_executable_path = ctx.executable._karma.short_path
  if karma_executable_path.startswith('..'):
    karma_executable_path = "external" + karma_executable_path[2:]

  ctx.actions.write(
      output = ctx.outputs.executable,
      is_executable = True,
      content = """#!/usr/bin/env bash
MANIFEST="$TEST_SRCDIR/MANIFEST"
if [ -e "$MANIFEST" ]; then
  while read line; do
    declare -a PARTS=($line)
    if [ "${{PARTS[0]}}" == "build_bazel_rules_typescript/{TMPL_karma}" ]; then
      readonly KARMA=${{PARTS[1]}}
    elif [ "${{PARTS[0]}}" == "build_bazel_rules_typescript/{TMPL_conf}" ]; then
      readonly CONF=${{PARTS[1]}}
    fi
  done < $MANIFEST
else
  readonly KARMA={TMPL_karma}
  readonly CONF={TMPL_conf}
fi

export HOME=$(mktemp -d)
ARGV=( "start" $CONF )

# Detect that we are running as a test, by using a well-known environment
# variable. See go/test-encyclopedia
if [ ! -z "$TEST_TMPDIR" ]; then
  ARGV+=( "--single-run" )
fi

$KARMA ${{ARGV[@]}}
""".format(TMPL_karma = karma_executable_path,
           TMPL_conf = conf.short_path))
  return [DefaultInfo(
      files = depset([ctx.outputs.executable]),
      runfiles = ctx.runfiles(
          files = ctx.files.srcs + ctx.files.deps + ctx.files.bootstrap + [
              conf, amd_names_shim
          ],
          transitive_files = files,
          # Propagate karma_bin and its runfiles
          collect_data = True,
          collect_default = True,
      ),
      executable = ctx.outputs.executable,
  )]

ts_web_test = rule(
    implementation = _ts_web_test_impl,
    test = True,
    executable = True,
    attrs = {
        "srcs": attr.label_list(
            doc = "JavaScript source files",
            allow_files = [".js"]),
        "deps": attr.label_list(
            doc = "Other targets which produce JavaScript such as `ts_library`",
            allow_files = True,
            aspects = [sources_aspect],
        ),
        "bootstrap": attr.label_list(
            doc = """JavaScript files to include *before* the module loader (require.js).
            For example, you can include Reflect,js for TypeScript decorator metadata reflection,
            or UMD bundles for third-party libraries.""",
            allow_files = [".js"],
        ),
        "data": attr.label_list(
            doc = "Runtime dependencies",
            cfg = "data"),
        "_karma": attr.label(
            default = Label("//internal/karma:karma_bin"),
            executable = True,
            cfg = "data",
            single_file = False,
            allow_files = True),
        "_conf_tmpl": attr.label(
            default = Label(_CONF_TMPL),
            allow_files = True, single_file = True),
    },
)
"""Runs unit tests in a browser.

When executed under `bazel test`, this uses a headless browser for speed.
This is also because `bazel test` allows multiple targets to be tested together,
and we don't want to open a Chrome window on your machine for each one. Also,
under `bazel test` the test will execute and immediately terminate.

Running under `ibazel test` gives you a "watch mode" for your tests. The rule is
optimized for this case - the test runner server will stay running and just
re-serve the up-to-date JavaScript source bundle.

To debug a single test target, run it with `bazel run` instead. This will open a
browser window on your computer. Also you can use any other browser by opening
the URL printed when the test starts up. The test will remain running until you
cancel the `bazel run` command.

Currently this rule uses Karma as the test runner, but this is an implementation
detail. We might switch to another runner like Jest in the future.
"""
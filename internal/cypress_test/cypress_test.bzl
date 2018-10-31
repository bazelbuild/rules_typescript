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

"""NodeJS testing

These rules let you run tests outside of a browser. This is typically faster
than launching a test in Karma, for example.
"""
load("@build_bazel_rules_nodejs//:defs.bzl", "nodejs_test")
load("@build_bazel_rules_nodejs//internal/common:devmode_js_sources.bzl", "devmode_js_sources")

def _impl(ctx):
  cypressjson_content = "{ \"integrationFolder\": \".\", \"video\": false, \"screenshots\": false, \"supportFile\": false }"
  ctx.actions.write(output = ctx.outputs.cypressjson, content = cypressjson_content)

  files = depset(ctx.files.srcs)
  for d in ctx.attr.deps:
    if hasattr(d, "node_sources"):
      files += d.node_sources
    elif hasattr(d, "files"):
      files += d.files

  cypress_executable_path = ctx.executable.cypress.short_path
  # if cypress_executable_path.startswith('..'):
  #   cypress_executable_path = "external" + cypress_executable_path[2:]

  # print(cypress_executable_path)

  ctx.actions.write(
      output = ctx.outputs.executable,
      is_executable = True,
      content = """#!/usr/bin/env bash
readonly CYPRESS={TMPL_cypress}

$CYPRESS open

  """.format(TMPL_cypress = cypress_executable_path))

  print(ctx.files)

  return [DefaultInfo(
      runfiles = ctx.runfiles(
          files = ctx.files.srcs + ctx.files.deps + ctx.files.cypress,
          transitive_files = files,
          # Propagate karma_bin and its runfiles
          collect_data = True,
          collect_default = True,
      ),
  )]

cypress_test = rule (
  implementation = _impl,
  test = True,
  # executable = True,
  outputs = {"cypressjson": "cypress.json"},
  attrs = {
    "deps": attr.label_list(),
    "srcs": attr.label_list(
            doc = "JavaScript source files",
            allow_files = [".js"]),
    "data": attr.label_list(
      doc = "Runtime dependencies",
      cfg = "data"),
    "cypress": attr.label(
      default = Label("//tools/cypress-rule:cypress_bin"),
        executable = True,
        cfg = "data",
        single_file = False,
        allow_files = True
    ),
  }
)

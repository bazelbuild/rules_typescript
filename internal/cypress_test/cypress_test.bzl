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

def cypress_test(
  name,
  srcs = [],
  data = [],
  deps = [],
  tags = [],
  expected_exit_code = 0,
  **kwargs):
  """Runs tests in NodeJS using the Jasmine test runner.

  To debug the test, see debugging notes in `nodejs_test`.

  Args:
    name: name of the resulting label
    srcs: JavaScript source files containing Jasmine specs
    data: Runtime dependencies which will be loaded while the test executes
    deps: Other targets which produce JavaScript, such as ts_library
    expected_exit_code: The expected exit code for the test. Defaults to 0.
    **kwargs: remaining arguments are passed to the test rule
  """
  devmode_js_sources(
      name = "%s_devmode_srcs" % name,
      deps = srcs + deps,
      # testonly = 1,
  )

  all_data = data + srcs + deps
  all_data += [Label("//internal/cypress_test:cypress_runner.js")]
  all_data += [":%s_devmode_srcs.MF" % name]
  # all_data += [Label("@bazel_tools//tools/bash/runfiles")]
  entry_point = "build_bazel_rules_typescript/internal/cypress_test/cypress_runner.js"
  # disabled due to https://github.com/cypress-io/cypress/issues/1925
  # tags = tags + ["ibazel_notify_changes"]

  nodejs_test(
      name = name,
      tags = tags,
      data = all_data,
      entry_point = entry_point,
      templated_args = ["$(location :%s_devmode_srcs.MF)" % name],
      # testonly = 1,
      expected_exit_code = expected_exit_code,
      **kwargs
  )

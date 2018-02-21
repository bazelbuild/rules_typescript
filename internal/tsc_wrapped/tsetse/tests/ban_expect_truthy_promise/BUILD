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

licenses(["notice"])  # Apache 2.0

load("//:defs.bzl", "ts_library")

error_message = "error TS21224: Value passed.*"

ts_library(
    name = "jasmine",
    testonly = 1,
    srcs = [
        "jasmine_types.ts",
    ],
)

ts_library(
    name = "positives",
    testonly = 1,
    tsconfig = "//internal/tsc_wrapped:tsconfig.json",
    srcs = [
        "positives.ts",
    ],
    expected_diagnostics = [
        "\(29,5\).*" + error_message,
        "\(30,5\).*" + error_message,
        "\(31,5\).*" + error_message,
        "\(32,5\).*" + error_message,
        "\(33,5\).*" + error_message,
        "\(34,5\).*" + error_message,
        "\(35,5\).*" + error_message,
    ],
    deps = [
        ":jasmine",
    ],
)

# FIXME: not sure why this is broken after the tsetse workaround
# Failure is:
# ERROR: rules_typescript/internal/tsc_wrapped/tsetse/tests/ban_expect_truthy_promise/BUILD:51:1: Compiling TypeScript (devmode) //internal/tsc_wrapped/tsetse/tests/ban_expect_truthy_promise:negatives failed (Exit 1)
# internal/tsc_wrapped/tsetse/tests/ban_expect_truthy_promise/negatives.ts(10,1): error TS21224: Value passed to expect() is of type Promise<number>, which is thenable. Promises are always truthy. Either use toBe(true) or await the value.
#        See http://tsetse.info/ban-expect-truthy-promise
# ts_library(
#     name = "negatives",
#     testonly = 1,
#     tsconfig = "//internal/tsc_wrapped:tsconfig.json",
#     srcs = [
#         "negatives.ts",
#     ],
#     deps = [
#         ":jasmine",
#     ],
# )

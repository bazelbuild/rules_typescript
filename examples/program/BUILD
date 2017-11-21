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

package(default_visibility = ["//visibility:public"])

load("//:defs.bzl", "ts_library")

load("@build_bazel_rules_nodejs//:defs.bzl", "nodejs_binary")

ts_library(
    name = "ts_library",
    srcs = ["main.ts"],
    module_name = "ts_library",
)

filegroup(name = "node_modules", srcs = glob(["node_modules/**/*"]))

# Run this command via `bazel run //examples/program`
# To pass flags to the nodejs binary use -- as a delemiter 
# between flags for bazel and flags for the program.
# ex. `bazel run //exmaple/program -- -C -P`
nodejs_binary(
    name = "program",
    # Cause ts_library to be transpiled into ES5.
    data = [":ts_library"],
    # ts_library transpiles .ts files within WORKSPACE_NAME/path/to/file.js
    entry_point = "build_bazel_rules_typescript/examples/program/main.js",
    # Make node_modules availbile at runtime.
    node_modules = ":node_modules",
)

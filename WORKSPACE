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

workspace(name = "build_bazel_rules_typescript")

git_repository(
    name = "build_bazel_rules_nodejs",
    remote = "https://github.com/bazelbuild/rules_nodejs",
    commit = "6b498e36095350bd88d2ea89e1a87ce791e51d82",
)

load("@build_bazel_rules_nodejs//:defs.bzl", "node_repositories")

# Install a hermetic version of node.
# After this is run, these labels will be available:
# - The nodejs install:
#   @build_bazel_rules_typescript_node//:bin/node
#   @build_bazel_rules_typescript_node//:bin/npm
# - The yarn package manager:
#   @yarn//:yarn
node_repositories(package_json = ["//:package.json"])

load("@build_bazel_rules_typescript//:setup.bzl", "ts_setup_workspace")

ts_setup_workspace()

http_archive(
    name = "io_bazel_rules_go",
    url = "https://github.com/bazelbuild/rules_go/releases/download/0.7.1/rules_go-0.7.1.tar.gz",
    sha256 = "341d5eacef704415386974bc82a1783a8b7ffbff2ab6ba02375e1ca20d9b031c",
)

load("@io_bazel_rules_go//go:def.bzl", "go_rules_dependencies", "go_register_toolchains")

go_rules_dependencies()

go_register_toolchains()

git_repository(
    name = "io_bazel_rules_closure",
    commit = "172f84fe96e07214fa7337b081648d4a61b45b93",
    remote = "https://github.com/bazelbuild/rules_closure",
)

load("@io_bazel_rules_closure//closure:defs.bzl", "closure_repositories")

closure_repositories()

git_repository(
    name = "angular",
    commit = "d7f4f50f1346e23b7b11407fdc775b06e55a7bfd",
    remote = "https://github.com/angular/bazel-builds.git",
)

git_repository(
    name = "io_bazel_rules_sass",
    remote = "https://github.com/bazelbuild/rules_sass.git",
    tag = "0.0.3",
)

load("@io_bazel_rules_sass//sass:sass.bzl", "sass_repositories")

sass_repositories()

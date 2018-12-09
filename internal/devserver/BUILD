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

package(default_visibility = ["//visibility:public"])

load("@bazel_tools//tools/build_defs/pkg:pkg.bzl", "pkg_tar")

exports_files([
    # Exported to be consumed for generating skydoc.
    "ts_devserver.bzl",
])

filegroup(
    name = "source_tree",
    srcs = glob(["**/*"]),
)

pkg_tar(
  name = "package",
  srcs = [
    "ts_devserver.bzl",
    "BUILD",
    "yarn.lock",
    "package.json",
  ],
  package_dir = "devserver",
)

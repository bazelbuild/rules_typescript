# Copyright 2018 The Bazel Authors. All rights reserved.
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

"""Package file which defines build dependencies
"""

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

def rules_typescript_dev_dependencies():
    """
    Fetch dependencies needed for local development.

    These are in this file to keep version information in one place, and make the WORKSPACE
    shorter.

    Also this allows other repos to reference our sources with local_repository and install the needed deps.
    """

    _maybe(
        http_archive,
        name = "build_bazel_rules_nodejs",
        sha256 = "cb6d92c93a1769205d6573c21363bdbdcf5831af114a7fbc3f800b8598207dee",
        urls = ["https://github.com/bazelbuild/rules_nodejs/releases/download/2.0.0-rc.2/rules_nodejs-2.0.0-rc.2.tar.gz"],
    )

    # For protocol buffers
    _maybe(
        http_archive,
        name = "io_bazel",
        urls = ["https://github.com/bazelbuild/bazel/releases/download/0.25.0/bazel-0.25.0-dist.zip"],
        sha256 = "f624fe9ca8d51de192655369ac538c420afb7cde16e1ad052554b582fff09287",
    )

    # For building ts_devserver binary
    # See https://github.com/bazelbuild/rules_go#setup for the latest version.
    # Cannot update to https://github.com/bazelbuild/rules_go/releases/tag/v0.23.00 as this changes
    # where go devserver binaries are outputed to and breaks the devserver.
    _maybe(
        http_archive,
        name = "io_bazel_rules_go",
        sha256 = "7b9bbe3ea1fccb46dcfa6c3f3e29ba7ec740d8733370e21cdc8937467b4a4349",
        urls = [
            "https://mirror.bazel.build/github.com/bazelbuild/rules_go/releases/download/v0.22.4/rules_go-v0.22.4.tar.gz",
            "https://github.com/bazelbuild/rules_go/releases/download/v0.22.4/rules_go-v0.22.4.tar.gz",
        ],
    )

    _maybe(
        http_archive,
        name = "com_google_protobuf",
        sha256 = "98e615d592d237f94db8bf033fba78cd404d979b0b70351a9e5aaff725398357",
        strip_prefix = "protobuf-3.9.1",
        urls = ["https://github.com/protocolbuffers/protobuf/archive/v3.9.1.tar.gz"],
    )

    # go_repository is defined in bazel_gazelle
    _maybe(
        http_archive,
        name = "bazel_gazelle",
        sha256 = "cdb02a887a7187ea4d5a27452311a75ed8637379a1287d8eeb952138ea485f7d",
        urls = [
            "https://mirror.bazel.build/github.com/bazelbuild/bazel-gazelle/releases/download/v0.21.1/bazel-gazelle-v0.21.1.tar.gz",
            "https://github.com/bazelbuild/bazel-gazelle/releases/download/v0.21.1/bazel-gazelle-v0.21.1.tar.gz",
        ],
    )

def _maybe(repo_rule, name, **kwargs):
    if not native.existing_rule(name):
        repo_rule(name = name, **kwargs)

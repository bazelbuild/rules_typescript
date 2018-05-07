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

"Install toolchain dependencies"

load("@build_bazel_rules_nodejs//:defs.bzl", "yarn_install")
load("//internal/karma:browser_repository.bzl", "browser_repository")

def ts_setup_workspace():
  """This repository rule should be called from your WORKSPACE file.

  It creates some additional Bazel external repositories that are used internally
  by the TypeScript rules.
  """
  yarn_install(
      name = "build_bazel_rules_typescript_tsc_wrapped_deps",
      package_json = "@build_bazel_rules_typescript//internal:tsc_wrapped/package.json",
      yarn_lock = "@build_bazel_rules_typescript//internal:tsc_wrapped/yarn.lock",
  )
  yarn_install(
      name = "build_bazel_rules_typescript_devserver_deps",
      package_json = "@build_bazel_rules_typescript//internal/devserver:package.json",
      yarn_lock = "@build_bazel_rules_typescript//internal/devserver:yarn.lock",
  )

  yarn_install(
      name = "build_bazel_rules_typescript_karma_deps",
      package_json = "@build_bazel_rules_typescript//internal/karma:package.json",
      yarn_lock = "@build_bazel_rules_typescript//internal/karma:yarn.lock",
  )

  yarn_install(
      name = "build_bazel_rules_typescript_protobufs_compiletime_deps",
      package_json = "@build_bazel_rules_typescript//internal/protobufjs:package.json",
      yarn_lock = "@build_bazel_rules_typescript//internal/protobufjs:yarn.lock",
  )

  browser_repository(
      name="build_bazel_rules_typescript_chromium",
      amd64_sha256="51a189382cb5272d240a729da0ae77d0211c1bbc0d10b701a2723b5b068c1e3a",
      amd64_urls=[
          "http://commondatastorage.googleapis.com/chromium-browser-snapshots/Linux_x64/539259/chrome-linux.zip"
      ],
      macos_sha256="866ec9aa4e07cc86ae1d5aeb6e9bdafb5f94989c7c0be661302930ad667f41f3",
      macos_urls=[
          "http://commondatastorage.googleapis.com/chromium-browser-snapshots/Mac/539251/chrome-mac.zip"
      ],
      windows_sha256="be4fcc7257d85c12ae2de10aef0150ddbb7b9ecbd5ada6a898d247cf867a058a",
      windows_urls=[
          "http://commondatastorage.googleapis.com/chromium-browser-snapshots/Win_x64/539249/chrome-win32.zip"
      ])

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

"""The ts_devserver rule brings up our "getting started" devserver under
`bazel run`.
"""

load("@build_bazel_rules_nodejs//internal:node.bzl", "expand_location_into_runfiles")

def _ts_devserver(ctx):
  serving_arg = ""
  if ctx.attr.serving_path:
    serving_arg = "-serving_path=%s" % ctx.attr.serving_path
  # FIXME: more bash dependencies makes Windows support harder
  ctx.actions.write(
      output = ctx.outputs.executable,
      is_executable = True,
      content = """#!/bin/sh
# TODO: change to $(rootpath :devserver) after bazel#2475 lands
external/build_bazel_rules_typescript/internal/devserver/devserver {0} \
  -base "$PWD" \
  -packages={1} \
  -manifest={2}
# NB: manifest needs to look up one dir, because runfiles path includes workspace
# but the PWD also includes the workspace
# FIXME: that seems wrong
""".format(serving_arg, ctx.label.package,
    expand_location_into_runfiles(ctx, ctx.attr.manifest)))
  return [DefaultInfo(
      runfiles = ctx.runfiles(
          files = [ctx.executable._devserver] + ctx.files.static_files,
          # FIXME: understand why
          transitive_files = depset(ctx.files.data),
          collect_data = True,
          collect_default = True,
      )
  )]

ts_devserver = rule(
    implementation = _ts_devserver,
    attrs = {
        "manifest": attr.string(mandatory = True),
        "serving_path": attr.string(),
        "data": attr.label_list(allow_files = True, cfg = "data"),
        "static_files": attr.label_list(allow_files = True),
        "_devserver": attr.label(
            default = Label("//internal/devserver"),
            executable = True,
            cfg = "host",
        ),
    },
    executable = True,
)

def ts_devserver_macro(manifest, data = [], **kwargs):
  ts_devserver(
      data = data + [manifest],
      manifest = "$(location %s)" % manifest,
      tags = ["IBAZEL_MAGIC_TAG"],
      **kwargs
  )
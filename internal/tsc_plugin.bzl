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

"Extend the TypeScript compiler"

load("@build_bazel_rules_nodejs//internal:node.bzl", "sources_aspect")

TscPlugin = provider(
    doc = "Plugin to tsc",
    fields = {
        "entry_point": """What path should be require'd by tsc_wrapped.
            A path starting with "/" is interpreted as execroot-relative""",
        "node_sources": "Files to include in action inputs of tsc_wrapped",
    },
)

def _basename(p):
    for ext in [".d.ts", ".tsx", ".ts", ".js"]:
        if p.endswith(ext):
            return p[:-len(ext)]
    return p

def _tsc_plugin_impl(ctx):
    # Collect the outputs of the sources_aspect to get devmode JS files
    node_sources = depset(transitive = [p.node_sources for p in ctx.attr.deps])

    # Requested entry point is a label in the user space, and might point to a .ts file
    requested_entry_point = "/".join([ctx.attr.entry_point.label.package, ctx.attr.entry_point.label.name])

    # Iterate the devmode JS files we collected from the plugin deps to find
    # the entry point file.
    # We need to map from the users input to a file in the execroot
    entry_point = None
    for f in node_sources:
        if _basename(f.short_path) == _basename(requested_entry_point):
            if entry_point:
                fail("Multiple files in the deps have the requested entry_point")
            # Leading slash means the plugin is rooted at the execroot
            entry_point = "/" + f.path
    if not entry_point:
        fail("Entry point not found")

    return [
        TscPlugin(
            entry_point = entry_point,
            node_sources = node_sources,
        ),
    ]

tsc_plugin = rule(
    implementation = _tsc_plugin_impl,
    attrs = {
      "entry_point": attr.label(allow_single_file = True),
      "deps": attr.label_list(
            aspects = [sources_aspect],
      ),
    }
)

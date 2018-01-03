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

"""Create a node module that can be required as require('module_name').
"""

def _internal_node_module(ctx):
  main_file = ctx.actions.declare_file("node_modules/%s/index.js" % ctx.attr.import_path)
  ctx.actions.expand_template(
    output = main_file,
    template = ctx.file.main,
    substitutions = {}
  )
  return struct(closure_js_library = struct(srcs = [main_file]))

internal_node_module = rule(
    attrs = {
        "main": attr.label(
            allow_single_file = True,
            mandatory = True,
        ),
        "import_path": attr.string(mandatory = True),
    },
    implementation = _internal_node_module,
)

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

"""Renames outputted .closure.js files to be .js files so that ES6
module loading can work properly using the closure_js_binary rule
from rules_closure.
"""

load("@io_bazel_rules_closure//closure:defs.bzl", "closure_js_binary")    

def _reroot_closure_files_impl(ctx):
  rerooted_es6_srcs = depset()

  for dep in ctx.attr.deps:
    if hasattr(dep, "typescript"):
      for es6_src in dep.typescript.transitive_es6_srcs:
        rerooted_es6_src = ctx.actions.declare_file(
          "%s/%s" % (
            es6_src.dirname, 
            es6_src.basename.replace(".closure", "")))
        ctx.actions.expand_template(
          output = rerooted_es6_src,
          template = es6_src,
          substitutions = {}
        )
        rerooted_es6_srcs += [rerooted_es6_src]
    elif hasattr(dep, "closure_js_library"):
      rerooted_es6_srcs += dep.closure_js_library.srcs
    else:
      fail(
          ("%s is neither a TypeScript nor a Closure JS library producing rule." % dep.label) +
          "\nDependencies must be ts_library, ts_declaration, or closure_js_library.")
    
  return struct(closure_js_library = struct(srcs = rerooted_es6_srcs))


_reroot_closure_files = rule(
    attrs = {"deps": attr.label_list(mandatory = True)},
    implementation = _reroot_closure_files_impl,
)


def closure_ts_binary(name, deps, **kwargs):
    rerooted_name = name + "_reroot_closure_files"

    _reroot_closure_files(name = rerooted_name, deps = deps)

    closure_js_binary(name = name, deps = [":" + rerooted_name], **kwargs)

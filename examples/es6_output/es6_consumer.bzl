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

"""Example of a rule that requires ES6 inputs.
"""

load("//:internal/common/reroot_prod_files.bzl", "reroot_prod_files")

def _es6_consumer(ctx):
  rerooted_prod_files = reroot_prod_files(ctx)

  return [DefaultInfo(
      files = rerooted_prod_files,
      runfiles = ctx.runfiles(rerooted_prod_files.to_list()),
  )]

es6_consumer = rule(
    implementation = _es6_consumer,
    attrs = {
        "deps": attr.label_list()
    }
)

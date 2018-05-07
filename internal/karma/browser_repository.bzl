# Copyright 2016 The Closure Rules Authors. All rights reserved.
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
"""Downloads browser files based on local platform."""

def _impl(repository_ctx):
  if repository_ctx.os.name.lower().startswith("mac os"):
    urls = repository_ctx.attr.macos_urls
    sha256 = repository_ctx.attr.macos_sha256
  elif repository_ctx.os.name.lower().startswith("windows"):
    urls = repository_ctx.attr.windows_urls
    sha256 = repository_ctx.attr.windows_sha256
  else:
    urls = repository_ctx.attr.amd64_urls
    sha256 = repository_ctx.attr.amd64_sha256
  basename = urls[0][urls[0].rindex("/") + 1:]
  repository_ctx.download(urls, basename, sha256)
  repository_ctx.symlink(basename, "file/" + basename)
  repository_ctx.file(
      "file/BUILD", "\n".join([
          ("# DO NOT EDIT: automatically generated BUILD file for " +
           "browser_repository rule " + repository_ctx.name),
          "filegroup(",
          "    name = 'file',",
          "    srcs = ['%s']," % basename,
          "    visibility = ['//visibility:public'],",
          ")",
      ]))

browser_repository = repository_rule(
    implementation = _impl,
    attrs = {
        "amd64_urls": attr.string_list(),
        "amd64_sha256": attr.string(),
        "macos_urls": attr.string_list(),
        "macos_sha256": attr.string(),
        "windows_urls": attr.string_list(),
        "windows_sha256": attr.string(),
    },
)

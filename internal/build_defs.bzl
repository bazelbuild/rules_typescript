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

"""TypeScript rules.
"""
# pylint: disable=unused-argument
# pylint: disable=missing-docstring
load(":common/compilation.bzl", "COMMON_ATTRIBUTES", "compile_ts", "ts_providers_dict_to_struct")
load(":executables.bzl", "get_tsc")
# This is created by the ts_repositories() repository rule
load("@build_bazel_rules_typescript_install//:tsconfig.bzl", "get_default_tsconfig")
load(":common/tsconfig.bzl", "create_tsconfig")
load(":ts_config.bzl", "TsConfigInfo")
load("//:internal/common/collect_es6_sources.bzl", "collect_es6_sources")
load("@io_bazel_rules_closure//closure:defs.bzl", "closure_js_binary")    

def _compile_action(ctx, inputs, outputs, config_file_path):
  externs_files = []
  non_externs_files = []
  for output in outputs:
    if output.basename.endswith(".es5.MF"):
      ctx.file_action(output, content="")
    else:
      non_externs_files.append(output)

  action_inputs = inputs + [f for f in ctx.files.node_modules + ctx.files._tsc_wrapped_deps
                            if f.path.endswith(".ts") or f.path.endswith(".json")]
  if ctx.file.tsconfig:
    action_inputs += [ctx.file.tsconfig]
    if TsConfigInfo in ctx.attr.tsconfig:
      action_inputs += ctx.attr.tsconfig[TsConfigInfo].deps

  # One at-sign makes this a params-file, enabling the worker strategy.
  # Two at-signs escapes the argument so it's passed through to tsc_wrapped
  # rather than the contents getting expanded.
  if ctx.attr.supports_workers:
    arguments = ["@@" + config_file_path]
    mnemonic = "TypeScriptCompile"
  else:
    arguments = ["-p", config_file_path]
    mnemonic = "tsc"

  outputs = non_externs_files
  if not outputs:
    return

  ctx.action(
      progress_message = "Compiling TypeScript (devmode) %s" % ctx.label,
      mnemonic = mnemonic,
      inputs = action_inputs,
      outputs = outputs,
      arguments = arguments,
      executable = ctx.executable.compiler,
      execution_requirements = {
          "supports-workers": str(int(ctx.attr.supports_workers)),
      },
  )


def _devmode_compile_action(ctx, inputs, outputs, config_file_path):
  _compile_action(ctx, inputs, outputs, config_file_path)

def tsc_wrapped_tsconfig(ctx,
                         files,
                         srcs,
                         devmode_manifest=None,
                         jsx_factory=None,
                         **kwargs):
  """Produce a tsconfig.json that sets options required under Bazel.
  """

  # The location of tsconfig.json is interpreted as the root of the project
  # when it is passed to the TS compiler with the `-p` option:
  #   https://www.typescriptlang.org/docs/handbook/tsconfig-json.html.
  # Our tsconfig.json is in bazel-foo/bazel-out/local-fastbuild/bin/{package_path}
  # because it's generated in the execution phase. However, our source files are in
  # bazel-foo/ and therefore we need to strip some parent directories for each
  # f.path.

  config = create_tsconfig(ctx, files, srcs,
                           devmode_manifest=devmode_manifest,
                           **kwargs)
  config["bazelOptions"]["nodeModulesPrefix"] = "/".join([p for p in [
    ctx.attr.node_modules.label.workspace_root,
    ctx.attr.node_modules.label.package,
    "node_modules"
  ] if p])

  if config["compilerOptions"]["target"] == "es6":
    config["compilerOptions"]["module"] = "es2015"
  else:
    # The "typescript.es5_sources" provider is expected to work
    # in both nodejs and in browsers.
    # NOTE: tsc-wrapped will always name the enclosed AMD modules
    config["compilerOptions"]["module"] = "umd"

  # If the user gives a tsconfig attribute, the generated file should extend
  # from the user's tsconfig.
  # See https://github.com/Microsoft/TypeScript/issues/9876
  # We subtract the ".json" from the end before handing to TypeScript because
  # this gives extra error-checking.
  if ctx.file.tsconfig:
    workspace_path = config["compilerOptions"]["rootDir"]
    config["extends"] = "/".join([workspace_path, ctx.file.tsconfig.path[:-len(".json")]])

  if jsx_factory:
    config["compilerOptions"]["jsxFactory"] = jsx_factory

  return config

# ************ #
# ts_library   #
# ************ #

def _ts_library_impl(ctx):
  """Implementation of ts_library.

  Args:
    ctx: the context.

  Returns:
    the struct returned by the call to compile_ts.
  """
  ts_providers = compile_ts(ctx, is_library=True,
                            compile_action=_compile_action,
                            devmode_compile_action=_devmode_compile_action,
                            tsc_wrapped_tsconfig=tsc_wrapped_tsconfig)
  return ts_providers_dict_to_struct(ts_providers)

ts_library = rule(
    _ts_library_impl,
    attrs = dict(COMMON_ATTRIBUTES, **{
        "srcs":
            attr.label_list(
                allow_files=FileType([
                    ".ts",
                    ".tsx",
                ]),
                mandatory=True,),

        # TODO(alexeagle): reconcile with google3: ts_library rules should
        # be portable across internal/external, so we need this attribute
        # internally as well.
        "tsconfig":
            attr.label(
                default = get_default_tsconfig(),
                allow_files = True,
                single_file = True),
        "compiler":
            attr.label(
                default=get_tsc(),
                single_file=False,
                allow_files=True,
                executable=True,
                cfg="host"),
        "supports_workers": attr.bool(default = True),
        "_tsc_wrapped_deps": attr.label(default = Label("@build_bazel_rules_typescript_deps//:node_modules")),
        # @// is special syntax for the "main" repository
        # The default assumes the user specified a target "node_modules" in their
        # root BUILD file.
        "node_modules": attr.label(default = Label("@//:node_modules")),
    }),
    outputs = {
        "tsconfig": "%{name}_tsconfig.json"
    }
)

# Helper that compiles typescript libraries using the vanilla tsc compiler
# Only used in Bazel - this file is not intended for use with Blaze.
def tsc_library(**kwargs):
  ts_library(
      supports_workers = False,
      compiler = "//internal/tsc_wrapped:tsc",
      node_modules = "@build_bazel_rules_typescript_deps//:node_modules",
      **kwargs)

# ******************* #
# closure_ts_binary   #
# ******************* #
def _collect_es6_sources_impl(ctx):
  """Rule which wraps the rerooted_prod_files action for rules_closure.

  Args:
    ctx: the context.

  Returns:
    A closure_js_library with the rerooted files.
  """
  rerooted_prod_files = collect_es6_sources(ctx)

  js_module_roots = depset()
  for prod_file in rerooted_prod_files:
    if "node_modules/" in prod_file.dirname:
      js_module_roots += [prod_file.dirname[:prod_file.dirname.find('node_modules/')]]

  return struct(
    files = rerooted_prod_files,
    closure_js_library = struct(
      srcs = rerooted_prod_files,
      js = [

      ],
      js_module_roots = js_module_roots
  ))

_collect_es6_sources = rule(
    attrs = {"deps": attr.label_list(mandatory = True)},
    implementation = _collect_es6_sources_impl,
)

def closure_ts_binary(name, deps, **kwargs):
  _collect_es6_sources_label = name + "_collect_es6_sources"
  _collect_es6_sources(name = _collect_es6_sources_label, deps = deps)

  closure_js_binary(
    name = name,
    deps = [":" + _collect_es6_sources_label],
    **kwargs
  )

def closure_ng_binary(name, workspace_name, defs = [], **kwargs):
  rerooted_node_modules_path = "**/%s_collect_es6_sources.es6/node_modules" % name

  rerooted_workspace_root = "%s/%s" % (rerooted_node_modules_path, workspace_name)
  rxjs_path = "%s/rxjs" % rerooted_node_modules_path

  closure_ts_binary(
    name = name, 
    defs = defs + [
        # jscomp_off flags needed for libraries which examine 
        # global variables (ie typeof module === "undefined"). 
        "--jscomp_off=undefinedVars",
        # jscomp_off flags needed specifically for RXJS
        # TODO(mrmeku): Investigate whether these flags are needed from a tsickle bug.
        "--jscomp_off=checkTypes",
        "--jscomp_off=misplacedTypeAnnotation",
        "--jscomp_off=unusedLocalVariables",
        "--jscomp_off=jsdocMissingType",

        ### @angular Dependencies 
        "--js=node_modules/zone.js/dist/zone_externs.js",
        "--js=node_modules/hammerjs/hammer.js",
        "--js=%s/**.js" % rxjs_path,

        ### @angular packages
        "--package_json_entry_names=es2015",
        "--js=node_modules/@angular/**/package.json",
        "--js=node_modules/@angular/core/esm2015/core.js",
        "--js=node_modules/@angular/common/esm2015/common.js",
        "--js=node_modules/@angular/platform-browser/esm2015/platform-browser.js",

        ### All other rerooted Typescript files in the users workspace.
        "--js=%s/**.js" % rerooted_workspace_root,
        "--js=!%s/**.ngsummary.js" % rerooted_workspace_root,
    ],
    manually_specify_js = True,
    **kwargs
  )

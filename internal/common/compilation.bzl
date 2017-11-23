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

"""Used for compilation by the different implementations of build_defs.bzl.
"""

load(":common/module_mappings.bzl", "module_mappings_aspect")
load(":common/json_marshal.bzl", "json_marshal")
load("@io_bazel_rules_closure//closure/private:defs.bzl", "collect_js")

BASE_ATTRIBUTES = dict()

DEPS_ASPECTS = [
    module_mappings_aspect,
]

# Attributes shared by any typescript-compatible rule (ts_library, ng_module)
COMMON_ATTRIBUTES = dict(BASE_ATTRIBUTES, **{
    "deps": attr.label_list(aspects = DEPS_ASPECTS),
    "data": attr.label_list(
        default = [],
        allow_files = True,
        cfg = "data",
    ),
    # TODO(evanm): make this the default and remove the option.
    "runtime": attr.string(default = "browser"),
    # Used to determine module mappings
    "module_name": attr.string(),
    "module_root": attr.string(),
    # TODO(radokirov): remove this attr when clutz is stable enough to consume
    # any closure JS code.
    "runtime_deps": attr.label_list(
        default = [],
        providers = ["js"],
    ),
    # Override _additional_d_ts to specify google3 stdlibs
    "_additional_d_ts": attr.label_list(
        allow_files = True,
    ),
    # Whether to generate externs.js from any "declare" statement.
    "generate_externs": attr.bool(default = True),
    # A list of diagnostics expected when compiling this library, in the form of
    # "diagnostic:regexp", e.g. "TS1234:failed to quizzle the .* wobble".
    # Useful to test for expected compilation errors.
    "expected_diagnostics": attr.string_list(),
})

COMMON_OUTPUTS = {
    # Allow the tsconfig.json to be generated without running compile actions.
    "tsconfig": "%{name}_tsconfig.json",
}

# TODO(plf): Enforce this at analysis time.
def assert_js_or_typescript_deps(ctx):
  for dep in ctx.attr.deps:
    if not hasattr(dep, "typescript") and not hasattr(dep, "js"):
      fail(
          ("%s is neither a TypeScript nor a JS producing rule." % dep.label) +
          "\nDependencies must be ts_library, ts_declaration, or " +
          # TODO(plf): Leaving this here for now, but this message does not
          # make sense in opensource.
          "JavaScript library rules (js_library, pinto_library, etc, but " +
          "also proto_library and some others).\n")

# Deep flag controls whether we grab d.ts's from ts_libraries that are imported
# by js libraries (which usually use clutz to create a single .d.ts for their
# entire set of transitive dependencies).
def _collect_transitive_dts(ctx, deep=True):
  all_deps_declarations = depset()
  type_blacklisted_declarations = depset()
  for extra in ctx.files._additional_d_ts:
    all_deps_declarations += depset([extra])
  for dep in ctx.attr.deps + getattr(ctx.attr, '_helpers', []):
    if hasattr(dep, "typescript"):
      all_deps_declarations += dep.typescript.transitive_declarations
      type_blacklisted_declarations += dep.typescript.type_blacklisted_declarations
    else:
      if deep and hasattr(dep, "clutz_transitive_dts"):
        all_deps_declarations += dep.clutz_transitive_dts
  return struct(
      transitive_declarations=all_deps_declarations,
      type_blacklisted_declarations=type_blacklisted_declarations
  )

def _outputs(ctx, label):
  """Returns closure js, devmode js, and .d.ts output files.

  Args:
    ctx: ctx.
    label: Label. package label.
  Returns:
    A struct of file lists for different output types.
  """
  workspace_segments = label.workspace_root.split("/") if label.workspace_root else []
  package_segments = label.package.split("/") if label.package else []
  trim = len(workspace_segments) + len(package_segments)
  closure_js_files = []
  devmode_js_files = []
  declaration_files = []
  for input_file in ctx.files.srcs:
    if (input_file.short_path.endswith(".d.ts")):
      continue
    basename = "/".join(input_file.short_path.split("/")[trim:])
    dot = basename.rfind(".")
    basename = basename[:dot]
    closure_js_files += [ctx.new_file(basename + ".closure.js")]
    devmode_js_files += [ctx.new_file(basename + ".js")]
    declaration_files += [ctx.new_file(basename + ".d.ts")]
  return struct(
    closure_js = closure_js_files,
    devmode_js = devmode_js_files,
    declarations = declaration_files,
  )

def compile_ts(ctx,
               is_library,
               extra_dts_files=[],
               compile_action=None,
               devmode_compile_action=None,
               jsx_factory=None,
               tsc_wrapped_tsconfig=None,
               outputs=_outputs):
  """Creates actions to compile TypeScript code.

  This rule is shared between ts_library and ts_declaration.

  Args:
    ctx: ctx.
    is_library: boolean. False if only compiling .dts files.
    extra_dts_files: list. Additional dts files to pass for compilation,
      not included in the transitive closure of declarations.
    compile_action: function. Creates the compilation action.
    devmode_compile_action: function. Creates the compilation action
      for devmode.
    jsx_factory: optional string. Enables overriding jsx pragma.
    tsc_wrapped_tsconfig: function that produces a tsconfig object.
    outputs: function from a ctx to the expected compilation outputs.
  Returns:
    struct that will be returned by the rule implementation.
  """
  assert_js_or_typescript_deps(ctx)

  ### Collect srcs and outputs.
  srcs = ctx.files.srcs
  src_declarations = []  # d.ts found in inputs.
  tsickle_externs = []  # externs.js generated by tsickle, if any.
  has_sources = False

  # Validate the user inputs.
  for src in ctx.attr.srcs:
    if src.label.package != ctx.label.package:
      # Sources can be in sub-folders, but not in sub-packages.
      fail("Sources must be in the same package as the ts_library rule, " +
           "but %s is not in %s" % (src.label, ctx.label.package), "srcs")

    for f in src.files:
      has_sources = True
      if not is_library and not f.path.endswith(".d.ts"):
          fail("srcs must contain only type declarations (.d.ts files), " +
               "but %s contains %s" % (src.label, f.short_path), "srcs")
      if f.path.endswith(".d.ts"):
        src_declarations += [f]
        continue

  outs = outputs(ctx, ctx.label)
  transpiled_closure_js = outs.closure_js
  transpiled_devmode_js = outs.devmode_js
  gen_declarations = outs.declarations

  if has_sources and ctx.attr.runtime != "nodejs":
    # Note: setting this variable controls whether tsickle is run at all.
    tsickle_externs = [ctx.new_file(ctx.label.name + ".externs.js")]

  transitive_dts = _collect_transitive_dts(ctx)
  input_declarations = transitive_dts.transitive_declarations + src_declarations
  type_blacklisted_declarations = transitive_dts.type_blacklisted_declarations
  if not is_library and not ctx.attr.generate_externs:
    type_blacklisted_declarations += ctx.files.srcs

  # The list of output files. These are the files that are always built
  # (including e.g. if you "blaze build :the_target" directly).
  files = depset()

  # A manifest listing the order of this rule's *.ts files (non-transitive)
  # Only generated if the rule has any sources.
  devmode_manifest = None

  # Enable to produce a performance trace when compiling TypeScript to JS.
  # The trace file location will be printed as a build result and can be read
  # in Chrome's chrome://tracing/ UI.
  perf_trace = False

  compilation_inputs = input_declarations + extra_dts_files + srcs
  tsickle_externs_path = tsickle_externs[0] if tsickle_externs else None

  # Calculate allowed dependencies for strict deps enforcement.
  allowed_deps = depset()
  allowed_deps += srcs[:]  # A target's sources may depend on each other.
  for dep in ctx.attr.deps:
    if hasattr(dep, "typescript"):
      allowed_deps += dep.typescript.declarations
  allowed_deps += extra_dts_files

  tsconfig_es6 = tsc_wrapped_tsconfig(
      ctx,
      compilation_inputs,
      srcs,
      jsx_factory=jsx_factory,
      tsickle_externs=tsickle_externs_path,
      type_blacklisted_declarations=type_blacklisted_declarations,
      allowed_deps=allowed_deps)
  # Do not produce declarations in ES6 mode, tsickle cannot produce correct
  # .d.ts (or even errors) from the altered Closure-style JS emit.
  tsconfig_es6["compilerOptions"]["declaration"] = False
  tsconfig_es6["compilerOptions"].pop("declarationDir")
  outputs = transpiled_closure_js + tsickle_externs
  if perf_trace:
    perf_trace_file = ctx.new_file(ctx.label.name + ".es6.trace")
    tsconfig_es6["bazelOptions"]["perfTracePath"] = perf_trace_file.path
    outputs.append(perf_trace_file)
    files += [perf_trace_file]
  ctx.file_action(output=ctx.outputs.tsconfig,
                  content=json_marshal(tsconfig_es6))

  # Parameters of this compiler invocation in case we need to replay this with different
  # settings for I18N.
  replay_params = None

  if has_sources:
    inputs = compilation_inputs + [ctx.outputs.tsconfig]
    replay_params = compile_action(ctx, inputs, outputs, ctx.outputs.tsconfig.path)

    devmode_manifest = ctx.new_file(ctx.label.name + ".es5.MF")
    tsconfig_json_es5 = ctx.new_file(ctx.label.name + "_es5_tsconfig.json")
    outputs = (
        transpiled_devmode_js + gen_declarations + [devmode_manifest])
    tsconfig_es5 = tsc_wrapped_tsconfig(ctx,
                                        compilation_inputs,
                                        srcs,
                                        jsx_factory=jsx_factory,
                                        devmode_manifest=devmode_manifest.path,
                                        allowed_deps=allowed_deps)
    if perf_trace:
      perf_trace_file = ctx.new_file(ctx.label.name + ".es5.trace")
      tsconfig_es5["bazelOptions"]["perfTracePath"] = perf_trace_file.path
      outputs.append(perf_trace_file)
      files += [perf_trace_file]
    ctx.file_action(output=tsconfig_json_es5, content=json_marshal(
        tsconfig_es5))
    inputs = compilation_inputs + [tsconfig_json_es5]
    devmode_compile_action(ctx, inputs, outputs, tsconfig_json_es5.path)

  # TODO(martinprobst): Merge the generated .d.ts files, and enforce strict
  # deps (do not re-export transitive types from the transitive closure).
  transitive_decls = input_declarations + gen_declarations

  if is_library:
    es6_sources = depset(transpiled_closure_js + tsickle_externs)
    es5_sources = depset(transpiled_devmode_js)
  else:
    es6_sources = depset(tsickle_externs)
    es5_sources = depset(tsickle_externs)
    devmode_manifest = None

  # Downstream rules see the .d.ts files produced or declared by this rule.
  declarations = depset()
  declarations += gen_declarations
  declarations += src_declarations
  if not srcs:
    # Re-export sources from deps.
    # TODO(b/30018387): introduce an "exports" attribute.
    for dep in ctx.attr.deps:
      if hasattr(dep, "typescript"):
        declarations += dep.typescript.declarations
  files += declarations

  # If this is a ts_declaration, add tsickle_externs to the outputs list to
  # force compilation of d.ts files.  (tsickle externs are produced by running a
  # compilation over the d.ts file and extracting type information.)
  if not is_library:
    files += depset(tsickle_externs)

  rerooted_es6_sources = []
  es6_js_modules_roots = []

  for source in es6_sources:
    root = source.dirname
    es6_js_modules_roots.append(root)

    file_path = "%s/%s" % (root, source.basename.replace(".closure", ""))
    rooted_file = ctx.actions.declare_file(file_path)

    ctx.actions.expand_template(
        output = rooted_file,
        template = source,
        substitutions = {}
    )
    rerooted_es6_sources.append(rooted_file)

  js = collect_js(ctx, ctx.attr.deps)

  return {
      "files": files,
      "runfiles": ctx.runfiles(
          # Note: don't include files=... here, or they will *always* be built
          # by any dependent rule, regardless of whether it needs them.
          # But these attributes are needed to pass along any input runfiles:
          collect_default=True,
          collect_data=True,
      ),
      # All of the subproviders below are considered optional and MUST be
      # accessed using getattr(x, y, default). See collect_js() in
      # @io_bazel_rules_closure//closure/private/defs.bzl.
      "closure_js_library": struct(
          # NestedSet<File> of all JavaScript source File artifacts in the
          # transitive closure. These files MUST be JavaScript.
          srcs= js.srcs + rerooted_es6_sources,
          # NestedSet<String> of all execroot path prefixes in the transitive
          # closure. For very simple projects, it will be empty. It is useful
          # for getting rid of Bazel generated directories, workspace names,
          # etc. out of module paths.  It contains the cartesian product of
          # generated roots, external repository roots, and includes
          # prefixes. This is passed to JSCompiler via the --js_module_root
          # flag. See find_js_module_roots() in
          # @io_bazel_rules_closure//closure/private/defs.bzl
          js_module_roots= js.js_module_roots + es6_js_modules_roots,
      ),
      # TODO(martinprobst): Prune transitive deps, only re-export what's needed.
      "typescript": {
          "declarations": declarations,
          "transitive_declarations": transitive_decls,
          "es6_sources": es6_sources,
          "es5_sources": es5_sources,
          "devmode_manifest": devmode_manifest,
          "type_blacklisted_declarations": type_blacklisted_declarations,
          "tsickle_externs": tsickle_externs,
          "replay_params": replay_params,
      },
      # Expose the tags so that a Skylark aspect can access them.
      "tags": ctx.attr.tags,
      "instrumented_files": {
          "extensions": ["ts"],
          "source_attributes": ["srcs"],
          "dependency_attributes": ["deps", "runtime_deps"],
      },
  }

# Converts a dict to a struct, recursing into a single level of nested dicts.
# This allows users of compile_ts to modify or augment the returned dict before
# converting it to an immutable struct.
def ts_providers_dict_to_struct(d):
  for key, value in d.items():
    if type(value) == type({}):
      d[key] = struct(**value)
  return struct(**d)

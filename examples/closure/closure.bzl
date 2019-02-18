load("@io_bazel_rules_closure//closure:defs.bzl", "CLOSURE_JS_TOOLCHAIN_ATTRS", "create_closure_js_library")

default_ts_suppress = [
    "checkTypes",
    "strictCheckTypes",
    "reportUnknownTypes",
    "analyzerChecks",
    "JSC_EXTRA_REQUIRE_WARNING",
    "unusedLocalVariables",
]

def _closure_ts_import(ctx):
    js_deps = []
    # TODO: get runtime_deps from ts_library
    js_sources = depset(transitive = [dep.typescript.transitive_es6_sources for dep in ctx.attr.deps]).to_list()
    suppress = ctx.attr.suppress + default_ts_suppress
    js_library = create_closure_js_library(ctx, js_sources, js_deps, [], suppress)
    return struct(
        files=depset([]),
        runfiles=ctx.runfiles(files=js_sources, collect_default=True, collect_data=True),
        exports=js_library.exports,
        closure_js_library=js_library.closure_js_library,
    )

closure_ts_import = rule(
    implementation = _closure_ts_import,
    attrs = dict({
        "deps": attr.label_list(providers = ["typescript"]),
        "suppress": attr.string_list(),
    }, **CLOSURE_JS_TOOLCHAIN_ATTRS),
)

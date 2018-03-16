def _closure_aspect_impl(target, ctx):
    """Generate typescript providers for closure_js_libraries"""
    if hasattr(target, 'typescript'):
        return []
    if not(hasattr(target, 'closure_js_library')):
        return []
    direct_typings = [target.clutz_dts]
    srcs = ctx.rule.files.srcs        

    deps = getattr(ctx.rule.attr, 'deps', [])
    exports = getattr(ctx.rule.attr, 'exports', [])
    decls = depset(direct_typings,transitive=[dep.typescript.declarations for dep in exports])
    transitive_deps = [dep.typescript.declarations for dep in deps]
    transitive_decls = depset(direct_typings, transitive=transitive_deps)
    # transitive_decls = depset(direct_typings+ctx.files._clutz_root_decls, transitive=transitive_deps)
    transitive_es6_srcs = depset(srcs, transitive=[dep.typescript.transitive_es6_sources for dep in deps])
    transitive_es5_srcs = depset(srcs, transitive=[dep.typescript.transitive_es5_sources for dep in deps])
    return struct(
        typescript=struct(
            declarations=decls,
            transitive_declarations=transitive_decls,
            es6_srcs=depset(srcs),
            transitive_es6_sources=transitive_es6_srcs,
            es5_sources=depset(srcs),
            transitive_es5_sources=transitive_es5_srcs,
            type_blacklisted_declarations=depset(transitive=[dep.typescript.type_blacklisted_declarations for dep in deps]),
            runtime_deps=depset(transitive=[d.typescript.runtime_deps for d in deps]),
            tsickle_externs=[],
            replay_params=None,
            devmode_manifest=None,
        )
    )

closure_aspect = aspect(
    attr_aspects = [
        "deps",
        "exports",
    ],
    implementation = _closure_aspect_impl,
)

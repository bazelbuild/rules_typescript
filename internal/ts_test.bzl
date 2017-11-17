load("@build_bazel_rules_nodejs//internal:node.bzl",
    "sources_aspect",
    "expand_path_into_runfiles",
)

_CONF_TMPL = "//internal/karma:karma.conf.js"
_LOADER = "//internal/karma:test-main.js"

def _ts_test_impl(ctx):
  conf = ctx.actions.declare_file(
      "%s.conf.js" % ctx.label.name,
      sibling=ctx.outputs.executable)

  files = depset(ctx.files.srcs)
  for d in ctx.attr.deps:
    if hasattr(d, "node_sources"):
      files += d.node_sources
    elif hasattr(d, "files"):
      files += d.files

  TMPL_files = "\n".join([
      "      '%s'," % expand_path_into_runfiles(ctx, f.short_path)
      for f in files
  ])

  # root-relative (runfiles) path to the directory containing karma.conf
  config_segments = len(conf.short_path.split("/"))

  ctx.actions.expand_template(
      output = conf,
      template =  ctx.file._conf_tmpl,
      substitutions = {
          "TMPL_runfiles_path": "/".join([".."] * config_segments),
          "TMPL_files": TMPL_files,
          "TMPL_workspace_name": ctx.workspace_name,
      })

  ctx.actions.write(
      output = ctx.outputs.executable,
      is_executable = True,
      content = """#!/usr/bin/env bash
readonly KARMA={TMPL_karma}
readonly CONF={TMPL_conf}
export HOME=$(mktemp -d)
ARGV=( "start" $CONF )

# Detect that we are running as a test, by using a well-known environment
# variable. See go/test-encyclopedia
if [ ! -z "$TEST_TMPDIR" ]; then
  ARGV+=( "--single-run" )
fi

$KARMA ${{ARGV[@]}}
""".format(TMPL_karma = ctx.executable._karma.short_path,
           TMPL_conf = conf.short_path))
  return [DefaultInfo(
      runfiles = ctx.runfiles(
          files = ctx.files.srcs + ctx.files.deps + [
              conf,
              ctx.file._loader,
          ],
          transitive_files = files,
          # Propagate karma_bin and its runfiles
          collect_data = True,
      ),
  )]

ts_test = rule(
    implementation = _ts_test_impl,
    test = True,
    attrs = {
        "srcs": attr.label_list(allow_files = ["js"]),
        "deps": attr.label_list(
          allow_files = True,
          aspects = [sources_aspect],
        ),
        "data": attr.label_list(cfg = "data"),
        "_karma": attr.label(
            default = Label("//internal/karma:karma_bin"),
            executable = True,
            cfg = "data",
            single_file = False,
            allow_files = True),
        "_conf_tmpl": attr.label(
            default = Label(_CONF_TMPL),
            allow_files = True, single_file = True),
        "_loader": attr.label(
            default = Label(_LOADER),
            allow_files = True, single_file = True),
    },
)

# This macro exists only to modify the users rule definition a bit.
# DO NOT add composition of additional rules here.
def ts_test_macro(tags = [], data = [], **kwargs):
  ts_test(
      # Users don't need to know that this tag is required to run under ibazel
      tags = tags + ["iblaze_notify_changes"],
      # Our binary dependency must be in data[] for collect_data to pick it up
      # FIXME: maybe we can just ask the attr._karma for its runfiles attr
      data = data + ["@build_bazel_rules_typescript//internal/karma:karma_bin"],
      **kwargs)

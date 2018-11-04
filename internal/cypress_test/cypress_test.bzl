"""NodeJS testing

These rules let you run tests outside of a browser. This is typically faster
than launching a test in Karma, for example.
"""
load("@build_bazel_rules_nodejs//:defs.bzl", "nodejs_test")
load("@build_bazel_rules_nodejs//internal/common:devmode_js_sources.bzl", "devmode_js_sources")
CYPRESS_JSON_CONTENT = "{ \"integrationFolder\": \".\", \"video\": false, \"screenshots\": false, \"supportFile\": false }"

def _short_path_to_manifest_path(ctx, short_path):
    if short_path.startswith("../"):
        return short_path[3:]
    else:
        return ctx.workspace_name + "/" + short_path

def _impl(ctx):

  conf = ctx.actions.declare_file("cypress.json")
  ctx.actions.write(output = ctx.outputs.cypressjson, content = CYPRESS_JSON_CONTENT)

  # files = depset(ctx.files.srcs)
  # for d in ctx.attr.deps:
  #   print(d.files)
  #   if hasattr(d, "node_sources"):
  #     files += d.node_sources
  #   elif hasattr(d, "files"):
  #     files += d.files
  files = depset(ctx.files.srcs)
  for d in ctx.attr.deps:
      if hasattr(d, "node_sources"):
          files = depset(transitive = [files, d.node_sources])
      elif hasattr(d, "files"):
          files = depset(transitive = [files, d.files])

  ctx.actions.write(
      output = ctx.outputs.executable,
      is_executable = True,
      content = """#!/usr/bin/env bash
if [ -e "$RUNFILES_MANIFEST_FILE" ]; then
  while read line; do
    declare -a PARTS=($line)
    if [ "${{PARTS[0]}}" == "{TMPL_cypress}" ]; then
      readonly CYPRESS=${{PARTS[1]}}
    fi
  done < $RUNFILES_MANIFEST_FILE
else
  readonly CYPRESS=../{TMPL_cypress}
fi
export HOME=$(mktemp -d)
ARGV=()
# Detect that we are running as a test, by using well-known environment
# variables. See go/test-encyclopedia
# Note: in Bazel 0.14 and later, TEST_TMPDIR is set for both bazel test and bazel run
# so we also check for the BUILD_WORKSPACE_DIRECTORY which is set only for bazel run
if [[ ! -z "${{TEST_TMPDIR}}" && ! -n "${{BUILD_WORKSPACE_DIRECTORY}}" ]]; then
  ARGV+=( "run" )
fi
# $CYPRESS ${{ARGV[@]}}
echo $CYPRESS
$CYPRESS open
  """.format(TMPL_cypress = _short_path_to_manifest_path(ctx, ctx.executable.cypress.short_path)))

  cypress_runfiles = [conf] + ctx.files.srcs + ctx.files.data

  return [DefaultInfo(
      files = depset([ctx.outputs.executable]),
      runfiles = ctx.runfiles(
          files = cypress_runfiles,
          transitive_files = files,
          # Propagate karma_bin and its runfiles
          collect_data = True,
          collect_default = True,
      ),
      executable = ctx.outputs.executable,
  )]

cypress_test = rule (
  implementation = _impl,
  test = True,
  # executable = True,
  outputs = {"cypressjson": "cypress.json"},
  attrs = {
    "deps": attr.label_list(),
    "srcs": attr.label_list(
            doc = "JavaScript source files",
            allow_files = [".js"]),
    "data": attr.label_list(
      doc = "Runtime dependencies",
      cfg = "target"),
    "cypress": attr.label(
      default = Label("//tools/cypress-rule:cypress_bin"),
        executable = True,
        cfg = "data",
        single_file = False,
        allow_files = True
    ),

  }
)

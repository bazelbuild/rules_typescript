const fs = require('fs');
const path = require('path');
const child_process = require('child_process');
const os = require('os');

const tmpdir = fs.mkdtempSync(path.join(os.tmpdir(), 'wksp'));
const WORKSPACE_BOILERPLATE = `
http_archive(
    name = "build_bazel_rules_nodejs",
    urls = ["https://github.com/bazelbuild/rules_nodejs/archive/0.10.0.zip"],
    strip_prefix = "rules_nodejs-0.10.0",
)
http_archive(
    name = "io_bazel_rules_webtesting",
    urls = ["https://github.com/bazelbuild/rules_webtesting/archive/v0.2.0.zip"],
    strip_prefix = "rules_webtesting-0.2.0",
)
http_archive(
    name = "io_bazel_rules_go",
    urls = [
        "http://mirror.bazel.build/github.com/bazelbuild/rules_go/releases/download/0.10.3/rules_go-0.10.3.tar.gz",
        "https://github.com/bazelbuild/rules_go/releases/download/0.10.3/rules_go-0.10.3.tar.gz"
    ],
)
local_repository(
    name = "build_bazel_rules_typescript",
    path = "${process.cwd()}",
)
load("@build_bazel_rules_nodejs//:defs.bzl", "node_repositories")
node_repositories(package_json=[])
load("@build_bazel_rules_typescript//:defs.bzl", "ts_setup_workspace")
ts_setup_workspace()
`;

function write(filename, content) {
    var parents = path.dirname(path.join(tmpdir, filename)); 
    while (path.dirname(parents) !== parents) {
        if (!fs.existsSync(path.join(parents))) {
            fs.mkdirSync(path.join(parents));
        }
        parents = path.dirname(parents);
    }
    fs.writeFileSync(path.join(tmpdir, filename), content);
}

function bazel(workspace, args) {
  const result = child_process.spawnSync('bazel', args, {
      cwd: path.join(tmpdir, workspace),
      stdio: 'inherit',
  });
  expect(result.status).toBe(0, 'bazel exited with non-zero exit code');
}

describe('default tsconfig', () => {
    it('uses the tsconfig in the workspace defining the rule', () => {
        // Workspace 'a' can't compile with --noImplicitAny
        write('a/WORKSPACE', `
workspace(name = "a")
${WORKSPACE_BOILERPLATE}`);
        write('a/BUILD', `
load("@build_bazel_rules_typescript//:defs.bzl", "ts_library")
ts_library(
    name = "a_lib", 
    srcs=["has_implicit_any.ts"],
    node_modules = "@build_bazel_rules_typescript_tsc_wrapped_deps//:node_modules",
    visibility = ["//visibility:public"],
)
        `);
        write('a/tsconfig.json', `{}`);
        write('a/has_implicit_any.ts', `function f(a) {
            console.error(a);
        }`);

        // Workspace 'b' has a default tsconfig that sets --noImplicitAny
        write('b/WORKSPACE', `
workspace(name="b")
local_repository(name="a", path="../a")
${WORKSPACE_BOILERPLATE}`);
        write('b/BUILD', `
load("@build_bazel_rules_typescript//:defs.bzl", "ts_library")
exports_files(["tsconfig.json"])
ts_library(
    name = "b_lib",
    srcs = ["file.ts"],
    deps = ["@a//:a_lib"],
    node_modules = "@build_bazel_rules_typescript_tsc_wrapped_deps//:node_modules",
)
        `);
        write('b/file.ts', `
        f('thing');
        `);
        write('b/tsconfig.json', `{
            "compilerOptions": {
                "noImplicitAny": true
            }
        }`);
        bazel('b', ['build', ':all']);
    });
});
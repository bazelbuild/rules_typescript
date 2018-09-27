/**
 * @fileoverview
 * This tests interactions between multiple Bazel workspaces.
 *
 * We have learned from experience in the rules_nodejs repo that it's not
 * practical to simply check in the nested WORKSPACE files and try to build
 * them, because
 * - it's hard to exclude them from the parent WORKSPACE - each nested workspace
 *   must be registered there with a matching name
 * - testing a child workspace requires `cd` into the directory, which doesn't
 *   fit the CI model of `bazel test ...`
 *
 * The test is written in JavaScript simply to make it more portable, so we can
 * run it on Windows for example. We don't use TypeScript here since we are
 * running outside the build system.
 */

const fs = require('fs');
const path = require('path');
const child_process = require('child_process');
const os = require('os');

const tmpdir = fs.mkdtempSync(path.join(os.tmpdir(), 'wksp'));
const WORKSPACE_BOILERPLATE = `
http_archive(
    name = "build_bazel_rules_nodejs",
    urls = ["https://github.com/bazelbuild/rules_nodejs/archive/0.14.1.zip"],
    strip_prefix = "rules_nodejs-0.14.1",
    sha256 = "813eb51733d3632f456f3bb581d940ed64e80dab417595c93bf5ad19079898e2",
)
http_archive(
    name = "bazel_skylib",
    urls = ["https://github.com/bazelbuild/bazel-skylib/archive/0.3.1.zip"],
    strip_prefix = "bazel-skylib-0.3.1",
    sha256 = "95518adafc9a2b656667bbf517a952e54ce7f350779d0dd95133db4eb5c27fb1",
)
http_archive(
    name = "io_bazel_skydoc",
    urls = ["https://github.com/bazelbuild/skydoc/archive/0ef7695c9d70084946a3e99b89ad5a99ede79580.zip"],
    strip_prefix = "skydoc-0ef7695c9d70084946a3e99b89ad5a99ede79580",
    sha256 = "491f9e142b870b18a0ec8eb3d66636eeceabe5f0c73025706c86f91a1a2acb4d",
)
http_archive(
    name = "io_bazel_rules_webtesting",
    urls = ["https://github.com/bazelbuild/rules_webtesting/archive/0.2.1.zip"],
    strip_prefix = "rules_webtesting-0.2.1",
    sha256 = "7d490aadff9b5262e5251fa69427ab2ffd1548422467cb9f9e1d110e2c36f0fa",
)
http_archive(
    name = "io_bazel_rules_go",
    urls = ["https://github.com/bazelbuild/rules_go/releases/download/0.13.0/rules_go-0.13.0.tar.gz"],
    sha256 = "ba79c532ac400cefd1859cbc8a9829346aa69e3b99482cd5a54432092cbc3933",
)
http_archive(
    name = "bazel_gazelle",
    urls = ["https://github.com/bazelbuild/bazel-gazelle/releases/download/0.13.0/bazel-gazelle-0.13.0.tar.gz"],
    sha256 = "bc653d3e058964a5a26dcad02b6c72d7d63e6bb88d94704990b908a1445b8758",
)
local_repository(
    name = "build_bazel_rules_typescript",
    path = "${process.cwd()}",
)
load("@build_bazel_rules_nodejs//:defs.bzl", "node_repositories", "yarn_install")
node_repositories()
yarn_install(
  name = "npm",
  package_json = "//:package.json",
  yarn_lock = "//:yarn.lock",
)
load("@build_bazel_rules_typescript//:defs.bzl", "ts_setup_workspace")
ts_setup_workspace()
`;

const PACKAGE_JSON = `{
    "devDependencies": {
        "@types/node": "7.0.18",
        "protobufjs": "5.0.0",
        "tsickle": "0.32.1",
        "tsutils": "2.20.0",
        "typescript": "2.7.x"
    }
}
`;

const YARN_LOCK =
    `# THIS IS AN AUTOGENERATED FILE. DO NOT EDIT THIS FILE DIRECTLY.
# yarn lockfile v1


"@types/node@7.0.18":
  version "7.0.18"
  resolved "https://registry.yarnpkg.com/@types/node/-/node-7.0.18.tgz#cd67f27d3dc0cfb746f0bdd5e086c4c5d55be173"

ansi-regex@^2.0.0:
  version "2.1.1"
  resolved "https://registry.yarnpkg.com/ansi-regex/-/ansi-regex-2.1.1.tgz#c3b33ab5ee360d86e0e628f0468ae7ef27d654df"

ascli@~1:
  version "1.0.1"
  resolved "https://registry.yarnpkg.com/ascli/-/ascli-1.0.1.tgz#bcfa5974a62f18e81cabaeb49732ab4a88f906bc"
  dependencies:
    colour "~0.7.1"
    optjs "~3.2.2"

balanced-match@^1.0.0:
  version "1.0.0"
  resolved "https://registry.yarnpkg.com/balanced-match/-/balanced-match-1.0.0.tgz#89b4d199ab2bee49de164ea02b89ce462d71b767"

brace-expansion@^1.1.7:
  version "1.1.11"
  resolved "https://registry.yarnpkg.com/brace-expansion/-/brace-expansion-1.1.11.tgz#3c7fcbf529d87226f3d2f52b966ff5271eb441dd"
  dependencies:
    balanced-match "^1.0.0"
    concat-map "0.0.1"

buffer-from@^1.0.0:
  version "1.1.1"
  resolved "https://registry.yarnpkg.com/buffer-from/-/buffer-from-1.1.1.tgz#32713bc028f75c02fdb710d7c7bcec1f2c6070ef"

bytebuffer@~5:
  version "5.0.1"
  resolved "https://registry.yarnpkg.com/bytebuffer/-/bytebuffer-5.0.1.tgz#582eea4b1a873b6d020a48d58df85f0bba6cfddd"
  dependencies:
    long "~3"

camelcase@^2.0.1:
  version "2.1.1"
  resolved "https://registry.yarnpkg.com/camelcase/-/camelcase-2.1.1.tgz#7c1d16d679a1bbe59ca02cacecfb011e201f5a1f"

cliui@^3.0.3:
  version "3.2.0"
  resolved "https://registry.yarnpkg.com/cliui/-/cliui-3.2.0.tgz#120601537a916d29940f934da3b48d585a39213d"
  dependencies:
    string-width "^1.0.1"
    strip-ansi "^3.0.1"
    wrap-ansi "^2.0.0"

code-point-at@^1.0.0:
  version "1.1.0"
  resolved "https://registry.yarnpkg.com/code-point-at/-/code-point-at-1.1.0.tgz#0d070b4d043a5bea33a2f1a40e2edb3d9a4ccf77"

colour@~0.7.1:
  version "0.7.1"
  resolved "https://registry.yarnpkg.com/colour/-/colour-0.7.1.tgz#9cb169917ec5d12c0736d3e8685746df1cadf778"

concat-map@0.0.1:
  version "0.0.1"
  resolved "https://registry.yarnpkg.com/concat-map/-/concat-map-0.0.1.tgz#d8a96bd77fd68df7793a73036a3ba0d5405d477b"

decamelize@^1.1.1:
  version "1.2.0"
  resolved "https://registry.yarnpkg.com/decamelize/-/decamelize-1.2.0.tgz#f6534d15148269b20352e7bee26f501f9a191290"

diff@^3.2.0:
  version "3.5.0"
  resolved "https://registry.yarnpkg.com/diff/-/diff-3.5.0.tgz#800c0dd1e0a8bfbc95835c202ad220fe317e5a12"

glob@^5.0.10:
  version "5.0.15"
  resolved "https://registry.yarnpkg.com/glob/-/glob-5.0.15.tgz#1bc936b9e02f4a603fcc222ecf7633d30b8b93b1"
  dependencies:
    inflight "^1.0.4"
    inherits "2"
    minimatch "2 || 3"
    once "^1.3.0"
    path-is-absolute "^1.0.0"

inflight@^1.0.4:
  version "1.0.6"
  resolved "https://registry.yarnpkg.com/inflight/-/inflight-1.0.6.tgz#49bd6331d7d02d0c09bc910a1075ba8165b56df9"
  dependencies:
    once "^1.3.0"
    wrappy "1"

inherits@2:
  version "2.0.3"
  resolved "https://registry.yarnpkg.com/inherits/-/inherits-2.0.3.tgz#633c2c83e3da42a502f52466022480f4208261de"

invert-kv@^1.0.0:
  version "1.0.0"
  resolved "https://registry.yarnpkg.com/invert-kv/-/invert-kv-1.0.0.tgz#104a8e4aaca6d3d8cd157a8ef8bfab2d7a3ffdb6"

is-fullwidth-code-point@^1.0.0:
  version "1.0.0"
  resolved "https://registry.yarnpkg.com/is-fullwidth-code-point/-/is-fullwidth-code-point-1.0.0.tgz#ef9e31386f031a7f0d643af82fde50c457ef00cb"
  dependencies:
    number-is-nan "^1.0.0"

jasmine-diff@^0.1.3:
  version "0.1.3"
  resolved "https://registry.yarnpkg.com/jasmine-diff/-/jasmine-diff-0.1.3.tgz#93ccc2dcc41028c5ddd4606558074839f2deeaa8"
  dependencies:
    diff "^3.2.0"

lcid@^1.0.0:
  version "1.0.0"
  resolved "https://registry.yarnpkg.com/lcid/-/lcid-1.0.0.tgz#308accafa0bc483a3867b4b6f2b9506251d1b835"
  dependencies:
    invert-kv "^1.0.0"

long@~3:
  version "3.2.0"
  resolved "https://registry.yarnpkg.com/long/-/long-3.2.0.tgz#d821b7138ca1cb581c172990ef14db200b5c474b"

"minimatch@2 || 3":
  version "3.0.4"
  resolved "https://registry.yarnpkg.com/minimatch/-/minimatch-3.0.4.tgz#5166e286457f03306064be5497e8dbb0c3d32083"
  dependencies:
    brace-expansion "^1.1.7"

minimist@0.0.8:
  version "0.0.8"
  resolved "http://registry.npmjs.org/minimist/-/minimist-0.0.8.tgz#857fcabfc3397d2625b8228262e86aa7a011b05d"

minimist@^1.2.0:
  version "1.2.0"
  resolved "http://registry.npmjs.org/minimist/-/minimist-1.2.0.tgz#a35008b20f41383eec1fb914f4cd5df79a264284"

mkdirp@^0.5.1:
  version "0.5.1"
  resolved "http://registry.npmjs.org/mkdirp/-/mkdirp-0.5.1.tgz#30057438eac6cf7f8c4767f38648d6697d75c903"
  dependencies:
    minimist "0.0.8"

number-is-nan@^1.0.0:
  version "1.0.1"
  resolved "https://registry.yarnpkg.com/number-is-nan/-/number-is-nan-1.0.1.tgz#097b602b53422a522c1afb8790318336941a011d"

once@^1.3.0:
  version "1.4.0"
  resolved "https://registry.yarnpkg.com/once/-/once-1.4.0.tgz#583b1aa775961d4b113ac17d9c50baef9dd76bd1"
  dependencies:
    wrappy "1"

optjs@~3.2.2:
  version "3.2.2"
  resolved "https://registry.yarnpkg.com/optjs/-/optjs-3.2.2.tgz#69a6ce89c442a44403141ad2f9b370bd5bb6f4ee"

os-locale@^1.4.0:
  version "1.4.0"
  resolved "http://registry.npmjs.org/os-locale/-/os-locale-1.4.0.tgz#20f9f17ae29ed345e8bde583b13d2009803c14d9"
  dependencies:
    lcid "^1.0.0"

path-is-absolute@^1.0.0:
  version "1.0.1"
  resolved "https://registry.yarnpkg.com/path-is-absolute/-/path-is-absolute-1.0.1.tgz#174b9268735534ffbc7ace6bf53a5a9e1b5c5f5f"

protobufjs@5.0.0:
  version "5.0.0"
  resolved "https://registry.yarnpkg.com/protobufjs/-/protobufjs-5.0.0.tgz#4223063233ea96ac063ca2b554035204db524fa1"
  dependencies:
    ascli "~1"
    bytebuffer "~5"
    glob "^5.0.10"
    yargs "^3.10.0"

source-map-support@^0.5.0:
  version "0.5.9"
  resolved "https://registry.yarnpkg.com/source-map-support/-/source-map-support-0.5.9.tgz#41bc953b2534267ea2d605bccfa7bfa3111ced5f"
  dependencies:
    buffer-from "^1.0.0"
    source-map "^0.6.0"

source-map@^0.6.0:
  version "0.6.1"
  resolved "https://registry.yarnpkg.com/source-map/-/source-map-0.6.1.tgz#74722af32e9614e9c287a8d0bbde48b5e2f1a263"

string-width@^1.0.1:
  version "1.0.2"
  resolved "https://registry.yarnpkg.com/string-width/-/string-width-1.0.2.tgz#118bdf5b8cdc51a2a7e70d211e07e2b0b9b107d3"
  dependencies:
    code-point-at "^1.0.0"
    is-fullwidth-code-point "^1.0.0"
    strip-ansi "^3.0.0"

strip-ansi@^3.0.0, strip-ansi@^3.0.1:
  version "3.0.1"
  resolved "https://registry.yarnpkg.com/strip-ansi/-/strip-ansi-3.0.1.tgz#6a385fb8853d952d5ff05d0e8aaf94278dc63dcf"
  dependencies:
    ansi-regex "^2.0.0"

tsickle@0.32.1:
  version "0.32.1"
  resolved "https://registry.yarnpkg.com/tsickle/-/tsickle-0.32.1.tgz#f16e94ba80b32fc9ebe320dc94fbc2ca7f3521a5"
  dependencies:
    jasmine-diff "^0.1.3"
    minimist "^1.2.0"
    mkdirp "^0.5.1"
    source-map "^0.6.0"
    source-map-support "^0.5.0"

tslib@^1.8.1:
  version "1.9.3"
  resolved "https://registry.yarnpkg.com/tslib/-/tslib-1.9.3.tgz#d7e4dd79245d85428c4d7e4822a79917954ca286"

tsutils@2.20.0:
  version "2.20.0"
  resolved "https://registry.yarnpkg.com/tsutils/-/tsutils-2.20.0.tgz#303394064bc80be8ee04e10b8609ae852e9312d3"
  dependencies:
    tslib "^1.8.1"

typescript@2.7.x:
  version "2.7.2"
  resolved "http://registry.npmjs.org/typescript/-/typescript-2.7.2.tgz#2d615a1ef4aee4f574425cdff7026edf81919836"

window-size@^0.1.4:
  version "0.1.4"
  resolved "https://registry.yarnpkg.com/window-size/-/window-size-0.1.4.tgz#f8e1aa1ee5a53ec5bf151ffa09742a6ad7697876"

wrap-ansi@^2.0.0:
  version "2.1.0"
  resolved "http://registry.npmjs.org/wrap-ansi/-/wrap-ansi-2.1.0.tgz#d8fc3d284dd05794fe84973caecdd1cf824fdd85"
  dependencies:
    string-width "^1.0.1"
    strip-ansi "^3.0.1"

wrappy@1:
  version "1.0.2"
  resolved "https://registry.yarnpkg.com/wrappy/-/wrappy-1.0.2.tgz#b5243d8f3ec1aa35f1364605bc0d1036e30ab69f"

y18n@^3.2.0:
  version "3.2.1"
  resolved "https://registry.yarnpkg.com/y18n/-/y18n-3.2.1.tgz#6d15fba884c08679c0d77e88e7759e811e07fa41"

yargs@^3.10.0:
  version "3.32.0"
  resolved "http://registry.npmjs.org/yargs/-/yargs-3.32.0.tgz#03088e9ebf9e756b69751611d2a5ef591482c995"
  dependencies:
    camelcase "^2.0.1"
    cliui "^3.0.3"
    decamelize "^1.1.1"
    os-locale "^1.4.0"
    string-width "^1.0.1"
    window-size "^0.1.4"
    y18n "^3.2.0"
`;

/**
 * Create a file at path filename, creating parent directories as needed, under
 * this test's temp directory. Write the content into that file.
 */
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
  it(`uses the tsconfig in the workspace defining the rule,
        not the workspace where the rule is defined (rules_typescript), nor
        the workspace where the build is occurring`,
     () => {
       // Workspace 'a' can't compile with --noImplicitAny.
       // When workspace 'b' has a dep here, we make sure not to use the
       // tsconfig from workspace 'b'
       write('a/package.json', PACKAGE_JSON);
       write('a/yarn.lock', YARN_LOCK);
       write('a/WORKSPACE', `
workspace(name = "a")
${WORKSPACE_BOILERPLATE}`);
       write('a/BUILD', `
# We use ts_library from internal/defaults.bzl since we don't have a @bazel/typescript npm
# package in this test. This changes the ts_library compiler from the default '@build_bazel_rules_typescript//:@bazel/typescript/tsc_wrapped'
# which depends on @npm//:@bazel/typescript which is not available in this test to '@build_bazel_rules_typescript//internal:tsc_wrapped_bin' which is
load("@build_bazel_rules_typescript//internal:defaults.bzl", "ts_library")
ts_library(
    name = "a_lib",
    srcs=["has_implicit_any.ts"],
    visibility = ["//visibility:public"],
)
        `);
       write('a/tsconfig.json', `{}`);
       write('a/has_implicit_any.ts', `function f(a) {
            console.error(a);
        }`);

       // Workspace 'b' has a default tsconfig that sets --noImplicitAny.
       write('b/package.json', PACKAGE_JSON);
       write('b/yarn.lock', YARN_LOCK);
       write('b/WORKSPACE', `
workspace(name="b")
local_repository(name="a", path="../a")
${WORKSPACE_BOILERPLATE}`);
       write('b/BUILD', `
# We use ts_library from internal/defaults.bzl since we don't have a @bazel/typescript npm
# package in this test. This changes the ts_library compiler from the default '@build_bazel_rules_typescript//:@bazel/typescript/tsc_wrapped'
# which depends on @npm//:@bazel/typescript which is not available in this test to '@build_bazel_rules_typescript//internal:tsc_wrapped_bin' which is
load("@build_bazel_rules_typescript//internal:defaults.bzl", "ts_library")
exports_files(["tsconfig.json"])
ts_library(
    name = "b_lib",
    srcs = ["file.ts"],
    deps = ["@a//:a_lib"],
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

       // Now build from workspace 'b' and verify that the dep in workspace 'a'
       // was able to compile.
       bazel('b', ['build', ':all']);
     });
});

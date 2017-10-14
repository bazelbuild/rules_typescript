// Runs tslint under bazel.
// In place of the regular tslint CLI, we'll be called as a Bazel extra action.
// So our inputs come from a protocol buffer, and the outputs go into another protocol buffer.

import * as fs from 'fs';
import * as path from 'path';
import {ILinterOptions, Linter, IOptions} from 'tslint';
import * as ts from 'typescript';
import {parseTsconfig} from '@bazel/typescript';

/* tslint:disable:no-require-imports */
const protobufjs = require('protobufjs');
const ByteBuffer = require('bytebuffer');

export const extraActionPb = (function loadPb(): {decode: Function} {
  // This doesn't work due to a Bazel bug, see comments in build_defs.bzl
  // let protoPath =
  // 'external/bazel_tools/src/main/protobuf/extra_actions_base.proto';
  let protoPath = 'build_bazel_rules_typescript/internal/extra_actions_base.proto';

  // Use node module resolution so we can find the .proto file in any of the root dirs
  const protoNamespace = protobufjs.loadProtoFile(require.resolve(protoPath));
  if (!protoNamespace) {
    throw new Error('Cannot find ' + path.resolve(protoPath));
  }
  return protoNamespace.build('blaze.ExtraActionInfo');
})();

export function diagnosticsToString(diagnostics: ts.Diagnostic[]): string {
  return ts.formatDiagnostics(diagnostics, {
    getCurrentDirectory: () => ts.sys.getCurrentDirectory(),
    getNewLine: () => ts.sys.newLine,
    getCanonicalFileName: f => f
  });
}

export function main(args: string[]) {
  const [extraActionProtoFile, outputAnalysisFile] = args;
  const extraActionProto =
  extraActionPb.decode(fs.readFileSync(extraActionProtoFile));
  const actionArgs = extraActionProto['.blaze.SpawnInfo.spawnInfo']['argument'];
  // Take the last argument and strip leading `@@`
  const tsconfigPath = actionArgs[actionArgs.length - 1].substring(2);
  const [parsed, errors] = parseTsconfig(tsconfigPath);

  if (errors) {
    throw diagnosticsToString(errors);
  }
  if (!parsed) {
    throw new Error(
        'Impossible state: if parseTsconfig returns no errors, then parsed should be non-null');
  }
  const {options, bazelOpts, files} = parsed;
  const compilerHost = ts.createCompilerHost(options);
  const program = ts.createProgram(files, options, compilerHost);
  const tslintOptions: ILinterOptions = {
    formatter: 'prose',
    fix: false,
  };
  function isCompilationTarget(sf: ts.SourceFile): boolean {
    return !/\.d\.ts$/.test(sf.fileName) &&
        (bazelOpts.compilationTargetSrc.indexOf(sf.fileName) >= 0);
  }

  const linter = new Linter(tslintOptions, program);
  const diagnostics = [];
  const tslintConfig = Linter.loadConfigurationFromPath('build_bazel_rules_typescript/tslint/tslint.json');
  for (const sf of program.getSourceFiles()) {
    if (isCompilationTarget(sf)) {
      // trigger a type-check first
      diagnostics.push(...ts.getPreEmitDiagnostics(program, sf));
      linter.lint(sf.fileName, sf.getFullText(), tslintConfig);
    }
  }
  const lintResult = linter.getResult();
  // This can be located after the build with
  // ls bazel-out/*/extra_actions/tslint/tslint_action
  fs.writeFileSync(
      outputAnalysisFile, lintResult, {encoding: 'utf-8'});

  if (lintResult.errorCount > 0) {
    console.error(lintResult.output);
    return 1;
  }
  return 0;
}

if (require.main === module) {
  process.exitCode = main(process.argv.slice(2));
}

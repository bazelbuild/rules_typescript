import * as path from 'path';
import * as tsickle from 'tsickle';
import * as ts from 'typescript';

import {PLUGIN as tsetsePlugin} from '../tsetse/runner';

import {CompilerHost} from './compiler_host';
import * as bazelDiagnostics from './diagnostics';
import {CachedFileLoader, FileCache, FileLoader, UncachedFileLoader} from './file_cache';
import {wrap} from './perf_trace';
import {PLUGIN as strictDepsPlugin} from './strict_deps';
import {BazelOptions, parseTsconfig, resolveNormalizedPath} from './tsconfig';
import {TscPlugin} from './plugin_api';
import {debug, log, runAsWorker, runWorkerLoop} from './worker';

export function main(args: string[]) {
  if (runAsWorker(args)) {
    log('Starting TypeScript compiler persistent worker...');
    runWorkerLoop(runOneBuild);
    // Note: intentionally don't process.exit() here, because runWorkerLoop
    // is waiting for async callbacks from node.
  } else {
    debug('Running a single build...');
    if (args.length === 0) throw new Error('Not enough arguments');
    if (!runOneBuild(args)) {
      return 1;
    }
  }
  return 0;
}

// Narrowed type where the transforms are always defined
interface CustomTransformers {
  before: ts.TransformerFactory<ts.SourceFile>[];
  after: ts.TransformerFactory<ts.SourceFile>[];
  afterDeclarations: ts.TransformerFactory<ts.Bundle | ts.SourceFile>[];
}

// The one FileCache instance used in this process.
const fileCache = new FileCache(debug);

function isCompilationTarget(bazelOpts: BazelOptions, sf: ts.SourceFile): boolean {
  return (bazelOpts.compilationTargetSrc.indexOf(sf.fileName) !== -1);
}

export function gatherDiagnostics(
    options: ts.CompilerOptions, bazelOpts: BazelOptions, program: ts.Program,
    disabledTsetseRules: string[]): ts.Diagnostic[] {
  // Install extra diagnostic plugins
  if (!bazelOpts.disableStrictDeps) {
    const ignoredFilesPrefixes = [bazelOpts.nodeModulesPrefix];
    if (options.rootDir) {
      ignoredFilesPrefixes.push(path.resolve(options.rootDir, 'node_modules'));
    }
    program = strictDepsPlugin.wrap(program, {
      ...bazelOpts,
      rootDir: options.rootDir,
      ignoredFilesPrefixes,
    });
  }
  program = tsetsePlugin.wrap(program, disabledTsetseRules);

  const diagnostics: ts.Diagnostic[] = [];
  // These checks mirror ts.getPreEmitDiagnostics, with the important
  // exception that if you call program.getDeclarationDiagnostics() it somehow
  // corrupts the emit.
  wrap(`global diagnostics`, () => {
    diagnostics.push(...program.getOptionsDiagnostics());
    diagnostics.push(...program.getGlobalDiagnostics());
  });
  let sourceFilesToCheck: ReadonlyArray<ts.SourceFile>;
  if (bazelOpts.typeCheckDependencies) {
    sourceFilesToCheck = program.getSourceFiles();
  } else {
    sourceFilesToCheck = program.getSourceFiles().filter(
      f => isCompilationTarget(bazelOpts, f));
  }
  for (const sf of sourceFilesToCheck) {
    wrap(`check ${sf.fileName}`, () => {
      diagnostics.push(...program.getSyntacticDiagnostics(sf));
      diagnostics.push(...program.getSemanticDiagnostics(sf));
    });
  }
  return diagnostics;
}

/**
 * Runs a single build, returning false on failure.  This is potentially called
 * multiple times (once per bazel request) when running as a bazel worker.
 * Any encountered errors are written to stderr.
 */
function runOneBuild(
    args: string[], inputs?: {[path: string]: string}): boolean {
  if (args.length !== 1) {
    console.error('Expected one argument: path to tsconfig.json');
    return false;
  }
  // Strip leading at-signs, used in build_defs.bzl to indicate a params file
  const tsconfigFile = args[0].replace(/^@+/, '');

  const [parsed, errors, {target}] = parseTsconfig(tsconfigFile);
  if (errors) {
    console.error(bazelDiagnostics.format(target, errors));
    return false;
  }
  if (!parsed) {
    throw new Error(
        'Impossible state: if parseTsconfig returns no errors, then parsed should be non-null');
  }
  const {options, bazelOpts, files, disabledTsetseRules} = parsed;

  // Reset cache stats.
  fileCache.resetStats();
  fileCache.traceStats();
  if (bazelOpts.maxCacheSizeMb !== undefined) {
    const maxCacheSizeBytes = bazelOpts.maxCacheSizeMb * 1 << 20;
    fileCache.setMaxCacheSize(maxCacheSizeBytes);
  } else {
    fileCache.resetMaxCacheSize();
  }

  let fileLoader: FileLoader;
  const allowActionInputReads = true;

  if (inputs) {
    fileLoader = new CachedFileLoader(fileCache);
    // Resolve the inputs to absolute paths to match TypeScript internals
    const resolvedInputs = new Map<string, string>();
    for (const key of Object.keys(inputs)) {
      resolvedInputs.set(resolveNormalizedPath(key), inputs[key]);
    }
    fileCache.updateCache(resolvedInputs);
  } else {
    fileLoader = new UncachedFileLoader();
  }

  const compilerHostDelegate =
      ts.createCompilerHost({target: ts.ScriptTarget.ES5});

  const compilerHost = new CompilerHost(
      files, options, bazelOpts, compilerHostDelegate, fileLoader,
      allowActionInputReads);

  let program = ts.createProgram(files, options, compilerHost);

  fileCache.traceStats();

  let diags: ts.Diagnostic[] = [];
  const transforms: CustomTransformers = {
    before: [],
    after: [],
    afterDeclarations: [],
  };

  for (const p of bazelOpts.plugins || []) {
    switch (p) {
      case 'Angular':
        let plugin: TscPlugin;
        try {
          plugin = require('@angular/compiler-cli').NgTscPlugin;
        } catch (e) {
          throw new Error('when using `ts_library(plugins=["Angular"])`, ' +
              'you must install @angular/compiler-cli');
        }
        // Apply the diagnostics capability of the plugin
        program = plugin.wrap(program, parsed.angularCompilerOptions);
        // Apply the transformers capability of the plugin
        if (plugin.createTransformers) {
          const x = plugin.createTransformers(/**FIXME*/(s: string) => s);
          if (x.before) {
            transforms.before = transforms.before.concat(x.before);
          }
          if (x.after) {
            transforms.after = transforms.after.concat(x.after);
          }
          if (x.afterDeclarations) {
            transforms.afterDeclarations = transforms.afterDeclarations.concat(x.afterDeclarations);
          }
        }

        break;
      default:
        throw new Error(`Unknown ts_library plugin ${p}`);
    }
  }

  // If there are any TypeScript type errors abort now, so the error
  // messages refer to the original source.  After any subsequent passes
  // (decorator downleveling or tsickle) we do not type check.
  diags = bazelDiagnostics.filterExpected(bazelOpts, diags);
  if (diags.length > 0) {
    console.error(bazelDiagnostics.format(bazelOpts.target, diags));
    return false;
  }
  const toEmit = program.getSourceFiles().filter(f => isCompilationTarget(bazelOpts, f));
  const emitResults: ts.EmitResult[] = [];

  if (bazelOpts.tsickle) {
    // The 'tsickle' import above is only used in type positions, so it won't
    // result in a runtime dependency on tsickle.
    // If the user requests the tsickle emit, then we dynamically require it
    // here for use at runtime.
    let optTsickle: typeof tsickle;
    try {
      // tslint:disable-next-line:no-require-imports optDep on tsickle
      optTsickle = require('tsickle');
    } catch {
      throw new Error(
          'When setting bazelOpts { tsickle: true }, ' +
          'you must also add a devDependency on the tsickle npm package');
    }
    for (const sf of toEmit) {
      emitResults.push(optTsickle.emitWithTsickle(
          program, compilerHost, compilerHost, options, sf,
          /*writeFile*/ undefined,
          /*cancellationToken*/ undefined, /*emitOnlyDtsFiles*/ undefined,
          {
            beforeTs: transforms.before,
            afterTs: transforms.after
            // FIXME: what about transforms.afterDeclarations
          }));
    }
    diags.push(
        ...optTsickle.mergeEmitResults(emitResults as tsickle.EmitResult[])
            .diagnostics);
  } else {
    for (const sf of toEmit) {
      emitResults.push(program.emit(
          sf, /*writeFile*/ undefined,
          /*cancellationToken*/ undefined, /*emitOnlyDtsFiles*/ undefined,
          transforms));
    }

    for (const d of emitResults) {
      diags.push(...d.diagnostics);
    }
  }
  if (diags.length > 0) {
    console.error(bazelDiagnostics.format(bazelOpts.target, diags));
    return false;
  }
  return true;
}

if (require.main === module) {
  process.exitCode = main(process.argv.slice(2));
}

const fs = require('fs');
const path = require('path');
const cypress = require('cypress');

const UTF8 = {
  encoding: 'utf-8'
};

// These exit codes are handled specially by Bazel:
// https://github.com/bazelbuild/bazel/blob/486206012a664ecb20bdb196a681efc9a9825049/src/main/java/com/google/devtools/build/lib/util/ExitCode.java#L44
const BAZEL_EXIT_TESTS_FAILED = 3;
const BAZEL_EXIT_NO_TESTS_FOUND = 4;
const IBAZEL_NOTIFY_BUILD_SUCCESS = 'IBAZEL_BUILD_COMPLETED SUCCESS';
const IBAZEL_NOTIFY_CHANGES = 'IBAZEL_NOTIFY_CHANGES';

// Set the StackTraceLimit to infinity. This will make stack capturing slower, but more useful.
// Since we are running tests having proper stack traces is very useful and should be always set to
// the maximum (See: https://nodejs.org/api/errors.html#errors_error_stacktracelimit)
Error.stackTraceLimit = Infinity;

async function main(args) {
  if (!args.length) {
    throw new Error('Spec file manifest expected argument missing');
  }
  const manifest = require.resolve(args[0]);
  const exeRoot = path.dirname(manifest);

  const specLocations = fs.readFileSync(manifest, UTF8).split('\n').filter(p =>p.length > 0).map(f => {
    return require.resolve(f)
  });

  const specs = specLocations.filter(f => f.endsWith('spec.js'))
  
  const cypressJsonSettings = {integrationFolder: '.', video: false, screenshots: false, supportFile: false}
  fs.writeFileSync(path.join(exeRoot, 'cypress.json'), JSON.stringify(cypressJsonSettings));

  const isIBazelMode = Boolean(process.env[IBAZEL_NOTIFY_CHANGES]);

  // we cant use open right now due to https://github.com/cypress-io/cypress/issues/1925
  if(isIBazelMode) {
    await open(exeRoot, specs);
  } else {
    await run(exeRoot, specs);
  }

}

async function run(configFilePath, specs) {
  if(specs.length === 0) {
    process.exit(BAZEL_EXIT_NO_TESTS_FOUND);
  }

  const result = await cypress.run({
    project: configFilePath, 
    spec: specs
  }); 
   
  // if no tests failed then it's a pass
  if(result.totalFailed > 0) {
    process.exit(BAZEL_EXIT_TESTS_FAILED);
  } else {
    process.exit(0)
  }

}

function open(configFilePath, specs) {
  cypress.open({
    project: configFilePath, 
    spec: specs
  }); 
}

if (require.main === module) {
  main(process.argv.slice(2)).catch(err => console.log(err));
}
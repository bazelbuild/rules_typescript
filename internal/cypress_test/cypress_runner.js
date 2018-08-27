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

// Set the StackTraceLimit to infinity. This will make stack capturing slower, but more useful.
// Since we are running tests having proper stack traces is very useful and should be always set to
// the maximum (See: https://nodejs.org/api/errors.html#errors_error_stacktracelimit)
Error.stackTraceLimit = Infinity;

function main(args) {
  if (!args.length) {
    throw new Error('Spec file manifest expected argument missing');
  }
  const manifest = require.resolve(args[0]);
  const specLocations = fs.readFileSync(manifest, UTF8).split('\n').filter(p =>p.length > 0).map(f => {
    return require.resolve(f)
  });

  const specs = specLocations.filter(f => f.endsWith('spec.js'))
  // console.log(specs)
// console.log(process.env)
//   console.log(specLocations)
  const cypressJsonSettings = {integrationFolder: 'integration', video: false, screenshots: false,}
  fs.writeFileSync('../../../cypress.json', JSON.stringify())
  console.log(process.cwd());
  console.log(specs[0])
  // console.log(path.relative('.', specs[0]))

  cypress.run({
    project: '../../../', 
    spec: specs
  });  

}

if (require.main === module) {
  process.exitCode = main(process.argv.slice(2));
}
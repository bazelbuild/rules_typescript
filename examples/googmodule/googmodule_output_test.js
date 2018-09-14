const fs = require('fs');

describe('googmodule', () => {
  let output;
  beforeAll(() => {
    output = fs.readFileSync(require.resolve(
        'build_bazel_rules_typescript/examples/googmodule/a.js'), 'utf-8');
  });

  it('should have goog module syntax in devmode', () => {
    expect(output).toContain(
        `goog.module('build_bazel_rules_typescript.examples.googmodule.a')`);
  });
  it('should have tsickle type annotations', () => {
    expect(output).toContain(`@type {number}`);
  });
  it('should not auto-quote properties', () => {
    expect(output).not.toContain(`quoted["hello"]`);
  });
});
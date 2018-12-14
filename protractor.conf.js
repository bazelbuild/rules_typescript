exports.config = {
  suites: {
    app: 'examples/app/bazel-bin/*_e2e_test.js',
    protocol_buffers: 'bazel-bin/examples/protocol_buffers/*_e2e_test.js',
  },
  capabilities: {
    browserName: 'chrome',
    chromeOptions: {args: ['--no-sandbox']}
  },
  directConnect: true,
  baseUrl: 'http://localhost:8080/',
  framework: 'jasmine',
};

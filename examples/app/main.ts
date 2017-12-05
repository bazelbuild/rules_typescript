import * as ng from 'angular';
import {helloWorldComponent} from 'build_bazel_rules_typescript/examples/app/hello-world/hello-world';

ng.module('HelloWorldApp', []).component('helloWorld', helloWorldComponent);

ng.bootstrap(document, ['HelloWorldApp']);

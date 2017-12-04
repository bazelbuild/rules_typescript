import * as fs from 'fs';
import * as tsForTypes from 'typescript';
import * as ts from 'typescript/lib/tsserverlibrary';

import * as pluginApi from '../tsc_wrapped/plugin_api';

import {Checker} from './checker';
import {registerRules} from './runner';

// Installs the Tsetse language server plugin, which checks Tsetse rules in your
// editor and shows issues as semantic errors (red squiggly underline).

function init() {
  return {
    create(info: ts.server.PluginCreateInfo) {
      const oldService = info.languageService;
      const checker = new Checker(oldService.getProgram());
      const {config, error} = ts.readConfigFile(
          info.project.getProjectRootPath() + '/tsconfig.json',
          fn => info.languageServiceHost.readFile!(fn));
      if (error) {
        // This will get lost in a log somewhere. Maybe we can fail more
        // gracefully?
        throw new Error(`Could not parse config file: ${error.messageText}`);
      }
      const disabledRules = config['bazelOpts'] ?
          config['bazelOpts']['disabledTsetseRules'] || [] :
          [];
      registerRules(checker, disabledRules);

      const proxy = pluginApi.createProxy(oldService);
      proxy.getSemanticDiagnostics = (fileName: string) => {
        const result = oldService.getSemanticDiagnostics(fileName);
        result.push(
            ...checker.execute(oldService.getProgram().getSourceFile(fileName))
                .map(failure => failure.toDiagnostic()));
        return result;
      };
      return proxy;
    }
  }
}

export = init;

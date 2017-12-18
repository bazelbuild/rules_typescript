import {IComponentOptions} from 'angular';

export class HelloWorldController {
  world: string;

  constructor() {
    this['world'] = '';
  }
}

export const helloWorldComponent: IComponentOptions = {
  templateUrl: '/hello-world/hello-world.html',
  controller: HelloWorldController,
  controllerAs: 'ctrl',
  bindings: {'world': '@'},
}

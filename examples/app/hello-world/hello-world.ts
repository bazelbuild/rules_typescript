import {IComponentOptions} from 'angular';

declare global {
  const HELLO: string;
}

export class HelloWorldController {
  hello: string;
  world: string;

  constructor() {
    this['world'] = '';
    this['hello'] = HELLO;
  }
}

export const helloWorldComponent: IComponentOptions = {
  templateUrl: '/hello-world/hello-world.html',
  controller: HelloWorldController,
  controllerAs: 'ctrl',
  bindings: {'world': '@'},
}

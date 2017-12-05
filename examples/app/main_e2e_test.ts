import {browser, by, element, ExpectedConditions} from 'protractor';

describe('Closure compiled AngularJS example', () => {
  beforeAll(() => {
    browser.get('');
    browser.sleep(1000);
  });

  it('should display: Hello world', () => {
    const helloWorld = element(by.css('hello-world'));
    expect(helloWorld.getText()).toContain(`Hello world`);
  });
});

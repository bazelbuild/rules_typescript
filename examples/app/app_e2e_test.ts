import {browser, by, element, ExpectedConditions} from 'protractor';

// This test uses Protractor without Angular, so disable Angular features
browser.waitForAngularEnabled(false);

// must include server build/startup
const timeoutMs = 90 * 1000;

describe('Devserver', () => {
  beforeAll(() => {
    browser.get('');
    // Don't run any specs until we see a <div> on the page.
    browser.wait(
        ExpectedConditions.presenceOf(element(by.css('div.ts1'))), timeoutMs);
  }, timeoutMs);

  it('should display: Hello world!', (done) => {
    const div = element(by.css('div.ts1'));
    div.getText().then(t => expect(t).toEqual(`Hello, TypeScript`));
    done();
  }, 60 * 1000);
});

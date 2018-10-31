
// declare let it: any;
// declare let describe: any;
declare let cy: any;

describe('My First Test', function() {
  it('Visits the Kitchen Sink', function() {
    cy.visit('https://example.cypress.io')
  })
})
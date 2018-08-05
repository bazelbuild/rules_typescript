## Expect not to have nested Jasmine 'it' call expressions

Nested `it` call expression in spec files will cause false positives for unit tests.

To fix this, the the upper `it` call expression should be changed to a `describe`.

### Positive Examples:
```ts
describe('given', () => {
  it('should be okay', () => {
    expect(1).toBeTruthy();
  });
});

describe('given', () => {
  describe('when', () => {
    describe('and', () => {
      it('should be okay', () => {
        expect(1).toBeTruthy();
      });
    });
  });
});
```

### Negative Examples:

```ts
it('given', () => {
  it('should fail', () => {
    expect(1).toBeTruthy();
  });
});

describe('given', () => {
  it('when', () => {
    describe('and', () => {
      it('should fail', () => {
        expect(1).toBeTruthy();
      });
    });
  });
});
```
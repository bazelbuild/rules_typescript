it('given', () => {
	it('should fail', () => {
		expect(1).toBeTruthy();
	});
});

it('given', function() {
	let x: boolean;
	it('should fail', function() {
		expect(x).toBeTruthy();
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

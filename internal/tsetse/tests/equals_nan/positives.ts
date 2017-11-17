const equalsNan = 1 === NaN;

declare const x: number;

if (x === NaN) console.log('never happens');
if (x == NaN) console.log('never happens');

NaN === NaN;
NaN === 0 / 0;

export {}  // Make this file a module.

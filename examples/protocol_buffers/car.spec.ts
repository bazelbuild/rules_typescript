import {Car} from './car';

describe('protocol buffers', () => {
  it('allows creation of an object described by proto', () => {
    const pontiac = Car.create({"make": "pontiac"});
    pontiac.frontTires = {
      width: 225,
      aspectRatio: 65,
      construction: 'R',
      diameter: 17,
    };
    expect(pontiac.make).toEqual('pontiac');
    expect(pontiac.frontTires.width).toEqual(225);
  });
});


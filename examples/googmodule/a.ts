export const a: number = 1;
interface Quoted {
  [k: string]: number;
}
let quoted: Quoted = {};
quoted.hello = a;

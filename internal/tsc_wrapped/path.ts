import * as path from 'path';

// resolve function that maintains backslashes
export function resolve(...a: string[]) {
    return path.resolve(...a).replace(/\\/g, '/');
}

// join function that maintains backslashes
export function join(...a: string[]) {
    return path.join(...a).replace(/\\/g, '/');
}

// relative function that maintains backslashes
export function relative(a: string, b: string) {
    return path.relative(a, b).replace(/\\/g, '/');
}

// normalize function that maintains backslashes
export function normalize(p: string) {
    return path.normalize(p).replace(/\\/g, '/');
}
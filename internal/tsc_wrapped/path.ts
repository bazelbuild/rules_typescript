import * as path from 'path';

// resolve function that preserves forward slashes ('/') on Windows
export function resolve(...a: string[]) {
    return path.resolve(...a).replace(/\\/g, '/');
}

// join function that preserves forward slashes ('/') on Windows
export function join(...a: string[]) {
    return path.join(...a).replace(/\\/g, '/');
}

// relative function that preserves forward slashes ('/') on Windows
export function relative(a: string, b: string) {
    return path.relative(a, b).replace(/\\/g, '/');
}

// normalize function that preserves forward slashes ('/') on Windows
export function normalize(p: string) {
    return path.normalize(p).replace(/\\/g, '/');
}

// re-export other functions used
export function dirname(p: string): string { return path.dirname(p); }
export function basename(p: string): string { return path.basename(p); }

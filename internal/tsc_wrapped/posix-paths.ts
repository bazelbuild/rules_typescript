import {resolve} from 'path';

/**
 * Converts a path which could potentially include backslash delimiters into a consistent posix
 * path that uses forward slashes.
 * 
 * Note that path.posix.resolve('a\\b\\c') still returns a non-posix path with backslashes.
 */
export function convertToPosixPath(value: string): string {
  return value.replace(/\\/g, '/');
}

/**
 * The same as Node's path.resolve, however it returns a path with forward
 * slashes rather than joining the resolved path with the platform's path
 * separator.
 * Note that even path.posix.resolve('.') returns C:\Users\... with backslashes.
 */
export function resolveNormalizedPath(...segments: string[]): string {
  return convertToPosixPath(resolve(...segments));
}

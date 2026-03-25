import micromatch from "micromatch";

export function isGlobMatch(path: string, pattern: string): boolean {
  return micromatch.isMatch(path, pattern, { dot: true });
}

export function isValidGlob(pattern: string): boolean {
  try {
    micromatch.makeRe(pattern, { dot: true });
    return true;
  } catch {
    return false;
  }
}

import fg from 'fast-glob';
import path from 'node:path';
const DEFAULT_EXCLUDES = [
    '**/node_modules/**',
    '**/dist/**',
    '**/build/**',
    '**/.git/**',
];
const RULES_FILE_PATTERN = '**/*.rules.json';
const FLIGHT_DOMAINS_DIR = '.flight/domains';
/**
 * Discover files matching glob patterns.
 * @param options - Discovery options with patterns, excludes, and base path
 * @returns Sorted array of absolute file paths
 */
export async function discoverFiles(options) {
    const { patterns, excludePatterns, basePath } = options;
    const combinedExcludes = [...DEFAULT_EXCLUDES, ...(excludePatterns ?? [])];
    const matchedFiles = await fg(patterns, {
        cwd: basePath,
        absolute: true,
        ignore: combinedExcludes,
        onlyFiles: true,
        dot: false,
    });
    return matchedFiles.map((filePath) => path.normalize(filePath)).sort();
}
/**
 * Discover .rules.json files for auto mode.
 * Searches in .flight/domains/ directory.
 * @param basePath - Project root directory
 * @returns Sorted array of absolute paths to .rules.json files
 */
export async function discoverRulesFiles(basePath) {
    const domainsPath = path.join(basePath, FLIGHT_DOMAINS_DIR);
    const matchedFiles = await fg(RULES_FILE_PATTERN, {
        cwd: domainsPath,
        absolute: true,
        onlyFiles: true,
        dot: false,
    });
    return matchedFiles.map((filePath) => path.normalize(filePath)).sort();
}

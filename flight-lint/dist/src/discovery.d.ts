import type { DiscoveryOptions } from './types.js';
/**
 * Get all test file and directory patterns for exclusion.
 * Use this to exclude test files from source-code validation.
 * @returns Array of glob patterns matching test files
 */
export declare function getTestFilePatterns(): string[];
/**
 * Check if a file path is a test file.
 * @param filePath - The file path to check
 * @returns true if the file is a test file
 */
export declare function isTestFile(filePath: string): boolean;
/**
 * Discover files matching glob patterns.
 * @param options - Discovery options with patterns, excludes, and base path
 * @returns Sorted array of absolute file paths
 */
export declare function discoverFiles(options: DiscoveryOptions): Promise<string[]>;
/**
 * Discover .rules.json files for auto mode.
 * Searches in .flight/domains/ directory.
 * @param basePath - Project root directory
 * @returns Sorted array of absolute paths to .rules.json files
 */
export declare function discoverRulesFiles(basePath: string): Promise<string[]>;
//# sourceMappingURL=discovery.d.ts.map
import type { DiscoveryOptions } from './types.js';
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
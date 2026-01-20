import type { RulesFile } from './types.js';
/**
 * Load and validate a .rules.json file.
 * @param filePath - Path to the rules file
 * @returns Parsed and validated rules file
 * @throws Error with context if file cannot be read or is invalid
 */
export declare function loadRulesFile(filePath: string): Promise<RulesFile>;
//# sourceMappingURL=loader.d.ts.map
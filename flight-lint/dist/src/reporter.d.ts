import type { LintResult, LintSummary, OutputFormat, Severity } from './types.js';
/**
 * Format lint results in the specified output format.
 * @param summary - The lint summary to format
 * @param format - Output format (pretty, json, sarif)
 * @returns Formatted string output
 */
export declare function formatResults(summary: LintSummary, format: OutputFormat): string;
/**
 * Format lint results as colored terminal output.
 * @param summary - The lint summary to format
 * @returns Colored terminal string
 */
export declare function formatPretty(summary: LintSummary): string;
/**
 * Format lint results as JSON.
 * @param summary - The lint summary to format
 * @returns JSON string
 */
export declare function formatJson(summary: LintSummary): string;
/**
 * Format lint results as SARIF 2.1.0.
 * @param summary - The lint summary to format
 * @returns SARIF JSON string
 */
export declare function formatSarif(summary: LintSummary): string;
/**
 * Group lint results by severity.
 * @param results - Array of lint results
 * @returns Map of severity to results
 */
export declare function groupBySeverity(results: readonly LintResult[]): Map<Severity, LintResult[]>;
/**
 * Group lint results by rule ID.
 * @param results - Array of lint results
 * @returns Map of rule ID to results
 */
export declare function groupByRule(results: readonly LintResult[]): Map<string, LintResult[]>;
/**
 * Get exit code based on lint results.
 * Returns 1 if there are NEVER or MUST violations, 0 otherwise.
 * @param results - Array of lint results
 * @returns Exit code (0 or 1)
 */
export declare function getExitCode(results: readonly LintResult[]): number;
//# sourceMappingURL=reporter.d.ts.map
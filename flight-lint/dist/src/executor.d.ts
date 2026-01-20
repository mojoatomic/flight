import Parser from 'tree-sitter';
import type { Rule, RulesFile, LintResult, LintSummary } from './types.js';
/**
 * Internal interface for query matches.
 */
interface QueryMatch {
    readonly line: number;
    readonly column: number;
    readonly text: string;
}
/**
 * Check if a file language is compatible with a rules language.
 * @param fileLanguage - The language of the file being linted
 * @param rulesLanguage - The language specified in the rules file
 * @returns True if the file can be linted with the rules
 */
export declare function isLanguageCompatible(fileLanguage: string, rulesLanguage: string): boolean;
/**
 * Execute a single rule's query against a parsed syntax tree.
 * @param tree - The parsed syntax tree
 * @param rule - The rule containing the query to execute
 * @param language - The tree-sitter language object
 * @returns Array of matches with 1-indexed locations
 * @throws Error if the query syntax is invalid
 */
export declare function executeRule(tree: Parser.Tree, rule: Rule, language: any): QueryMatch[];
/**
 * Lint a single file with the given rules.
 * @param filePath - Path to the file to lint
 * @param rules - Rules to apply
 * @param language - Language of the file
 * @returns Array of lint results
 */
export declare function lintFile(filePath: string, rules: readonly Rule[], language: string): Promise<LintResult[]>;
/**
 * Lint multiple files with rules from a rules file.
 * @param files - Array of file paths to lint
 * @param rulesFile - The rules file containing rules and language info
 * @returns Summary of lint results
 */
export declare function lintFiles(files: readonly string[], rulesFile: RulesFile): Promise<LintSummary>;
export {};
//# sourceMappingURL=executor.d.ts.map
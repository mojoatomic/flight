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
 * Check if a file language is compatible with a rule's target language.
 * @param fileLanguage - The language of the file being linted
 * @param ruleLanguage - The language specified in the rule (undefined for grep rules)
 * @returns True if the rule should be applied to this file
 */
export declare function isRuleCompatibleWithFile(fileLanguage: string, ruleLanguage: string | undefined): boolean;
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
 * Only rules compatible with the file's language are executed.
 * @param filePath - Path to the file to lint
 * @param rules - Rules to apply
 * @param fileLanguage - Language of the file
 * @returns Array of lint results
 */
export declare function lintFile(filePath: string, rules: readonly Rule[], fileLanguage: string): Promise<LintResult[]>;
/**
 * Lint multiple files with rules from a rules file.
 * Language filtering is done per-rule, not per-file.
 * @param files - Array of file paths to lint
 * @param rulesFile - The rules file containing rules
 * @returns Summary of lint results
 */
export declare function lintFiles(files: readonly string[], rulesFile: RulesFile): Promise<LintSummary>;
export {};
//# sourceMappingURL=executor.d.ts.map
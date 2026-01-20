import Parser from 'tree-sitter';
import { readFile } from 'node:fs/promises';
import { getLanguage, detectLanguage, parseFile } from './parser.js';
import type { Rule, RulesFile, LintResult, LintSummary } from './types.js';

/**
 * Language compatibility map.
 * JavaScript rules can run on JavaScript and JSX files.
 * TypeScript rules can run on TypeScript and TSX files.
 */
const LANGUAGE_COMPATIBILITY: Record<string, readonly string[]> = {
  javascript: ['javascript', 'jsx'],
  typescript: ['typescript', 'tsx'],
};

/**
 * Internal interface for query matches.
 */
interface QueryMatch {
  readonly line: number;   // 1-indexed
  readonly column: number; // 1-indexed
  readonly text: string;
}

/**
 * Check if a file language is compatible with a rules language.
 * @param fileLanguage - The language of the file being linted
 * @param rulesLanguage - The language specified in the rules file
 * @returns True if the file can be linted with the rules
 */
export function isLanguageCompatible(fileLanguage: string, rulesLanguage: string): boolean {
  const compatibleLanguages = LANGUAGE_COMPATIBILITY[rulesLanguage];
  if (compatibleLanguages) {
    return compatibleLanguages.includes(fileLanguage);
  }
  // If rulesLanguage not in map, require exact match
  return fileLanguage === rulesLanguage;
}

/**
 * Check if a rule has an AST query that can be executed.
 * @param rule - The rule to check
 * @returns True if the rule has an executable AST query
 */
function hasAstQuery(rule: Rule): boolean {
  return rule.query !== null && rule.query.length > 0;
}

/**
 * Execute a single rule's query against a parsed syntax tree.
 * @param tree - The parsed syntax tree
 * @param rule - The rule containing the query to execute
 * @param language - The tree-sitter language object
 * @returns Array of matches with 1-indexed locations
 * @throws Error if the query syntax is invalid
 */
export function executeRule(
  tree: Parser.Tree,
  rule: Rule,
  // tree-sitter's TypeScript types use `any` for language objects
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  language: any
): QueryMatch[] {
  // Skip rules without AST queries (e.g., grep-based rules)
  if (!hasAstQuery(rule)) {
    return [];
  }

  let query: Parser.Query;
  try {
    query = new Parser.Query(language, rule.query as string);
  } catch (parseError) {
    const errorMessage = parseError instanceof Error ? parseError.message : String(parseError);
    throw new Error(`Invalid query syntax for rule ${rule.id}: ${errorMessage}`);
  }

  const captures = query.captures(tree.rootNode);
  const matches: QueryMatch[] = [];

  for (const capture of captures) {
    // Only report captures named 'violation' - other captures are used for predicates
    if (capture.name !== 'violation') {
      continue;
    }
    matches.push({
      line: capture.node.startPosition.row + 1,    // Convert 0-indexed to 1-indexed
      column: capture.node.startPosition.column + 1, // Convert 0-indexed to 1-indexed
      text: capture.node.text,
    });
  }

  return matches;
}

/**
 * Lint a single file with the given rules.
 * @param filePath - Path to the file to lint
 * @param rules - Rules to apply
 * @param language - Language of the file
 * @returns Array of lint results
 */
export async function lintFile(
  filePath: string,
  rules: readonly Rule[],
  language: string
): Promise<LintResult[]> {
  const sourceContent = await readFile(filePath, 'utf-8');
  const tree = await parseFile(sourceContent, language);
  const treeSitterLanguage = await getLanguage(language);

  const lintResults: LintResult[] = [];

  for (const rule of rules) {
    const matches = executeRule(tree, rule, treeSitterLanguage);

    for (const match of matches) {
      lintResults.push({
        filePath,
        line: match.line,
        column: match.column,
        ruleId: rule.id,
        severity: rule.severity,
        message: rule.message,
      });
    }
  }

  return lintResults;
}

/**
 * Lint multiple files with rules from a rules file.
 * @param files - Array of file paths to lint
 * @param rulesFile - The rules file containing rules and language info
 * @returns Summary of lint results
 */
export async function lintFiles(
  files: readonly string[],
  rulesFile: RulesFile
): Promise<LintSummary> {
  const allResults: LintResult[] = [];
  let lintedFileCount = 0;

  for (const filePath of files) {
    const fileLanguage = detectLanguage(filePath);

    // Skip files with unrecognized extensions
    if (fileLanguage === null) {
      continue;
    }

    if (!isLanguageCompatible(fileLanguage, rulesFile.language)) {
      // Skip files that don't match the rules language
      continue;
    }

    const fileResults = await lintFile(filePath, rulesFile.rules, fileLanguage);
    allResults.push(...fileResults);
    lintedFileCount++;
  }

  return {
    domain: rulesFile.domain,
    fileCount: lintedFileCount,
    results: allResults,
  };
}

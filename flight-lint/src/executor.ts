import Parser from 'tree-sitter';
import { readFile } from 'node:fs/promises';
import { getLanguage, detectLanguage, parseFile } from './parser.js';
import type { Rule, RulesFile, LintResult, LintSummary } from './types.js';

/**
 * Internal interface for grep matches.
 */
interface GrepMatch {
  readonly line: number;   // 1-indexed
  readonly column: number; // 1-indexed
  readonly text: string;
}

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
 * Check if a file language is compatible with a rule's target language.
 * @param fileLanguage - The language of the file being linted
 * @param ruleLanguage - The language specified in the rule (undefined for grep rules)
 * @returns True if the rule should be applied to this file
 */
export function isRuleCompatibleWithFile(fileLanguage: string, ruleLanguage: string | undefined): boolean {
  // Rules without a language field (grep rules) apply to all files
  if (!ruleLanguage) {
    return true;
  }

  // Check compatibility map (e.g., javascript rules work on jsx files)
  const compatibleLanguages = LANGUAGE_COMPATIBILITY[ruleLanguage];
  if (compatibleLanguages) {
    return compatibleLanguages.includes(fileLanguage);
  }

  // If ruleLanguage not in map, require exact match
  return fileLanguage === ruleLanguage;
}

/**
 * Check if a rule has an AST query that can be executed.
 * @param rule - The rule to check
 * @returns True if the rule has an executable AST query
 */
function hasAstQuery(rule: Rule): boolean {
  return rule.query !== null && rule.query !== undefined && rule.query.length > 0;
}

/**
 * Check if a rule has a grep pattern that can be executed.
 * @param rule - The rule to check
 * @returns True if the rule has an executable grep pattern
 */
function hasGrepPattern(rule: Rule): boolean {
  return rule.pattern !== null && rule.pattern !== undefined && rule.pattern.length > 0;
}

/**
 * Execute a grep rule against file content using Node's regex.
 * @param content - The file content to search
 * @param rule - The rule containing the pattern
 * @returns Array of matches with 1-indexed locations
 */
function executeGrepRule(content: string, rule: Rule): GrepMatch[] {
  if (!hasGrepPattern(rule)) {
    return [];
  }

  const matches: GrepMatch[] = [];
  const lines = content.split('\n');

  let regex: RegExp;
  try {
    regex = new RegExp(rule.pattern!);
  } catch {
    // Invalid regex pattern - skip silently
    return [];
  }

  for (let i = 0; i < lines.length; i++) {
    const line = lines[i]!;
    const match = regex.exec(line);
    if (match) {
      matches.push({
        line: i + 1,  // 1-indexed
        column: match.index + 1,  // 1-indexed
        text: match[0],
      });
    }
  }

  return matches;
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
 * Handles both AST rules (tree-sitter) and grep rules (regex).
 * @param filePath - Path to the file to lint
 * @param rules - Rules to apply
 * @param fileLanguage - Language of the file (null for unknown)
 * @returns Array of lint results
 */
export async function lintFile(
  filePath: string,
  rules: readonly Rule[],
  fileLanguage: string | null
): Promise<LintResult[]> {
  const sourceContent = await readFile(filePath, 'utf-8');
  const lintResults: LintResult[] = [];

  // Separate rules by type
  const grepRules = rules.filter(r => hasGrepPattern(r));
  const astRules = rules.filter(r => hasAstQuery(r));

  // Execute grep rules (work on any file)
  for (const rule of grepRules) {
    const matches = executeGrepRule(sourceContent, rule);
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

  // Execute AST rules (only if we can parse the file)
  if (fileLanguage && astRules.length > 0) {
    try {
      const tree = await parseFile(sourceContent, fileLanguage);
      const treeSitterLanguage = await getLanguage(fileLanguage);

      for (const rule of astRules) {
        // Skip rules that don't match this file's language
        if (!isRuleCompatibleWithFile(fileLanguage, rule.language)) {
          continue;
        }

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
    } catch {
      // Failed to parse - skip AST rules for this file
    }
  }

  return lintResults;
}

/**
 * Lint multiple files with rules from a rules file.
 * Grep rules run on all files; AST rules only on files with supported languages.
 * @param files - Array of file paths to lint
 * @param rulesFile - The rules file containing rules
 * @returns Summary of lint results
 */
export async function lintFiles(
  files: readonly string[],
  rulesFile: RulesFile
): Promise<LintSummary> {
  const allResults: LintResult[] = [];
  let lintedFileCount = 0;

  // Check if we have any grep rules (these can run on any file)
  const hasGrepRules = rulesFile.rules.some(r => hasGrepPattern(r));

  for (const filePath of files) {
    const fileLanguage = detectLanguage(filePath);

    // Skip files only if we have no grep rules AND no AST language support
    if (!hasGrepRules && fileLanguage === null) {
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

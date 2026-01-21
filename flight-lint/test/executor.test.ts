import { describe, it, afterEach, before, after } from 'node:test';
import assert from 'node:assert';
import { writeFile, unlink, mkdir, rm } from 'node:fs/promises';
import path from 'node:path';
import { parseFile, getLanguage } from '../src/parser.js';
import { executeRule, lintFile, lintFiles, isRuleCompatibleWithFile } from '../src/executor.js';
import type { Rule, RulesFile } from '../src/types.js';

// Shared test rules - defined once to avoid duplication
// Query node types use tree-sitter naming conventions
// Note: executeRule only reports captures named '@violation'
const VAR_FINDER_QUERY = '(variable_declarator name: (identifier) @violation)';
const FUNC_FINDER_QUERY = '(function_declaration name: (identifier) @violation)';
const CLASS_FINDER_QUERY = '(class_declaration name: (identifier) @violation)';

function createVarFinderRule(overrides: Partial<Rule> = {}): Rule {
  return {
    id: 'find-vars',
    title: 'Find Variables',
    severity: 'SHOULD',
    query: VAR_FINDER_QUERY,
    message: 'Variable declaration found',
    ...overrides,
  };
}

function createFuncFinderRule(overrides: Partial<Rule> = {}): Rule {
  return {
    id: 'find-functions',
    title: 'Find Functions',
    severity: 'NEVER',
    query: FUNC_FINDER_QUERY,
    message: 'Function declaration found',
    ...overrides,
  };
}

describe('executor', () => {
  const TEST_DIR = `/tmp/flight-lint-executor-test-${Date.now()}`;
  const createdPaths: string[] = [];

  before(async () => {
    await mkdir(TEST_DIR, { recursive: true });
  });

  async function createTestFile(relativePath: string, content: string): Promise<string> {
    const fullPath = path.join(TEST_DIR, relativePath);
    const dirPath = path.dirname(fullPath);
    await mkdir(dirPath, { recursive: true });
    await writeFile(fullPath, content);
    createdPaths.push(fullPath);
    return fullPath;
  }

  afterEach(async () => {
    for (const filePath of createdPaths) {
      try {
        await unlink(filePath);
      } catch {
        // Ignore cleanup errors
      }
    }
    createdPaths.length = 0;
  });

  after(async () => {
    try {
      await rm(TEST_DIR, { recursive: true });
    } catch {
      // Ignore cleanup errors
    }
  });

  describe('isRuleCompatibleWithFile', () => {
    it('returns true for exact language match', () => {
      assert.strictEqual(isRuleCompatibleWithFile('javascript', 'javascript'), true);
      assert.strictEqual(isRuleCompatibleWithFile('typescript', 'typescript'), true);
    });

    it('returns true for javascript rules on jsx files', () => {
      assert.strictEqual(isRuleCompatibleWithFile('jsx', 'javascript'), true);
    });

    it('returns true for typescript rules on tsx files', () => {
      assert.strictEqual(isRuleCompatibleWithFile('tsx', 'typescript'), true);
    });

    it('returns false for incompatible languages', () => {
      assert.strictEqual(isRuleCompatibleWithFile('typescript', 'javascript'), false);
      assert.strictEqual(isRuleCompatibleWithFile('javascript', 'typescript'), false);
    });

    it('returns true for self-match when not in compatibility map', () => {
      assert.strictEqual(isRuleCompatibleWithFile('python', 'python'), true);
    });

    it('returns false for different unknown languages', () => {
      assert.strictEqual(isRuleCompatibleWithFile('python', 'rust'), false);
    });

    it('returns true when rule has no language (grep rules apply to all files)', () => {
      assert.strictEqual(isRuleCompatibleWithFile('javascript', undefined), true);
      assert.strictEqual(isRuleCompatibleWithFile('python', undefined), true);
    });
  });

  describe('executeRule', () => {
    it('finds matches with correct 1-indexed location', async () => {
      const sourceCode = 'let count = 1;';
      const tree = await parseFile(sourceCode, 'javascript');
      const language = await getLanguage('javascript');

      const rule = createVarFinderRule({ id: 'test-rule', title: 'Test Rule' });
      const matches = executeRule(tree, rule, language);

      assert.strictEqual(matches.length, 1);
      assert.strictEqual(matches[0]?.line, 1);
      assert.strictEqual(matches[0]?.column, 5);
      assert.strictEqual(matches[0]?.text, 'count');
    });

    it('finds multiple matches in the same file', async () => {
      const sourceCode = `let first = 1;
let second = 2;
let third = 3;`;
      const tree = await parseFile(sourceCode, 'javascript');
      const language = await getLanguage('javascript');

      const rule = createVarFinderRule({ id: 'multi-match', title: 'Multi Match' });
      const matches = executeRule(tree, rule, language);

      assert.strictEqual(matches.length, 3);
      assert.strictEqual(matches[0]?.line, 1);
      assert.strictEqual(matches[1]?.line, 2);
      assert.strictEqual(matches[2]?.line, 3);
    });

    it('returns empty array when no matches found', async () => {
      const sourceCode = 'const frozen = Object.freeze({});';
      const tree = await parseFile(sourceCode, 'javascript');
      const language = await getLanguage('javascript');

      const rule: Rule = {
        id: 'no-match',
        title: 'No Match',
        severity: 'SHOULD',
        query: CLASS_FINDER_QUERY,
        message: 'Found class',
      };

      const matches = executeRule(tree, rule, language);
      assert.strictEqual(matches.length, 0);
    });

    it('throws on invalid query syntax with rule ID in error', async () => {
      const sourceCode = 'let count = 1;';
      const tree = await parseFile(sourceCode, 'javascript');
      const language = await getLanguage('javascript');

      const rule: Rule = {
        id: 'invalid-query',
        title: 'Invalid Query',
        severity: 'SHOULD',
        query: '(this is not valid query syntax',
        message: 'Should not match',
      };

      assert.throws(
        () => executeRule(tree, rule, language),
        (thrown: unknown) => {
          const error = thrown as Error;
          return error.message.includes('invalid-query');
        }
      );
    });
  });

  describe('lintFile', () => {
    it('runs all rules on a file and returns results', async () => {
      const filePath = await createTestFile('test.js', `let alpha = 1;
let beta = 2;`);

      const rules: Rule[] = [createVarFinderRule()];
      const lintResults = await lintFile(filePath, rules, 'javascript');

      assert.strictEqual(lintResults.length, 2);
      assert.strictEqual(lintResults[0]?.ruleId, 'find-vars');
      assert.strictEqual(lintResults[0]?.severity, 'SHOULD');
      assert.strictEqual(lintResults[0]?.line, 1);
      assert.strictEqual(lintResults[1]?.line, 2);
    });

    it('runs multiple rules on the same file', async () => {
      const filePath = await createTestFile('multi-rule.js', `function greet() {
  let message = "hello";
  return message;
}`);

      const rules: Rule[] = [
        createFuncFinderRule(),
        createVarFinderRule({ severity: 'MUST' }),
      ];

      const lintResults = await lintFile(filePath, rules, 'javascript');

      assert.strictEqual(lintResults.length, 2);
      const ruleIds = lintResults.map((lint) => lint.ruleId);
      assert.ok(ruleIds.includes('find-functions'));
      assert.ok(ruleIds.includes('find-vars'));
    });
  });

  describe('lintFiles', () => {
    it('lints multiple files and returns summary', async () => {
      await createTestFile('src/app.js', 'let counter = 0;');
      await createTestFile('src/utils.js', 'let helper = null;');

      const rulesFile: RulesFile = {
        domain: 'test-domain',
        version: '1.0.0',
        filePatterns: ['**/*.js'],
        rules: [createVarFinderRule({ language: 'javascript' })],
      };

      const filesToLint = [
        path.join(TEST_DIR, 'src/app.js'),
        path.join(TEST_DIR, 'src/utils.js'),
      ];

      const summary = await lintFiles(filesToLint, rulesFile);

      assert.strictEqual(summary.domain, 'test-domain');
      assert.strictEqual(summary.fileCount, 2);
      assert.strictEqual(summary.results.length, 2);
    });

    it('skips rules with incompatible language', async () => {
      await createTestFile('src/app.ts', 'let typedCount: number = 0;');
      await createTestFile('src/utils.js', 'let jsCount = 0;');

      // Rule is for TypeScript, so it should only match .ts files
      const rulesFile: RulesFile = {
        domain: 'typescript-only',
        version: '1.0.0',
        filePatterns: ['**/*.ts', '**/*.js'],
        rules: [createVarFinderRule({ language: 'typescript' })],
      };

      const filesToLint = [
        path.join(TEST_DIR, 'src/app.ts'),
        path.join(TEST_DIR, 'src/utils.js'),
      ];

      const summary = await lintFiles(filesToLint, rulesFile);

      // Both files are linted, but only TS file matches the rule
      assert.strictEqual(summary.fileCount, 2);
      assert.strictEqual(summary.results.length, 1);
      assert.ok(summary.results[0]?.filePath.endsWith('app.ts'));
    });

    it('rules without language match all files', async () => {
      await createTestFile('src/app.js', 'let jsCount = 0;');
      await createTestFile('src/app.ts', 'let tsCount = 0;');

      // Rule without language applies to all files (like grep rules)
      const rulesFile: RulesFile = {
        domain: 'universal-rule',
        version: '1.0.0',
        filePatterns: ['**/*.ts', '**/*.js'],
        rules: [createVarFinderRule()], // No language = matches all
      };

      const filesToLint = [
        path.join(TEST_DIR, 'src/app.js'),
        path.join(TEST_DIR, 'src/app.ts'),
      ];
      const summary = await lintFiles(filesToLint, rulesFile);

      assert.strictEqual(summary.fileCount, 2);
      assert.strictEqual(summary.results.length, 2);
    });

    it('includes tsx files when rule language is typescript', async () => {
      await createTestFile('src/Component.tsx', 'let componentState = null;');

      const rulesFile: RulesFile = {
        domain: 'typescript-rules',
        version: '1.0.0',
        filePatterns: ['**/*.tsx'],
        rules: [createVarFinderRule({ language: 'typescript' })],
      };

      const filesToLint = [path.join(TEST_DIR, 'src/Component.tsx')];
      const summary = await lintFiles(filesToLint, rulesFile);

      assert.strictEqual(summary.fileCount, 1);
      assert.strictEqual(summary.results.length, 1);
    });
  });
});

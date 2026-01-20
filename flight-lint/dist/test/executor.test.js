import { describe, it, afterEach, before, after } from 'node:test';
import assert from 'node:assert';
import { writeFile, unlink, mkdir, rm } from 'node:fs/promises';
import path from 'node:path';
import { parseFile, getLanguage } from '../src/parser.js';
import { executeRule, lintFile, lintFiles, isLanguageCompatible } from '../src/executor.js';
// Shared test rules - defined once to avoid duplication
// Query node types use tree-sitter naming conventions
const VAR_FINDER_QUERY = '(variable_declarator name: (identifier) @match)';
const FUNC_FINDER_QUERY = '(function_declaration name: (identifier) @match)';
const CLASS_FINDER_QUERY = '(class_declaration name: (identifier) @match)';
function createVarFinderRule(overrides = {}) {
    return {
        id: 'find-vars',
        title: 'Find Variables',
        severity: 'SHOULD',
        query: VAR_FINDER_QUERY,
        message: 'Variable declaration found',
        ...overrides,
    };
}
function createFuncFinderRule(overrides = {}) {
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
    const createdPaths = [];
    before(async () => {
        await mkdir(TEST_DIR, { recursive: true });
    });
    async function createTestFile(relativePath, content) {
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
            }
            catch {
                // Ignore cleanup errors
            }
        }
        createdPaths.length = 0;
    });
    after(async () => {
        try {
            await rm(TEST_DIR, { recursive: true });
        }
        catch {
            // Ignore cleanup errors
        }
    });
    describe('isLanguageCompatible', () => {
        it('returns true for exact language match', () => {
            assert.strictEqual(isLanguageCompatible('javascript', 'javascript'), true);
            assert.strictEqual(isLanguageCompatible('typescript', 'typescript'), true);
        });
        it('returns true for javascript rules on jsx files', () => {
            assert.strictEqual(isLanguageCompatible('jsx', 'javascript'), true);
        });
        it('returns true for typescript rules on tsx files', () => {
            assert.strictEqual(isLanguageCompatible('tsx', 'typescript'), true);
        });
        it('returns false for incompatible languages', () => {
            assert.strictEqual(isLanguageCompatible('typescript', 'javascript'), false);
            assert.strictEqual(isLanguageCompatible('javascript', 'typescript'), false);
        });
        it('returns true for self-match when not in compatibility map', () => {
            assert.strictEqual(isLanguageCompatible('python', 'python'), true);
        });
        it('returns false for different unknown languages', () => {
            assert.strictEqual(isLanguageCompatible('python', 'rust'), false);
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
            const rule = {
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
            const rule = {
                id: 'invalid-query',
                title: 'Invalid Query',
                severity: 'SHOULD',
                query: '(this is not valid query syntax',
                message: 'Should not match',
            };
            assert.throws(() => executeRule(tree, rule, language), (thrown) => {
                const error = thrown;
                return error.message.includes('invalid-query');
            });
        });
    });
    describe('lintFile', () => {
        it('runs all rules on a file and returns results', async () => {
            const filePath = await createTestFile('test.js', `let alpha = 1;
let beta = 2;`);
            const rules = [createVarFinderRule()];
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
            const rules = [
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
            const rulesFile = {
                domain: 'test-domain',
                version: '1.0.0',
                language: 'javascript',
                filePatterns: ['**/*.js'],
                rules: [createVarFinderRule()],
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
        it('skips files with incompatible language', async () => {
            await createTestFile('src/app.ts', 'let typedCount: number = 0;');
            await createTestFile('src/utils.js', 'let jsCount = 0;');
            const rulesFile = {
                domain: 'typescript-only',
                version: '1.0.0',
                language: 'typescript',
                filePatterns: ['**/*.ts'],
                rules: [createVarFinderRule()],
            };
            const filesToLint = [
                path.join(TEST_DIR, 'src/app.ts'),
                path.join(TEST_DIR, 'src/utils.js'),
            ];
            const summary = await lintFiles(filesToLint, rulesFile);
            assert.strictEqual(summary.fileCount, 1);
            assert.strictEqual(summary.results.length, 1);
            assert.ok(summary.results[0]?.filePath.endsWith('app.ts'));
        });
        it('returns empty results when no files match language', async () => {
            await createTestFile('src/app.js', 'let count = 0;');
            const rulesFile = {
                domain: 'typescript-only',
                version: '1.0.0',
                language: 'typescript',
                filePatterns: ['**/*.ts'],
                rules: [createVarFinderRule()],
            };
            const filesToLint = [path.join(TEST_DIR, 'src/app.js')];
            const summary = await lintFiles(filesToLint, rulesFile);
            assert.strictEqual(summary.fileCount, 0);
            assert.strictEqual(summary.results.length, 0);
        });
        it('includes tsx files when language is typescript', async () => {
            await createTestFile('src/Component.tsx', 'let componentState = null;');
            const rulesFile = {
                domain: 'typescript-rules',
                version: '1.0.0',
                language: 'typescript',
                filePatterns: ['**/*.tsx'],
                rules: [createVarFinderRule()],
            };
            const filesToLint = [path.join(TEST_DIR, 'src/Component.tsx')];
            const summary = await lintFiles(filesToLint, rulesFile);
            assert.strictEqual(summary.fileCount, 1);
            assert.strictEqual(summary.results.length, 1);
        });
    });
});

import { describe, it, afterEach, before, after } from 'node:test';
import assert from 'node:assert';
import { writeFile, unlink, mkdir, rm } from 'node:fs/promises';
import path from 'node:path';
import { discoverFiles } from '../src/discovery.js';

describe('discovery', () => {
  const TEST_DIR = `/tmp/flight-lint-discovery-test-${Date.now()}`;
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

  describe('discoverFiles', () => {
    it('discovers files matching a single pattern', async () => {
      await createTestFile('src/index.ts', 'export {}');
      await createTestFile('src/utils.ts', 'export {}');

      const discoveredFiles = await discoverFiles({
        patterns: ['**/*.ts'],
        basePath: TEST_DIR,
      });

      assert.strictEqual(discoveredFiles.length, 2);
      assert.ok(discoveredFiles.some((filePath) => filePath.endsWith('index.ts')));
      assert.ok(discoveredFiles.some((filePath) => filePath.endsWith('utils.ts')));
    });

    it('discovers files matching multiple patterns', async () => {
      await createTestFile('src/app.ts', 'export {}');
      await createTestFile('src/styles.css', 'body {}');
      await createTestFile('src/config.json', '{}');

      const discoveredFiles = await discoverFiles({
        patterns: ['**/*.ts', '**/*.css'],
        basePath: TEST_DIR,
      });

      assert.strictEqual(discoveredFiles.length, 2);
      assert.ok(discoveredFiles.some((filePath) => filePath.endsWith('app.ts')));
      assert.ok(discoveredFiles.some((filePath) => filePath.endsWith('styles.css')));
    });

    it('respects custom exclusion patterns', async () => {
      await createTestFile('src/main.ts', 'export {}');
      await createTestFile('src/test.spec.ts', 'test');
      await createTestFile('src/utils.test.ts', 'test');

      const discoveredFiles = await discoverFiles({
        patterns: ['**/*.ts'],
        excludePatterns: ['**/*.spec.ts', '**/*.test.ts'],
        basePath: TEST_DIR,
      });

      assert.strictEqual(discoveredFiles.length, 1);
      assert.ok(discoveredFiles[0]?.endsWith('main.ts'));
    });

    it('excludes node_modules by default', async () => {
      await createTestFile('src/app.ts', 'export {}');
      await createTestFile('node_modules/pkg/index.ts', 'export {}');

      const discoveredFiles = await discoverFiles({
        patterns: ['**/*.ts'],
        basePath: TEST_DIR,
      });

      assert.strictEqual(discoveredFiles.length, 1);
      assert.ok(discoveredFiles[0]?.endsWith('src/app.ts'));
    });

    it('excludes dist directory by default', async () => {
      await createTestFile('src/app.ts', 'export {}');
      await createTestFile('dist/app.js', 'export {}');

      const discoveredFiles = await discoverFiles({
        patterns: ['**/*.ts', '**/*.js'],
        basePath: TEST_DIR,
      });

      assert.strictEqual(discoveredFiles.length, 1);
      assert.ok(discoveredFiles[0]?.endsWith('src/app.ts'));
    });

    it('returns sorted absolute paths', async () => {
      await createTestFile('z-file.ts', 'export {}');
      await createTestFile('a-file.ts', 'export {}');
      await createTestFile('m-file.ts', 'export {}');

      const discoveredFiles = await discoverFiles({
        patterns: ['*.ts'],
        basePath: TEST_DIR,
      });

      assert.strictEqual(discoveredFiles.length, 3);
      assert.ok(discoveredFiles[0]?.endsWith('a-file.ts'));
      assert.ok(discoveredFiles[1]?.endsWith('m-file.ts'));
      assert.ok(discoveredFiles[2]?.endsWith('z-file.ts'));

      for (const filePath of discoveredFiles) {
        assert.ok(path.isAbsolute(filePath), `Expected absolute path: ${filePath}`);
      }
    });

    it('returns empty array when no files match', async () => {
      const discoveredFiles = await discoverFiles({
        patterns: ['**/*.xyz'],
        basePath: TEST_DIR,
      });

      assert.strictEqual(discoveredFiles.length, 0);
    });
  });
});

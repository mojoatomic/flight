import { describe, it, afterEach } from 'node:test';
import assert from 'node:assert';
import { writeFile, unlink } from 'node:fs/promises';
import { loadRulesFile } from '../src/loader.js';

describe('loader', () => {
  const testFilePaths: string[] = [];

  async function createTestFile(filename: string, content: string): Promise<string> {
    const filePath = `/tmp/${filename}`;
    await writeFile(filePath, content);
    testFilePaths.push(filePath);
    return filePath;
  }

  afterEach(async () => {
    for (const filePath of testFilePaths) {
      try {
        await unlink(filePath);
      } catch {
        // Ignore cleanup errors
      }
    }
    testFilePaths.length = 0;
  });

  const validRulesContent = {
    domain: 'test-domain',
    version: '1.0.0',
    language: 'javascript',
    file_patterns: ['**/*.js'],
    rules: [
      {
        id: 'N1',
        title: 'Test Rule',
        severity: 'NEVER',
        query: '(identifier) @match',
        message: 'Found identifier'
      }
    ]
  };

  describe('loadRulesFile', () => {
    it('loads and parses valid rules file', async () => {
      const filePath = await createTestFile('valid-rules.json', JSON.stringify(validRulesContent));

      const rulesFile = await loadRulesFile(filePath);

      assert.strictEqual(rulesFile.domain, 'test-domain');
      assert.strictEqual(rulesFile.version, '1.0.0');
      assert.strictEqual(rulesFile.language, 'javascript');
      assert.strictEqual(rulesFile.rules.length, 1);
      assert.strictEqual(rulesFile.rules[0]?.id, 'N1');
      assert.strictEqual(rulesFile.rules[0]?.severity, 'NEVER');
    });

    it('throws with file path on read error', async () => {
      await assert.rejects(
        loadRulesFile('/nonexistent/path/rules.json'),
        /Failed to read rules file:.*nonexistent/
      );
    });

    it('throws with file path on invalid JSON', async () => {
      const filePath = await createTestFile('invalid.json', '{ not valid json }');

      await assert.rejects(
        loadRulesFile(filePath),
        /Invalid JSON in rules file:/
      );
    });

    it('throws with field name on missing domain', async () => {
      const invalidContent = { ...validRulesContent, domain: undefined };
      const filePath = await createTestFile('missing-domain.json', JSON.stringify(invalidContent));

      await assert.rejects(
        loadRulesFile(filePath),
        /Missing or invalid 'domain'/
      );
    });

    it('throws with field name on missing version', async () => {
      const invalidContent = { ...validRulesContent, version: undefined };
      const filePath = await createTestFile('missing-version.json', JSON.stringify(invalidContent));

      await assert.rejects(
        loadRulesFile(filePath),
        /Missing or invalid 'version'/
      );
    });

    it('throws on missing file_patterns', async () => {
      const invalidContent = { ...validRulesContent, file_patterns: undefined };
      const filePath = await createTestFile('missing-patterns.json', JSON.stringify(invalidContent));

      await assert.rejects(
        loadRulesFile(filePath),
        /Missing or invalid 'file_patterns'/
      );
    });

    it('throws on missing rules array', async () => {
      const invalidContent = { ...validRulesContent, rules: undefined };
      const filePath = await createTestFile('missing-rules.json', JSON.stringify(invalidContent));

      await assert.rejects(
        loadRulesFile(filePath),
        /Missing or invalid 'rules' array/
      );
    });

    it('throws on rule missing required field', async () => {
      const invalidContent = {
        ...validRulesContent,
        rules: [{ id: 'N1', title: 'Test' }] // missing severity, query, message
      };
      const filePath = await createTestFile('invalid-rule.json', JSON.stringify(invalidContent));

      await assert.rejects(
        loadRulesFile(filePath),
        /Rule 0 missing 'severity'/
      );
    });

    it('throws on invalid severity value', async () => {
      const invalidContent = {
        ...validRulesContent,
        rules: [{
          id: 'N1',
          title: 'Test',
          severity: 'INVALID',
          query: '(id)',
          message: 'msg'
        }]
      };
      const filePath = await createTestFile('invalid-severity.json', JSON.stringify(invalidContent));

      await assert.rejects(
        loadRulesFile(filePath),
        /Rule 0 has invalid severity 'INVALID'/
      );
    });

    it('loads file with multiple rules', async () => {
      const multiRuleContent = {
        ...validRulesContent,
        rules: [
          { id: 'N1', title: 'Rule 1', severity: 'NEVER', query: '(a)', message: 'msg1' },
          { id: 'M1', title: 'Rule 2', severity: 'MUST', query: '(b)', message: 'msg2' },
          { id: 'S1', title: 'Rule 3', severity: 'SHOULD', query: '(c)', message: 'msg3' },
        ]
      };
      const filePath = await createTestFile('multi-rules.json', JSON.stringify(multiRuleContent));

      const rulesFile = await loadRulesFile(filePath);

      assert.strictEqual(rulesFile.rules.length, 3);
      assert.strictEqual(rulesFile.rules[0]?.severity, 'NEVER');
      assert.strictEqual(rulesFile.rules[1]?.severity, 'MUST');
      assert.strictEqual(rulesFile.rules[2]?.severity, 'SHOULD');
    });

    it('loads file with optional provenance', async () => {
      const contentWithProvenance = {
        ...validRulesContent,
        provenance: {
          last_full_audit: '2026-01-20',
          audited_by: 'test'
        }
      };
      const filePath = await createTestFile('with-provenance.json', JSON.stringify(contentWithProvenance));

      const rulesFile = await loadRulesFile(filePath);

      assert.strictEqual(rulesFile.provenance?.lastFullAudit, '2026-01-20');
    });
  });
});

import { describe, it } from 'node:test';
import assert from 'node:assert';
import { parseFile, detectLanguage, getLanguage } from '../src/parser.js';

describe('parser', () => {
  describe('parseFile', () => {
    it('parses JavaScript and returns program root', async () => {
      const syntaxTree = await parseFile('let count = 1;', 'javascript');

      assert.strictEqual(syntaxTree.rootNode.type, 'program');
    });

    it('parses TypeScript and returns program root', async () => {
      const syntaxTree = await parseFile('let count: number = 1;', 'typescript');

      assert.strictEqual(syntaxTree.rootNode.type, 'program');
    });

    it('parses JSX correctly', async () => {
      const syntaxTree = await parseFile('let element = <div>Hello</div>;', 'jsx');

      assert.strictEqual(syntaxTree.rootNode.type, 'program');
    });

    it('parses TSX correctly', async () => {
      const syntaxTree = await parseFile('let element: JSX.Element = <div>Hello</div>;', 'tsx');

      assert.strictEqual(syntaxTree.rootNode.type, 'program');
    });
  });

  describe('detectLanguage', () => {
    it('detects .js as javascript', () => {
      assert.strictEqual(detectLanguage('foo.js'), 'javascript');
    });

    it('detects .mjs as javascript', () => {
      assert.strictEqual(detectLanguage('foo.mjs'), 'javascript');
    });

    it('detects .cjs as javascript', () => {
      assert.strictEqual(detectLanguage('foo.cjs'), 'javascript');
    });

    it('detects .jsx as jsx', () => {
      assert.strictEqual(detectLanguage('component.jsx'), 'jsx');
    });

    it('detects .ts as typescript', () => {
      assert.strictEqual(detectLanguage('bar.ts'), 'typescript');
    });

    it('detects .mts as typescript', () => {
      assert.strictEqual(detectLanguage('bar.mts'), 'typescript');
    });

    it('detects .cts as typescript', () => {
      assert.strictEqual(detectLanguage('bar.cts'), 'typescript');
    });

    it('detects .tsx as tsx', () => {
      assert.strictEqual(detectLanguage('component.tsx'), 'tsx');
    });

    it('returns null for unknown extension', () => {
      assert.strictEqual(detectLanguage('file.unknown'), null);
    });

    it('handles file paths with directories', () => {
      assert.strictEqual(detectLanguage('src/components/Button.tsx'), 'tsx');
    });
  });

  describe('getLanguage', () => {
    it('returns language for javascript', async () => {
      const language = await getLanguage('javascript');

      assert.ok(language, 'Language should be defined');
    });

    it('returns language for typescript', async () => {
      const language = await getLanguage('typescript');

      assert.ok(language, 'Language should be defined');
    });

    it('caches language on second call', async () => {
      const firstCall = await getLanguage('javascript');
      const secondCall = await getLanguage('javascript');

      assert.strictEqual(firstCall, secondCall, 'Should return cached language');
    });

    it('throws for unsupported language', async () => {
      await assert.rejects(
        getLanguage('cobol'),
        /Unsupported language: cobol/
      );
    });
  });
});

import { describe, it } from 'node:test';
import assert from 'node:assert';
import { parseArgs } from '../src/cli.js';
describe('CLI argument parsing', () => {
    it('parses default options with no arguments', () => {
        const parsedArgs = parseArgs(['node', 'flight-lint']);
        assert.strictEqual(parsedArgs.options.auto, false);
        assert.strictEqual(parsedArgs.options.format, 'pretty');
        assert.strictEqual(parsedArgs.options.severity, 'SHOULD');
        assert.deepStrictEqual(parsedArgs.rulesFiles, []);
    });
    it('parses --auto flag', () => {
        const parsedArgs = parseArgs(['node', 'flight-lint', '--auto']);
        assert.strictEqual(parsedArgs.options.auto, true);
    });
    it('parses --format option', () => {
        const parsedArgs = parseArgs(['node', 'flight-lint', '--format', 'json']);
        assert.strictEqual(parsedArgs.options.format, 'json');
    });
    it('parses --severity option', () => {
        const parsedArgs = parseArgs(['node', 'flight-lint', '--severity', 'MUST']);
        assert.strictEqual(parsedArgs.options.severity, 'MUST');
    });
    it('parses rules file arguments', () => {
        const parsedArgs = parseArgs(['node', 'flight-lint', 'test.rules.json', 'other.rules.json']);
        assert.deepStrictEqual(parsedArgs.rulesFiles, ['test.rules.json', 'other.rules.json']);
    });
    it('parses combined options and arguments', () => {
        const parsedArgs = parseArgs([
            'node',
            'flight-lint',
            '--auto',
            '--format',
            'sarif',
            '--severity',
            'NEVER',
            'rules.json',
        ]);
        assert.strictEqual(parsedArgs.options.auto, true);
        assert.strictEqual(parsedArgs.options.format, 'sarif');
        assert.strictEqual(parsedArgs.options.severity, 'NEVER');
        assert.deepStrictEqual(parsedArgs.rulesFiles, ['rules.json']);
    });
});

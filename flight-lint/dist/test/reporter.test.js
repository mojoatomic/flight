import { describe, it } from 'node:test';
import assert from 'node:assert';
import { formatResults, formatPretty, formatJson, formatSarif, groupBySeverity, groupByRule, getExitCode, } from '../src/reporter.js';
describe('reporter', () => {
    const sampleResults = [
        {
            filePath: '/src/app.ts',
            line: 10,
            column: 5,
            ruleId: 'N1',
            severity: 'NEVER',
            message: 'Generic variable name: data',
        },
        {
            filePath: '/src/app.ts',
            line: 20,
            column: 3,
            ruleId: 'M1',
            severity: 'MUST',
            message: 'Boolean variable missing prefix',
        },
        {
            filePath: '/src/utils.ts',
            line: 5,
            column: 1,
            ruleId: 'S1',
            severity: 'SHOULD',
            message: 'Consider using async prefix',
        },
    ];
    const sampleSummary = {
        domain: 'code-hygiene',
        fileCount: 5,
        results: sampleResults,
    };
    const emptySummary = {
        domain: 'code-hygiene',
        fileCount: 3,
        results: [],
    };
    describe('formatResults', () => {
        it('formats results with pretty format', () => {
            const output = formatResults(sampleSummary, 'pretty');
            assert.ok(output.includes('code-hygiene'));
            assert.ok(output.includes('Files scanned: 5'));
            assert.ok(output.includes('app.ts'));
        });
        it('formats results with json format', () => {
            const output = formatResults(sampleSummary, 'json');
            const parsed = JSON.parse(output);
            assert.strictEqual(parsed.domain, 'code-hygiene');
            assert.strictEqual(parsed.fileCount, 5);
            assert.strictEqual(parsed.results.length, 3);
        });
        it('formats results with sarif format', () => {
            const output = formatResults(sampleSummary, 'sarif');
            const parsed = JSON.parse(output);
            assert.strictEqual(parsed.version, '2.1.0');
            assert.ok(parsed.$schema.includes('sarif'));
            assert.strictEqual(parsed.runs[0].results.length, 3);
        });
    });
    describe('formatPretty', () => {
        it('shows domain and file count', () => {
            const output = formatPretty(sampleSummary);
            assert.ok(output.includes('code-hygiene'));
            assert.ok(output.includes('Files scanned: 5'));
        });
        it('groups results by file', () => {
            const output = formatPretty(sampleSummary);
            assert.ok(output.includes('/src/app.ts'));
            assert.ok(output.includes('/src/utils.ts'));
        });
        it('shows error and warning counts', () => {
            const output = formatPretty(sampleSummary);
            assert.ok(output.includes('2 error(s)'));
            assert.ok(output.includes('1 warning(s)'));
        });
        it('shows success message when no violations', () => {
            const output = formatPretty(emptySummary);
            assert.ok(output.includes('No violations found'));
        });
    });
    describe('formatJson', () => {
        it('produces valid JSON', () => {
            const output = formatJson(sampleSummary);
            assert.doesNotThrow(() => JSON.parse(output));
        });
        it('includes all summary fields', () => {
            const output = formatJson(sampleSummary);
            const parsed = JSON.parse(output);
            assert.strictEqual(parsed.domain, 'code-hygiene');
            assert.strictEqual(parsed.fileCount, 5);
            assert.strictEqual(parsed.results.length, 3);
        });
        it('includes all result fields', () => {
            const output = formatJson(sampleSummary);
            const parsed = JSON.parse(output);
            const firstResult = parsed.results[0];
            assert.strictEqual(firstResult.filePath, '/src/app.ts');
            assert.strictEqual(firstResult.line, 10);
            assert.strictEqual(firstResult.column, 5);
            assert.strictEqual(firstResult.ruleId, 'N1');
            assert.strictEqual(firstResult.severity, 'NEVER');
            assert.strictEqual(firstResult.message, 'Generic variable name: data');
        });
    });
    describe('formatSarif', () => {
        it('produces valid SARIF 2.1.0', () => {
            const output = formatSarif(sampleSummary);
            const parsed = JSON.parse(output);
            assert.strictEqual(parsed.version, '2.1.0');
            assert.ok(parsed.$schema.includes('sarif-schema-2.1.0'));
        });
        it('includes tool information', () => {
            const output = formatSarif(sampleSummary);
            const parsed = JSON.parse(output);
            const driver = parsed.runs[0].tool.driver;
            assert.strictEqual(driver.name, 'flight-lint');
            assert.strictEqual(driver.version, '1.0.0');
        });
        it('maps NEVER/MUST to error level', () => {
            const output = formatSarif(sampleSummary);
            const parsed = JSON.parse(output);
            const sarifResults = parsed.runs[0].results;
            const neverResult = sarifResults.find((sarifResult) => sarifResult.ruleId === 'N1');
            const mustResult = sarifResults.find((sarifResult) => sarifResult.ruleId === 'M1');
            assert.strictEqual(neverResult.level, 'error');
            assert.strictEqual(mustResult.level, 'error');
        });
        it('maps SHOULD to warning level', () => {
            const output = formatSarif(sampleSummary);
            const parsed = JSON.parse(output);
            const sarifResults = parsed.runs[0].results;
            const shouldResult = sarifResults.find((sarifResult) => sarifResult.ruleId === 'S1');
            assert.strictEqual(shouldResult.level, 'warning');
        });
        it('includes location information', () => {
            const output = formatSarif(sampleSummary);
            const parsed = JSON.parse(output);
            const firstResult = parsed.runs[0].results[0];
            const location = firstResult.locations[0].physicalLocation;
            assert.strictEqual(location.artifactLocation.uri, '/src/app.ts');
            assert.strictEqual(location.region.startLine, 10);
            assert.strictEqual(location.region.startColumn, 5);
        });
    });
    describe('groupBySeverity', () => {
        it('groups results by severity', () => {
            const grouped = groupBySeverity(sampleResults);
            assert.strictEqual(grouped.get('NEVER')?.length, 1);
            assert.strictEqual(grouped.get('MUST')?.length, 1);
            assert.strictEqual(grouped.get('SHOULD')?.length, 1);
        });
        it('returns empty map for empty results', () => {
            const grouped = groupBySeverity([]);
            assert.strictEqual(grouped.size, 0);
        });
    });
    describe('groupByRule', () => {
        it('groups results by rule ID', () => {
            const grouped = groupByRule(sampleResults);
            assert.strictEqual(grouped.get('N1')?.length, 1);
            assert.strictEqual(grouped.get('M1')?.length, 1);
            assert.strictEqual(grouped.get('S1')?.length, 1);
        });
        it('combines multiple results for same rule', () => {
            const multipleN1 = [
                { filePath: '/a.ts', line: 1, column: 1, ruleId: 'N1', severity: 'NEVER', message: 'msg1' },
                { filePath: '/b.ts', line: 2, column: 2, ruleId: 'N1', severity: 'NEVER', message: 'msg2' },
            ];
            const grouped = groupByRule(multipleN1);
            assert.strictEqual(grouped.get('N1')?.length, 2);
        });
    });
    describe('getExitCode', () => {
        it('returns 1 for NEVER violations', () => {
            const neverResults = [
                { filePath: '/a.ts', line: 1, column: 1, ruleId: 'N1', severity: 'NEVER', message: 'error' },
            ];
            assert.strictEqual(getExitCode(neverResults), 1);
        });
        it('returns 1 for MUST violations', () => {
            const mustResults = [
                { filePath: '/a.ts', line: 1, column: 1, ruleId: 'M1', severity: 'MUST', message: 'error' },
            ];
            assert.strictEqual(getExitCode(mustResults), 1);
        });
        it('returns 0 for SHOULD-only violations', () => {
            const shouldResults = [
                { filePath: '/a.ts', line: 1, column: 1, ruleId: 'S1', severity: 'SHOULD', message: 'warning' },
            ];
            assert.strictEqual(getExitCode(shouldResults), 0);
        });
        it('returns 0 for GUIDANCE-only violations', () => {
            const guidanceResults = [
                { filePath: '/a.ts', line: 1, column: 1, ruleId: 'G1', severity: 'GUIDANCE', message: 'info' },
            ];
            assert.strictEqual(getExitCode(guidanceResults), 0);
        });
        it('returns 0 for no violations', () => {
            assert.strictEqual(getExitCode([]), 0);
        });
        it('returns 1 when mixed with failures', () => {
            const mixedResults = [
                { filePath: '/a.ts', line: 1, column: 1, ruleId: 'S1', severity: 'SHOULD', message: 'warning' },
                { filePath: '/b.ts', line: 2, column: 2, ruleId: 'N1', severity: 'NEVER', message: 'error' },
            ];
            assert.strictEqual(getExitCode(mixedResults), 1);
        });
    });
});

# Task 004: File Discovery and Reporter

## Depends On
- 001-flight-lint-scaffold
- 003-rules-loader

## Delivers
- `src/discovery.ts` - Find files matching patterns, respecting exclusions
- `src/reporter.ts` - Format results (pretty, JSON, SARIF)
- File discovery using fast-glob
- Colored terminal output with chalk
- Tests for both modules

## NOT In Scope
- Query execution (Task 005)
- Tree-sitter parsing (Task 002)
- CLI integration (already done in Task 001)
- Watch mode (future enhancement)

## Acceptance Criteria
- [ ] `discoverFiles(patterns, excludes, basePath)` returns matching files
- [ ] Exclusion patterns work (node_modules, dist, etc.)
- [ ] `formatResults(results, 'pretty')` produces colored output
- [ ] `formatResults(results, 'json')` produces valid JSON
- [ ] Pass/fail counts are correct in output
- [ ] Exit code logic: failures = 1, no failures = 0
- [ ] Tests pass: `npm test`
- [ ] `.flight/validate-all.sh` passes

## Domain Constraints
Load these before starting:
- code-hygiene.md (always)
- typescript.md

## Context

File discovery finds all files matching the patterns from `.rules.json`. The reporter formats the linting results for display.

This task builds both components so they can be integrated with the query execution in Task 005.

## Technical Notes

### src/discovery.ts

```typescript
import fg from 'fast-glob';
import { resolve } from 'path';

export interface DiscoveryOptions {
  patterns: string[];
  exclude?: string[];
  basePath?: string;
}

export async function discoverFiles(options: DiscoveryOptions): Promise<string[]> {
  const { patterns, exclude = [], basePath = process.cwd() } = options;

  const defaultExcludes = [
    '**/node_modules/**',
    '**/dist/**',
    '**/build/**',
    '**/.git/**',
  ];

  const allExcludes = [...defaultExcludes, ...exclude];

  const files = await fg(patterns, {
    cwd: basePath,
    absolute: true,
    ignore: allExcludes,
    onlyFiles: true,
  });

  return files.sort();
}
```

### src/reporter.ts

```typescript
import chalk from 'chalk';
import { Severity } from './types.js';

export interface LintResult {
  file: string;
  line: number;
  column: number;
  ruleId: string;
  ruleTitle: string;
  severity: Severity;
  message: string;
}

export interface LintSummary {
  domain: string;
  fileCount: number;
  results: LintResult[];
  provenance?: {
    lastAudit?: string;
    nextDue?: string;
  };
}

export type OutputFormat = 'pretty' | 'json' | 'sarif';

export function formatResults(summary: LintSummary, format: OutputFormat): string {
  switch (format) {
    case 'json':
      return formatJson(summary);
    case 'sarif':
      return formatSarif(summary);
    default:
      return formatPretty(summary);
  }
}

function formatPretty(summary: LintSummary): string {
  const lines: string[] = [];
  const sep = '═'.repeat(43);

  lines.push(sep);
  lines.push(`  ${summary.domain.toUpperCase()} Domain Validation`);
  if (summary.provenance?.lastAudit) {
    lines.push(`  Last audit: ${summary.provenance.lastAudit}`);
  }
  lines.push(sep);
  lines.push('');
  lines.push(`Files: ${summary.fileCount}`);
  lines.push('');

  // Group by severity
  const bySeverity = groupBySeverity(summary.results);

  for (const severity of ['NEVER', 'MUST', 'SHOULD'] as Severity[]) {
    const results = bySeverity.get(severity) || [];
    if (results.length > 0) {
      lines.push(`## ${severity} Rules`);

      // Group by rule
      const byRule = groupByRule(results);
      for (const [ruleId, ruleResults] of byRule) {
        const first = ruleResults[0];
        const icon = severity === 'SHOULD' ? chalk.yellow('⚠️ ') : chalk.red('❌');
        lines.push(`${icon} ${ruleId}: ${first.ruleTitle}`);

        for (const result of ruleResults) {
          const relPath = result.file.replace(process.cwd() + '/', '');
          lines.push(`   ${relPath}:${result.line}:${result.column} - ${result.message}`);
        }
      }
      lines.push('');
    }
  }

  // Summary
  const failures = summary.results.filter(r => r.severity === 'NEVER' || r.severity === 'MUST').length;
  const warnings = summary.results.filter(r => r.severity === 'SHOULD').length;
  const passes = 0; // We only track violations

  lines.push(sep);
  lines.push(`  FAIL: ${failures}  WARN: ${warnings}`);
  lines.push(`  RESULT: ${failures > 0 ? chalk.red('FAIL') : chalk.green('PASS')}`);
  lines.push(sep);

  return lines.join('\n');
}

function formatJson(summary: LintSummary): string {
  return JSON.stringify({
    domain: summary.domain,
    fileCount: summary.fileCount,
    results: summary.results,
    summary: {
      failures: summary.results.filter(r => r.severity === 'NEVER' || r.severity === 'MUST').length,
      warnings: summary.results.filter(r => r.severity === 'SHOULD').length,
    }
  }, null, 2);
}

function formatSarif(summary: LintSummary): string {
  // SARIF 2.1.0 format for GitHub/VS Code integration
  const sarif = {
    version: '2.1.0',
    '$schema': 'https://raw.githubusercontent.com/oasis-tcs/sarif-spec/master/Schemata/sarif-schema-2.1.0.json',
    runs: [{
      tool: {
        driver: {
          name: 'flight-lint',
          version: '0.1.0',
          informationUri: 'https://github.com/mojoatomic/flight',
          rules: [], // Could populate from rules
        }
      },
      results: summary.results.map(r => ({
        ruleId: r.ruleId,
        level: r.severity === 'SHOULD' ? 'warning' : 'error',
        message: { text: r.message },
        locations: [{
          physicalLocation: {
            artifactLocation: { uri: r.file },
            region: { startLine: r.line, startColumn: r.column }
          }
        }]
      }))
    }]
  };
  return JSON.stringify(sarif, null, 2);
}

function groupBySeverity(results: LintResult[]): Map<Severity, LintResult[]> {
  const map = new Map<Severity, LintResult[]>();
  for (const result of results) {
    const existing = map.get(result.severity) || [];
    existing.push(result);
    map.set(result.severity, existing);
  }
  return map;
}

function groupByRule(results: LintResult[]): Map<string, LintResult[]> {
  const map = new Map<string, LintResult[]>();
  for (const result of results) {
    const existing = map.get(result.ruleId) || [];
    existing.push(result);
    map.set(result.ruleId, existing);
  }
  return map;
}

export function getExitCode(results: LintResult[]): number {
  const hasFailures = results.some(r => r.severity === 'NEVER' || r.severity === 'MUST');
  return hasFailures ? 1 : 0;
}
```

### Test Files

Create `test/discovery.test.ts` and `test/reporter.test.ts` with basic tests.

## Validation
Run after implementing:
```bash
cd flight-lint
npm run build
npm test
cd ..
.flight/validate-all.sh
```

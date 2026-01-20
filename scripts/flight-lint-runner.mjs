#!/usr/bin/env node
/**
 * Temporary runner for flight-lint executor.
 * Bypasses CLI to test AST query validation directly.
 *
 * Usage: node scripts/flight-lint-runner.mjs <rules-file> <source-file> [--format json]
 */

import { loadRulesFile } from '../flight-lint/dist/src/loader.js';
import { lintFiles } from '../flight-lint/dist/src/executor.js';
import { formatResults } from '../flight-lint/dist/src/reporter.js';

async function main() {
  const args = process.argv.slice(2);

  if (args.length < 2) {
    console.error('Usage: flight-lint-runner.mjs <rules-file> <source-file> [--format json|pretty]');
    process.exit(1);
  }

  const rulesPath = args[0];
  const sourcePath = args[1];
  const formatArg = args.includes('--format') ? args[args.indexOf('--format') + 1] : 'pretty';
  const format = formatArg === 'json' ? 'json' : 'pretty';

  try {
    // Load rules file
    const rulesFile = await loadRulesFile(rulesPath);

    // Lint the file
    const summary = await lintFiles([sourcePath], rulesFile);

    // Output results
    if (format === 'json') {
      const output = {
        domain: summary.domain,
        fileCount: summary.fileCount,
        results: summary.results,
        summary: {
          total: summary.results.length,
          byRule: {}
        }
      };

      // Group by rule
      for (const result of summary.results) {
        if (!output.summary.byRule[result.ruleId]) {
          output.summary.byRule[result.ruleId] = 0;
        }
        output.summary.byRule[result.ruleId]++;
      }

      console.log(JSON.stringify(output, null, 2));
    } else {
      // Pretty format
      const formatted = formatResults(summary.results, 'pretty', 'SHOULD');
      console.log(formatted);
      console.log(`\nTotal: ${summary.results.length} violations`);
    }

  } catch (error) {
    console.error('Error:', error.message);
    process.exit(1);
  }
}

main();

import chalk from 'chalk';
const SARIF_SCHEMA = 'https://raw.githubusercontent.com/oasis-tcs/sarif-spec/master/Schemata/sarif-schema-2.1.0.json';
const SARIF_VERSION = '2.1.0';
const TOOL_NAME = 'flight-lint';
const TOOL_VERSION = '1.0.0';
/**
 * Map severity to SARIF level.
 */
function mapSeverityToSarifLevel(severity) {
    switch (severity) {
        case 'NEVER':
        case 'MUST':
            return 'error';
        case 'SHOULD':
            return 'warning';
        case 'GUIDANCE':
            return 'note';
    }
}
/**
 * Format lint results in the specified output format.
 * @param summary - The lint summary to format
 * @param format - Output format (pretty, json, sarif)
 * @returns Formatted string output
 */
export function formatResults(summary, format) {
    switch (format) {
        case 'pretty':
            return formatPretty(summary);
        case 'json':
            return formatJson(summary);
        case 'sarif':
            return formatSarif(summary);
    }
}
/**
 * Format lint results as colored terminal output.
 * @param summary - The lint summary to format
 * @returns Colored terminal string
 */
export function formatPretty(summary) {
    const lines = [];
    const { domain, fileCount, results } = summary;
    lines.push(chalk.bold(`\n${domain}`));
    lines.push(chalk.dim(`Files scanned: ${fileCount}`));
    lines.push('');
    if (results.length === 0) {
        lines.push(chalk.green('✓ No violations found'));
        return lines.join('\n');
    }
    const groupedByFile = new Map();
    for (const lintResult of results) {
        const existing = groupedByFile.get(lintResult.filePath) ?? [];
        existing.push(lintResult);
        groupedByFile.set(lintResult.filePath, existing);
    }
    for (const [filePath, fileResults] of groupedByFile) {
        lines.push(chalk.underline(filePath));
        for (const lintResult of fileResults) {
            const location = chalk.dim(`${lintResult.line}:${lintResult.column}`);
            const severityColor = getSeverityColor(lintResult.severity);
            const severityLabel = severityColor(lintResult.severity.padEnd(8));
            const ruleId = chalk.dim(`[${lintResult.ruleId}]`);
            lines.push(`  ${location}  ${severityLabel} ${lintResult.message} ${ruleId}`);
        }
        lines.push('');
    }
    const errorCount = countFailures(results);
    const warningCount = results.length - errorCount;
    if (errorCount > 0) {
        lines.push(chalk.red(`✗ ${errorCount} error(s)`));
    }
    if (warningCount > 0) {
        lines.push(chalk.yellow(`⚠ ${warningCount} warning(s)`));
    }
    return lines.join('\n');
}
/**
 * Get chalk color function for severity.
 */
function getSeverityColor(severity) {
    switch (severity) {
        case 'NEVER':
        case 'MUST':
            return chalk.red;
        case 'SHOULD':
            return chalk.yellow;
        case 'GUIDANCE':
            return chalk.blue;
    }
}
/**
 * Format lint results as JSON.
 * @param summary - The lint summary to format
 * @returns JSON string
 */
export function formatJson(summary) {
    return JSON.stringify(summary, null, 2);
}
/**
 * Format lint results as SARIF 2.1.0.
 * @param summary - The lint summary to format
 * @returns SARIF JSON string
 */
export function formatSarif(summary) {
    const sarifResults = summary.results.map((lintResult) => ({
        ruleId: lintResult.ruleId,
        level: mapSeverityToSarifLevel(lintResult.severity),
        message: {
            text: lintResult.message,
        },
        locations: [
            {
                physicalLocation: {
                    artifactLocation: {
                        uri: lintResult.filePath,
                    },
                    region: {
                        startLine: lintResult.line,
                        startColumn: lintResult.column,
                    },
                },
            },
        ],
    }));
    const sarifOutput = {
        $schema: SARIF_SCHEMA,
        version: SARIF_VERSION,
        runs: [
            {
                tool: {
                    driver: {
                        name: TOOL_NAME,
                        version: TOOL_VERSION,
                        rules: [],
                    },
                },
                results: sarifResults,
            },
        ],
    };
    return JSON.stringify(sarifOutput, null, 2);
}
/**
 * Group lint results by severity.
 * @param results - Array of lint results
 * @returns Map of severity to results
 */
export function groupBySeverity(results) {
    const grouped = new Map();
    for (const lintResult of results) {
        const existing = grouped.get(lintResult.severity) ?? [];
        existing.push(lintResult);
        grouped.set(lintResult.severity, existing);
    }
    return grouped;
}
/**
 * Group lint results by rule ID.
 * @param results - Array of lint results
 * @returns Map of rule ID to results
 */
export function groupByRule(results) {
    const grouped = new Map();
    for (const lintResult of results) {
        const existing = grouped.get(lintResult.ruleId) ?? [];
        existing.push(lintResult);
        grouped.set(lintResult.ruleId, existing);
    }
    return grouped;
}
/**
 * Count results that are failures (NEVER or MUST severity).
 */
function countFailures(results) {
    return results.filter((lintResult) => lintResult.severity === 'NEVER' || lintResult.severity === 'MUST').length;
}
/**
 * Get exit code based on lint results.
 * Returns 1 if there are NEVER or MUST violations, 0 otherwise.
 * @param results - Array of lint results
 * @returns Exit code (0 or 1)
 */
export function getExitCode(results) {
    const hasFailures = results.some((lintResult) => lintResult.severity === 'NEVER' || lintResult.severity === 'MUST');
    return hasFailures ? 1 : 0;
}

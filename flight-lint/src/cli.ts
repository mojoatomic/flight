import { Command } from 'commander';
import type { CliOptions, OutputFormat, ParsedArgs, Severity, LintResult } from './types.js';
import { discoverFiles, discoverRulesFiles } from './discovery.js';
import { loadRulesFile } from './loader.js';
import { lintFiles } from './executor.js';
import { formatResults, getExitCode } from './reporter.js';

const VERSION = '0.1.0';

const VALID_FORMATS: readonly OutputFormat[] = ['pretty', 'json', 'sarif'];
const VALID_SEVERITIES: readonly Severity[] = ['NEVER', 'MUST', 'SHOULD', 'GUIDANCE'];

const EXIT_SUCCESS = 0;
const EXIT_VIOLATIONS = 1;
const EXIT_CONFIG_ERROR = 2;

/**
 * Validate that a format string is a valid OutputFormat.
 */
function isValidFormat(format: string): format is OutputFormat {
  return VALID_FORMATS.includes(format as OutputFormat);
}

/**
 * Validate that a severity string is a valid Severity.
 */
function isValidSeverity(severity: string): severity is Severity {
  return VALID_SEVERITIES.includes(severity as Severity);
}

/**
 * Create and configure a new Command instance.
 */
function createProgram(): Command {
  const commandProgram = new Command();

  commandProgram
    .name('flight-lint')
    .version(VERSION)
    .description('AST-based linter for Flight domains')
    .argument('[rules-files...]', 'One or more .rules.json files')
    .option('--auto', 'Auto-discover .rules.json files in .flight/domains/')
    .option('--format <type>', 'Output format: pretty, json, sarif', 'pretty')
    .option('--severity <level>', 'Minimum severity: NEVER, MUST, SHOULD', 'SHOULD');

  return commandProgram;
}

/**
 * Parse command line arguments and return structured ParsedArgs.
 */
export function parseArgs(argv: readonly string[]): ParsedArgs {
  const commandProgram = createProgram();

  commandProgram.parse(argv as string[]);

  const parsedOptions = commandProgram.opts<{ auto?: boolean; format?: string; severity?: string }>();
  const rulesFiles = commandProgram.args;

  const formatValue = parsedOptions.format ?? 'pretty';
  const severityValue = parsedOptions.severity ?? 'SHOULD';

  if (!isValidFormat(formatValue)) {
    throw new Error(`Invalid format '${formatValue}'. Valid: ${VALID_FORMATS.join(', ')}`);
  }

  if (!isValidSeverity(severityValue)) {
    throw new Error(`Invalid severity '${severityValue}'. Valid: ${VALID_SEVERITIES.join(', ')}`);
  }

  const cliOptions: CliOptions = {
    auto: Boolean(parsedOptions.auto),
    format: formatValue,
    severity: severityValue,
  };

  return {
    rulesFiles,
    targetPaths: [], // Will be populated in future tasks
    options: cliOptions,
  };
}

/**
 * Collect all rules file paths from explicit args and auto-discovery.
 * @param parsedArgs - Parsed CLI arguments
 * @param projectRoot - Project root directory for auto-discovery
 * @returns Array of rules file paths
 */
async function collectRulesFilePaths(
  parsedArgs: ParsedArgs,
  projectRoot: string
): Promise<string[]> {
  const rulesFilePaths: string[] = [...parsedArgs.rulesFiles];

  if (parsedArgs.options.auto) {
    const discoveredPaths = await discoverRulesFiles(projectRoot);
    rulesFilePaths.push(...discoveredPaths);
  }

  return rulesFilePaths;
}

/**
 * Filter results by minimum severity level.
 * @param allResults - All lint results
 * @param minimumSeverity - Minimum severity to include
 * @returns Filtered results
 */
function filterResultsBySeverity(
  allResults: readonly LintResult[],
  minimumSeverity: Severity
): LintResult[] {
  const severityOrder: Record<Severity, number> = {
    NEVER: 0,
    MUST: 1,
    SHOULD: 2,
    GUIDANCE: 3,
  };

  const minimumLevel = severityOrder[minimumSeverity];

  return allResults.filter(
    (lintResult) => severityOrder[lintResult.severity] <= minimumLevel
  );
}

/**
 * Main linting orchestration function.
 * Discovers rules, loads them, lints files, and outputs results.
 * @param parsedArgs - Parsed CLI arguments
 * @returns Exit code (0 = success, 1 = violations, 2 = config error)
 */
async function runLinting(parsedArgs: ParsedArgs): Promise<number> {
  const projectRoot = process.cwd();

  // Collect all rules file paths
  const rulesFilePaths = await collectRulesFilePaths(parsedArgs, projectRoot);

  // Handle no rules files found
  if (rulesFilePaths.length === 0) {
    if (parsedArgs.options.auto) {
      process.stdout.write('No .rules.json files found in .flight/domains/\n');
      return EXIT_SUCCESS;
    }
    // No rules files and not auto mode - show help (handled in runCli)
    return EXIT_SUCCESS;
  }

  const allResults: LintResult[] = [];

  // Process each rules file
  for (const rulesFilePath of rulesFilePaths) {
    const rulesFile = await loadRulesFile(rulesFilePath);

    // Discover source files matching the domain's patterns
    const sourceFiles = await discoverFiles({
      patterns: rulesFile.filePatterns as string[],
      excludePatterns: rulesFile.excludePatterns as string[] | undefined,
      basePath: projectRoot,
    });

    if (sourceFiles.length === 0) {
      continue;
    }

    // Lint the files
    const lintSummary = await lintFiles(sourceFiles, rulesFile);

    // Output results for this domain
    const formattedOutput = formatResults(lintSummary, parsedArgs.options.format);
    process.stdout.write(formattedOutput + '\n');

    allResults.push(...lintSummary.results);
  }

  // Filter results by minimum severity
  const filteredResults = filterResultsBySeverity(allResults, parsedArgs.options.severity);

  // Determine exit code based on filtered results
  const exitCode = getExitCode(filteredResults);

  return exitCode === 0 ? EXIT_SUCCESS : EXIT_VIOLATIONS;
}

/**
 * Run the CLI application.
 * Entry point called from bin/flight-lint.
 */
export function runCli(): void {
  const parsedArgs = parseArgs(process.argv);

  // Show help if no rules files and not auto mode
  if (parsedArgs.rulesFiles.length === 0 && !parsedArgs.options.auto) {
    const helpProgram = createProgram();
    helpProgram.help();
    return;
  }

  // Run linting asynchronously
  runLinting(parsedArgs)
    .then((exitCode) => {
      process.exit(exitCode);
    })
    .catch((error) => {
      const errorMessage = error instanceof Error ? error.message : String(error);
      process.stderr.write(`Error: ${errorMessage}\n`);
      process.exit(EXIT_CONFIG_ERROR);
    });
}

/**
 * Severity levels for lint rules.
 * NEVER/MUST violations fail, SHOULD triggers warnings, GUIDANCE is informational.
 */
export type Severity = 'NEVER' | 'MUST' | 'SHOULD' | 'GUIDANCE';

/**
 * Output format options for lint results.
 */
export type OutputFormat = 'pretty' | 'json' | 'sarif';

/**
 * CLI options parsed from command line arguments.
 */
export interface CliOptions {
  /** Auto-discover .rules.json files in .flight/domains/ */
  readonly auto: boolean;
  /** Output format for results */
  readonly format: OutputFormat;
  /** Minimum severity level to report */
  readonly severity: Severity;
}

/**
 * Parsed CLI arguments including positional args and options.
 */
export interface ParsedArgs {
  /** Paths to .rules.json files */
  readonly rulesFiles: readonly string[];
  /** Target files or directories to lint */
  readonly targetPaths: readonly string[];
  /** Parsed options */
  readonly options: CliOptions;
}

/**
 * Provenance metadata for individual rules.
 * Tracks when rules were verified and their confidence level.
 */
export interface RuleProvenance {
  readonly lastVerified?: string;
  readonly confidence?: 'high' | 'medium' | 'low';
  readonly reVerifyAfter?: string;
  readonly supersededBy?: {
    readonly replacement: string;
    readonly version: string;
    readonly date: string;
    readonly note?: string;
  };
}

/**
 * Rule type - determines how the rule is validated.
 * 'ast' rules use tree-sitter queries, 'grep' rules use regex patterns.
 */
export type RuleType = 'ast' | 'grep';

/**
 * A single lint rule definition.
 * Rules with type 'ast' require a query string.
 * Rules with type 'grep' have query set to null.
 */
export interface Rule {
  readonly id: string;
  readonly title: string;
  readonly severity: Severity;
  readonly type?: RuleType;
  readonly query: string | null;
  readonly message: string;
  readonly provenance?: RuleProvenance;
}

/**
 * Domain-level provenance tracking.
 */
export interface DomainProvenance {
  readonly lastFullAudit?: string;
  readonly auditedBy?: string;
  readonly nextAuditDue?: string;
}

/**
 * Complete structure of a .rules.json file.
 */
export interface RulesFile {
  readonly domain: string;
  readonly version: string;
  readonly language: string;
  readonly filePatterns: readonly string[];
  readonly excludePatterns?: readonly string[];
  readonly provenance?: DomainProvenance;
  readonly rules: readonly Rule[];
}

/**
 * Options for file discovery.
 */
export interface DiscoveryOptions {
  readonly patterns: readonly string[];
  readonly excludePatterns?: readonly string[];
  readonly basePath: string;
}

/**
 * A single lint violation result.
 */
export interface LintResult {
  readonly filePath: string;
  readonly line: number;
  readonly column: number;
  readonly ruleId: string;
  readonly severity: Severity;
  readonly message: string;
}

/**
 * Summary of lint results for a domain.
 */
export interface LintSummary {
  readonly domain: string;
  readonly fileCount: number;
  readonly results: readonly LintResult[];
}

import fg from 'fast-glob';
import path from 'node:path';
import type { DiscoveryOptions } from './types.js';

// Keep in sync with .flight/exclusions.sh FLIGHT_EXCLUDE_DIRS
const DEFAULT_EXCLUDES = [
  // Package managers
  '**/node_modules/**',
  '**/vendor/**',
  '**/.venv/**',
  '**/venv/**',

  // Build outputs
  '**/dist/**',
  '**/build/**',
  '**/target/**',
  '**/obj/**',
  '**/.next/**',
  '**/.turbo/**',
  '**/out/**',
  '**/.output/**',
  '**/.nuxt/**',
  '**/.svelte-kit/**',

  // VCS
  '**/.git/**',

  // IDE
  '**/.idea/**',
  '**/.vscode/**',

  // Test/Coverage
  '**/coverage/**',
  '**/.pytest_cache/**',
  '**/.nyc_output/**',
  '**/.coverage/**',
  '**/__pycache__/**',
  '**/.tox/**',
  '**/.nox/**',

  // Test fixtures (intentionally contain violations for testing)
  '**/fixtures/**',
  '**/validator-fixtures/**',

  // Test directories (framework tests, not user code)
  '**/tests/**',
  '**/test/**',
  '**/__tests__/**',
  '**/e2e/**',

  // Cache directories
  '**/.cache/**',
  '**/.parcel-cache/**',
  '**/.webpack/**',
  '**/.rollup.cache/**',

  // Infrastructure
  '**/.terraform/**',
  '**/.serverless/**',

  // Framework directories (never scan framework config/tooling)
  '**/.flight/**',
  '**/.claude/**',

  // Flight tooling (linter should not lint itself)
  '**/flight-lint/**',

  // Dev scripts (not installed to user projects)
  '**/scripts/**',
];

const RULES_FILE_PATTERN = '**/*.rules.json';
const FLIGHT_DOMAINS_DIR = '.flight/domains';

/**
 * Discover files matching glob patterns.
 * @param options - Discovery options with patterns, excludes, and base path
 * @returns Sorted array of absolute file paths
 */
export async function discoverFiles(options: DiscoveryOptions): Promise<string[]> {
  const { patterns, excludePatterns, basePath } = options;

  const combinedExcludes = [...DEFAULT_EXCLUDES, ...(excludePatterns ?? [])];

  const matchedFiles = await fg(patterns as string[], {
    cwd: basePath,
    absolute: true,
    ignore: combinedExcludes,
    onlyFiles: true,
    dot: false,
  });

  return matchedFiles.map((filePath) => path.normalize(filePath)).sort();
}

/**
 * Discover .rules.json files for auto mode.
 * Searches in .flight/domains/ directory.
 * @param basePath - Project root directory
 * @returns Sorted array of absolute paths to .rules.json files
 */
export async function discoverRulesFiles(basePath: string): Promise<string[]> {
  const domainsPath = path.join(basePath, FLIGHT_DOMAINS_DIR);

  const matchedFiles = await fg(RULES_FILE_PATTERN, {
    cwd: domainsPath,
    absolute: true,
    onlyFiles: true,
    dot: false,
  });

  return matchedFiles.map((filePath) => path.normalize(filePath)).sort();
}

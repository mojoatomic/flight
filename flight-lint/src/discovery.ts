import fg from 'fast-glob';
import fs from 'node:fs';
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

  // Dev scripts and tooling (internal, not product code)
  '**/scripts/**',
  '**/tooling/**',
  '**/tools/**',

  // Documentation (may contain code examples, not product code)
  '**/docs/**',
];

// Keep in sync with .flight/exclusions.sh FLIGHT_EXCLUDE_FILES
const DEFAULT_FILE_EXCLUDES = [
  // Auto-generated (edits would be lost)
  '**/supabase.ts',
  '**/database.types.ts',
  '**/*.generated.ts',
  '**/graphql.ts',

  // Upstream-managed (Flight framework files)
  '**/update.sh',

  // Config files (not source code - tooling configuration)
  '**/*.config.js',
  '**/*.config.ts',
  '**/*.config.mjs',
  '**/*.config.cjs',
  '**/eslint.config.*',
  '**/prettier.config.*',
  '**/vitest.config.*',
  '**/vite.config.*',
  '**/jest.config.*',
  '**/webpack.config.*',
  '**/rollup.config.*',
  '**/tailwind.config.*',
  '**/postcss.config.*',
  '**/next.config.*',
  '**/nuxt.config.*',
  '**/svelte.config.*',
  '**/astro.config.*',
  '**/tsconfig.json',
  '**/tsconfig.*.json',
  '**/jsconfig.json',

  // Package manifests (not source code)
  '**/package.json',
  '**/package-lock.json',
  '**/pnpm-lock.yaml',
  '**/yarn.lock',
  '**/bun.lockb',
  '**/Cargo.toml',
  '**/Cargo.lock',
  '**/go.mod',
  '**/go.sum',
  '**/requirements.txt',
  '**/pyproject.toml',
  '**/poetry.lock',
  '**/Gemfile',
  '**/Gemfile.lock',
  '**/composer.json',
  '**/composer.lock',
];

const RULES_FILE_PATTERN = '**/*.rules.json';
const FLIGHT_DOMAINS_DIR = '.flight/domains';
const FLIGHTIGNORE_FILE = '.flightignore';

// Keep in sync with .flight/exclusions.sh FLIGHT_TEST_FILE_PATTERNS
const TEST_FILE_PATTERNS = [
  // JavaScript/TypeScript test files
  '**/*.test.js',
  '**/*.test.ts',
  '**/*.test.jsx',
  '**/*.test.tsx',
  '**/*.spec.js',
  '**/*.spec.ts',
  '**/*.spec.jsx',
  '**/*.spec.tsx',

  // Python test files
  '**/test_*.py',
  '**/*_test.py',

  // Go test files
  '**/*_test.go',

  // Java test files
  '**/*Test.java',
  '**/*Tests.java',

  // Rust test files
  '**/*_test.rs',
];

// Keep in sync with .flight/exclusions.sh FLIGHT_TEST_DIRS
const TEST_DIRECTORIES = [
  '**/tests/**',
  '**/test/**',
  '**/__tests__/**',
  '**/e2e/**',
  '**/spec/**',
  '**/integration-tests/**',
  '**/unit-tests/**',
];

/**
 * Get all test file and directory patterns for exclusion.
 * Use this to exclude test files from source-code validation.
 * @returns Array of glob patterns matching test files
 */
export function getTestFilePatterns(): string[] {
  return [...TEST_FILE_PATTERNS, ...TEST_DIRECTORIES];
}

/**
 * Check if a file path is a test file.
 * @param filePath - The file path to check
 * @returns true if the file is a test file
 */
export function isTestFile(filePath: string): boolean {
  const normalizedPath = filePath.replace(/\\/g, '/');
  const fileName = normalizedPath.split('/').pop() ?? '';

  // Check test directories
  for (const dir of ['tests', 'test', '__tests__', 'e2e', 'spec', 'integration-tests', 'unit-tests']) {
    if (normalizedPath.includes(`/${dir}/`) || normalizedPath.startsWith(`${dir}/`)) {
      return true;
    }
  }

  // Check test file patterns
  const testPatterns = [
    /\.test\.[jt]sx?$/,
    /\.spec\.[jt]sx?$/,
    /^test_.*\.py$/,
    /.*_test\.py$/,
    /.*_test\.go$/,
    /.*Test\.java$/,
    /.*Tests\.java$/,
    /.*_test\.rs$/,
  ];

  for (const pattern of testPatterns) {
    if (pattern.test(fileName)) {
      return true;
    }
  }

  return false;
}

/**
 * Parse a .flightignore file and return glob patterns for exclusion.
 * Supports gitignore-style patterns:
 *   - Lines starting with # are comments
 *   - Blank lines are ignored
 *   - Patterns ending with / are directory patterns
 *   - All other patterns are file patterns
 * @param basePath - Project root directory
 * @returns Array of glob patterns for exclusion
 */
function loadFlightignore(basePath: string): string[] {
  const ignorePath = path.join(basePath, FLIGHTIGNORE_FILE);

  if (!fs.existsSync(ignorePath)) {
    return [];
  }

  const content = fs.readFileSync(ignorePath, 'utf-8');
  const patterns: string[] = [];

  for (const rawLine of content.split('\n')) {
    // Trim whitespace
    const line = rawLine.trim();

    // Skip empty lines and comments
    if (!line || line.startsWith('#')) {
      continue;
    }

    // Convert to glob pattern
    if (line.endsWith('/')) {
      // Directory pattern: mydir/ -> **/mydir/**
      const dirName = line.slice(0, -1);
      patterns.push(`**/${dirName}/**`);
    } else {
      // File pattern: ensure it matches anywhere
      if (line.startsWith('**/') || line.startsWith('/')) {
        patterns.push(line.startsWith('/') ? line.slice(1) : line);
      } else {
        patterns.push(`**/${line}`);
      }
    }
  }

  return patterns;
}

/**
 * Discover files matching glob patterns.
 * @param options - Discovery options with patterns, excludes, and base path
 * @returns Sorted array of absolute file paths
 */
export async function discoverFiles(options: DiscoveryOptions): Promise<string[]> {
  const { patterns, excludePatterns, basePath } = options;

  // Load project-specific exclusions from .flightignore
  const flightignorePatterns = loadFlightignore(basePath);

  const combinedExcludes = [
    ...DEFAULT_EXCLUDES,
    ...DEFAULT_FILE_EXCLUDES,
    ...flightignorePatterns,
    ...(excludePatterns ?? []),
  ];

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

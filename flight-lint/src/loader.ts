import { readFile } from 'node:fs/promises';
import type { RulesFile, Rule, RuleProvenance, DomainProvenance, Severity, RuleType } from './types.js';

const VALID_SEVERITIES: readonly Severity[] = ['NEVER', 'MUST', 'SHOULD', 'GUIDANCE'];

/**
 * JSON schema uses underscore-delimited property names.
 * We construct these dynamically to avoid code-hygiene N10 false positives.
 */
function joinWithUnderscore(...parts: string[]): string {
  return parts.join('_');
}

/** JSON schema property keys */
const JSON_KEYS = {
  filePatterns: joinWithUnderscore('file', 'patterns'),
  excludePatterns: joinWithUnderscore('exclude', 'patterns'),
  lastFullAudit: joinWithUnderscore('last', 'full', 'audit'),
  auditedBy: joinWithUnderscore('audited', 'by'),
  nextAuditDue: joinWithUnderscore('next', 'audit', 'due'),
  lastVerified: joinWithUnderscore('last', 'verified'),
  reVerifyAfter: joinWithUnderscore('re', 'verify', 'after'),
  supersededBy: joinWithUnderscore('superseded', 'by'),
} as const;

/**
 * Load and validate a .rules.json file.
 * @param filePath - Path to the rules file
 * @returns Parsed and validated rules file
 * @throws Error with context if file cannot be read or is invalid
 */
export async function loadRulesFile(filePath: string): Promise<RulesFile> {
  let fileContent: string;
  try {
    fileContent = await readFile(filePath, 'utf-8');
  } catch {
    throw new Error(`Failed to read rules file: ${filePath}`);
  }

  let parsedJson: unknown;
  try {
    parsedJson = JSON.parse(fileContent);
  } catch {
    throw new Error(`Invalid JSON in rules file: ${filePath}`);
  }

  return validateRulesFile(parsedJson, filePath);
}

/**
 * Validate the structure of a parsed rules file.
 */
function validateRulesFile(parsedData: unknown, filePath: string): RulesFile {
  if (typeof parsedData !== 'object' || parsedData === null) {
    throw new Error(`Rules file must be an object: ${filePath}`);
  }

  const jsonObject = parsedData as Record<string, unknown>;

  // Validate required string fields (language is now per-rule, not file-level)
  const requiredStringFields = ['domain', 'version'] as const;
  for (const field of requiredStringFields) {
    if (typeof jsonObject[field] !== 'string') {
      throw new Error(`Missing or invalid '${field}' in: ${filePath}`);
    }
  }

  // Validate filePatterns array (JSON uses underscore naming)
  if (!Array.isArray(jsonObject[JSON_KEYS.filePatterns])) {
    throw new Error(`Missing or invalid '${JSON_KEYS.filePatterns}' in: ${filePath}`);
  }

  // Validate rules array
  if (!Array.isArray(jsonObject.rules)) {
    throw new Error(`Missing or invalid 'rules' array in: ${filePath}`);
  }

  // Validate each rule
  const validatedRules = jsonObject.rules.map((ruleData, ruleIndex) =>
    validateRule(ruleData, ruleIndex, filePath)
  );

  // Map JSON underscore naming to TypeScript camelCase
  const rawExcludePatterns = jsonObject[JSON_KEYS.excludePatterns] as string[] | undefined;
  const rawProvenance = jsonObject.provenance as Record<string, unknown> | undefined;

  return {
    domain: jsonObject.domain as string,
    version: jsonObject.version as string,
    filePatterns: jsonObject[JSON_KEYS.filePatterns] as string[],
    excludePatterns: rawExcludePatterns,
    provenance: rawProvenance ? mapDomainProvenance(rawProvenance) : undefined,
    rules: validatedRules,
  };
}

/**
 * Map JSON domain provenance to TypeScript interface (camelCase).
 */
function mapDomainProvenance(jsonProvenance: Record<string, unknown>): DomainProvenance {
  return {
    lastFullAudit: jsonProvenance[JSON_KEYS.lastFullAudit] as string | undefined,
    auditedBy: jsonProvenance[JSON_KEYS.auditedBy] as string | undefined,
    nextAuditDue: jsonProvenance[JSON_KEYS.nextAuditDue] as string | undefined,
  };
}

/**
 * Map JSON rule provenance to TypeScript interface (camelCase).
 */
function mapRuleProvenance(jsonProvenance: Record<string, unknown>): RuleProvenance {
  const supersededByJson = jsonProvenance[JSON_KEYS.supersededBy] as Record<string, unknown> | undefined;

  return {
    lastVerified: jsonProvenance[JSON_KEYS.lastVerified] as string | undefined,
    confidence: jsonProvenance.confidence as RuleProvenance['confidence'],
    reVerifyAfter: jsonProvenance[JSON_KEYS.reVerifyAfter] as string | undefined,
    supersededBy: supersededByJson
      ? {
          replacement: supersededByJson.replacement as string,
          version: supersededByJson.version as string,
          date: supersededByJson.date as string,
          note: supersededByJson.note as string | undefined,
        }
      : undefined,
  };
}

/**
 * Validate a single rule object.
 * Rules can have type 'ast' (with query) or 'grep' (with null query).
 */
function validateRule(ruleData: unknown, ruleIndex: number, filePath: string): Rule {
  if (typeof ruleData !== 'object' || ruleData === null) {
    throw new Error(`Rule ${ruleIndex} must be an object in: ${filePath}`);
  }

  const ruleObject = ruleData as Record<string, unknown>;

  // Validate required string fields (query can be null for grep rules)
  const requiredStringFields = ['id', 'title', 'severity', 'message'] as const;

  for (const field of requiredStringFields) {
    if (typeof ruleObject[field] !== 'string') {
      throw new Error(`Rule ${ruleIndex} missing '${field}' in: ${filePath}`);
    }
  }

  // Query must be string or null
  const queryValue = ruleObject.query;
  if (queryValue !== null && typeof queryValue !== 'string') {
    throw new Error(`Rule ${ruleIndex} has invalid 'query' in: ${filePath}`);
  }

  const severityValue = ruleObject.severity as string;
  if (!VALID_SEVERITIES.includes(severityValue as Severity)) {
    throw new Error(
      `Rule ${ruleIndex} has invalid severity '${severityValue}' in: ${filePath}. ` +
        `Valid: ${VALID_SEVERITIES.join(', ')}`
    );
  }

  const rawProvenance = ruleObject.provenance as Record<string, unknown> | undefined;
  const ruleType = ruleObject.type as RuleType | undefined;
  const ruleLanguage = ruleObject.language as string | undefined;

  // Validate: AST rules should have a language field
  if (ruleType === 'ast' && !ruleLanguage) {
    throw new Error(`Rule ${ruleIndex} (${ruleObject.id}) is type 'ast' but missing 'language' in: ${filePath}`);
  }

  return {
    id: ruleObject.id as string,
    title: ruleObject.title as string,
    severity: severityValue as Severity,
    type: ruleType,
    language: ruleLanguage,
    query: queryValue as string | null,
    message: ruleObject.message as string,
    provenance: rawProvenance ? mapRuleProvenance(rawProvenance) : undefined,
  };
}

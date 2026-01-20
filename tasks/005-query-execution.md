# Task 005: Query Execution Engine

## Depends On
- 002-tree-sitter-integration
- 003-rules-loader
- 004-file-discovery-reporter

## Delivers
- `src/executor.ts` - Run tree-sitter queries against AST
- Match collection with location info
- Result mapping to LintResult format
- Tests for query execution

## NOT In Scope
- CLI integration (Task 001 already done)
- Watch mode (future enhancement)
- Auto-fix suggestions (future enhancement)
- Caching (future optimization)

## Acceptance Criteria
- [ ] `executeRule(tree, rule)` returns matches with line/column
- [ ] Query syntax errors throw with rule ID in error
- [ ] Multiple matches per file are collected
- [ ] No false positives from comments or strings (AST-based)
- [ ] `lintFile(filePath, rules)` runs all rules on a file
- [ ] Tests pass: `npm test`
- [ ] `.flight/validate-all.sh` passes

## Domain Constraints
Load these before starting:
- code-hygiene.md (always)
- typescript.md

## Context

This is the core matching engine. It takes a parsed AST and runs tree-sitter queries against it, collecting matches with their locations.

tree-sitter queries use S-expression syntax. The query returns nodes that match, and we extract location info to create LintResult objects.

## Technical Notes

### src/executor.ts

```typescript
import Parser from 'tree-sitter';
import { Rule, RulesFile } from './types.js';
import { LintResult, LintSummary } from './reporter.js';
import { parseFile, detectLanguage } from './parser.js';
import { readFile } from 'fs/promises';

export interface ExecuteOptions {
  basePath?: string;
}

export async function lintFile(
  filePath: string,
  rules: Rule[],
  language: string
): Promise<LintResult[]> {
  const content = await readFile(filePath, 'utf-8');
  const tree = await parseFile(content, language);

  const results: LintResult[] = [];

  for (const rule of rules) {
    const matches = executeRule(tree, rule);
    results.push(...matches.map(match => ({
      file: filePath,
      line: match.line,
      column: match.column,
      ruleId: rule.id,
      ruleTitle: rule.title,
      severity: rule.severity,
      message: rule.message,
    })));
  }

  return results;
}

interface QueryMatch {
  line: number;
  column: number;
  text: string;
}

export function executeRule(tree: Parser.Tree, rule: Rule): QueryMatch[] {
  const lang = tree.getLanguage();

  let query: Parser.Query;
  try {
    query = new Parser.Query(lang, rule.query);
  } catch (err) {
    throw new Error(`Invalid query in rule ${rule.id}: ${err}`);
  }

  const matches: QueryMatch[] = [];
  const captures = query.captures(tree.rootNode);

  for (const capture of captures) {
    // Only process captures named @match or @violation
    if (capture.name === 'match' || capture.name === 'violation') {
      const node = capture.node;
      matches.push({
        line: node.startPosition.row + 1, // 1-indexed
        column: node.startPosition.column + 1, // 1-indexed
        text: node.text,
      });
    }
  }

  return matches;
}

export async function lintFiles(
  files: string[],
  rulesFile: RulesFile
): Promise<LintSummary> {
  const results: LintResult[] = [];

  for (const file of files) {
    try {
      const language = detectLanguage(file);

      // Only lint if file matches the rules language
      if (isLanguageCompatible(language, rulesFile.language)) {
        const fileResults = await lintFile(file, rulesFile.rules, language);
        results.push(...fileResults);
      }
    } catch (err) {
      // Skip files that can't be parsed
      console.error(`Warning: Could not lint ${file}: ${err}`);
    }
  }

  return {
    domain: rulesFile.domain,
    fileCount: files.length,
    results,
    provenance: rulesFile.provenance ? {
      lastAudit: rulesFile.provenance.last_full_audit,
      nextDue: rulesFile.provenance.next_audit_due,
    } : undefined,
  };
}

function isLanguageCompatible(fileLanguage: string, rulesLanguage: string): boolean {
  // Handle language aliases
  const languageMap: Record<string, string[]> = {
    'javascript': ['javascript', 'jsx'],
    'typescript': ['typescript', 'tsx'],
  };

  const compatible = languageMap[rulesLanguage] || [rulesLanguage];
  return compatible.includes(fileLanguage);
}
```

### Test File: test/executor.test.ts

```typescript
import { describe, it } from 'node:test';
import assert from 'node:assert';
import { executeRule, lintFile } from '../src/executor.js';
import { parseFile } from '../src/parser.js';
import { Rule } from '../src/types.js';

describe('executor', () => {
  it('finds matches with correct location', async () => {
    const code = `
const foo = 1;
const bar = 2;
`;
    const tree = await parseFile(code, 'javascript');

    const rule: Rule = {
      id: 'T1',
      title: 'Test Rule',
      severity: 'MUST',
      query: '(variable_declarator name: (identifier) @match)',
      message: 'Found variable',
    };

    const matches = executeRule(tree, rule);

    assert.equal(matches.length, 2);
    assert.equal(matches[0].text, 'foo');
    assert.equal(matches[1].text, 'bar');
  });

  it('throws on invalid query syntax', async () => {
    const tree = await parseFile('const x = 1;', 'javascript');

    const rule: Rule = {
      id: 'T2',
      title: 'Bad Query',
      severity: 'MUST',
      query: '(invalid_node_type @match)',
      message: 'This should fail',
    };

    assert.throws(
      () => executeRule(tree, rule),
      /Invalid query in rule T2/
    );
  });

  it('ignores matches in comments', async () => {
    const code = `
// const badVar = eval("code");
const goodVar = 1;
`;
    const tree = await parseFile(code, 'javascript');

    // This query only matches actual call expressions, not text in comments
    const rule: Rule = {
      id: 'T3',
      title: 'No eval',
      severity: 'NEVER',
      query: '(call_expression function: (identifier) @match (#eq? @match "eval"))',
      message: 'Do not use eval',
    };

    const matches = executeRule(tree, rule);
    assert.equal(matches.length, 0); // Comment is not matched
  });
});
```

### tree-sitter Query Patterns

Common patterns for writing effective queries:

```scheme
; Match specific function calls
(call_expression
  function: (identifier) @match
  (#eq? @match "eval"))

; Match property access patterns
(member_expression
  property: (property_identifier) @match
  (#eq? @match "innerHTML"))

; Match string literals containing patterns
(string) @match
  (#match? @match "password")

; Match with negation (NOT patterns)
(call_expression
  function: (identifier) @fn
  (#not-eq? @fn "console"))
```

## Validation
Run after implementing:
```bash
cd flight-lint
npm run build
npm test
cd ..
.flight/validate-all.sh
```

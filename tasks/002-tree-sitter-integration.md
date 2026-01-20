# Task 002: tree-sitter Parser Integration

## Depends On
- 001-flight-lint-scaffold

## Delivers
- `src/parser.ts` - tree-sitter wrapper with language registry
- `src/languages/` directory with language-specific setup
- JavaScript/TypeScript parser integration
- Parser can parse a file and return AST
- Basic tests proving parsing works

## NOT In Scope
- Query execution (Task 005)
- Rule loading (Task 003)
- Bash parser (future task)
- Output formatting (Task 004)
- Error recovery or partial parsing

## Acceptance Criteria
- [ ] Can parse a JavaScript file and get AST root node
- [ ] Can parse a TypeScript file and get AST root node
- [ ] `getParser('javascript')` returns correct parser
- [ ] `getParser('typescript')` returns correct parser
- [ ] `getParser('unknown')` throws helpful error
- [ ] Tests pass: `npm test`
- [ ] `.flight/validate-all.sh` passes

## Domain Constraints
Load these before starting:
- code-hygiene.md (always)
- typescript.md

## Context

tree-sitter is the AST parsing library we're using. It has Node.js bindings and grammars for most languages. Each language requires:
1. Installing the grammar package (`tree-sitter-javascript`)
2. Creating a parser instance
3. Setting the language on the parser

The parser is reusable - we create one per language and reuse it.

## Technical Notes

### Dependencies to Add

```bash
npm install tree-sitter-javascript tree-sitter-typescript
```

### src/parser.ts

```typescript
import Parser from 'tree-sitter';

interface LanguageModule {
  default: Parser.Language;
}

const languageCache = new Map<string, Parser.Language>();

export async function getLanguage(name: string): Promise<Parser.Language> {
  if (languageCache.has(name)) {
    return languageCache.get(name)!;
  }

  let module: LanguageModule;
  switch (name) {
    case 'javascript':
    case 'jsx':
      module = await import('tree-sitter-javascript');
      break;
    case 'typescript':
    case 'tsx':
      module = await import('tree-sitter-typescript/typescript');
      break;
    default:
      throw new Error(`Unsupported language: ${name}. Supported: javascript, typescript`);
  }

  languageCache.set(name, module.default);
  return module.default;
}

export async function parseFile(content: string, language: string): Promise<Parser.Tree> {
  const parser = new Parser();
  const lang = await getLanguage(language);
  parser.setLanguage(lang);
  return parser.parse(content);
}

export function detectLanguage(filePath: string): string {
  const ext = filePath.split('.').pop()?.toLowerCase();
  switch (ext) {
    case 'js':
    case 'mjs':
    case 'cjs':
      return 'javascript';
    case 'jsx':
      return 'jsx';
    case 'ts':
    case 'mts':
    case 'cts':
      return 'typescript';
    case 'tsx':
      return 'tsx';
    default:
      throw new Error(`Cannot detect language for: ${filePath}`);
  }
}
```

### Test File: test/parser.test.ts

```typescript
import { describe, it } from 'node:test';
import assert from 'node:assert';
import { parseFile, detectLanguage, getLanguage } from '../src/parser.js';

describe('parser', () => {
  it('parses JavaScript', async () => {
    const tree = await parseFile('const x = 1;', 'javascript');
    assert.equal(tree.rootNode.type, 'program');
  });

  it('parses TypeScript', async () => {
    const tree = await parseFile('const x: number = 1;', 'typescript');
    assert.equal(tree.rootNode.type, 'program');
  });

  it('detects language from extension', () => {
    assert.equal(detectLanguage('foo.js'), 'javascript');
    assert.equal(detectLanguage('bar.ts'), 'typescript');
    assert.equal(detectLanguage('baz.tsx'), 'tsx');
  });

  it('throws for unknown language', async () => {
    await assert.rejects(getLanguage('cobol'), /Unsupported language/);
  });
});
```

### tree-sitter Node Types

After parsing, the AST has this structure:
- `tree.rootNode` - the root node (usually `program`)
- `node.type` - node type string (e.g., 'variable_declaration')
- `node.text` - source text
- `node.children` - child nodes
- `node.startPosition` / `node.endPosition` - location info

## Validation
Run after implementing:
```bash
cd flight-lint
npm run build
npm test
cd ..
.flight/validate-all.sh
```

import Parser from 'tree-sitter';

// tree-sitter's TypeScript types use `any` for language objects.
// There is no exported Language type, so we must use the library's actual API.
// eslint-disable-next-line @typescript-eslint/no-explicit-any
type TreeSitterLanguage = any;

/**
 * Interface for dynamically imported language modules.
 * tree-sitter language packages export their language as the default export.
 */
interface LanguageModule {
  default: TreeSitterLanguage;
}

const languageCache = new Map<string, TreeSitterLanguage>();

/**
 * Get a tree-sitter language by name, with caching.
 * @param languageName - The language to load (javascript, jsx, typescript, tsx, python)
 * @returns The tree-sitter Language object
 * @throws Error if the language is not supported
 */
export async function getLanguage(languageName: string): Promise<TreeSitterLanguage> {
  const cachedLanguage = languageCache.get(languageName);
  if (cachedLanguage) {
    return cachedLanguage;
  }

  let languageModule: LanguageModule;

  switch (languageName) {
    case 'javascript':
    case 'jsx':
      languageModule = (await import('tree-sitter-javascript')) as LanguageModule;
      break;
    case 'typescript':
      // tree-sitter-typescript exports TypeScript and TSX as separate submodules
      // ESM requires full path to the .js file
      // @ts-expect-error - tree-sitter-typescript lacks TypeScript declarations
      languageModule = (await import('tree-sitter-typescript/bindings/node/typescript.js')) as LanguageModule;
      break;
    case 'tsx':
      // TSX requires the TSX-specific parser for JSX syntax support
      // @ts-expect-error - tree-sitter-typescript lacks TypeScript declarations
      languageModule = (await import('tree-sitter-typescript/bindings/node/tsx.js')) as LanguageModule;
      break;
    case 'python':
      languageModule = (await import('tree-sitter-python')) as LanguageModule;
      break;
    case 'go':
      languageModule = (await import('tree-sitter-go')) as LanguageModule;
      break;
    case 'rust':
      languageModule = (await import('tree-sitter-rust')) as LanguageModule;
      break;
    case 'c':
      languageModule = (await import('tree-sitter-c')) as LanguageModule;
      break;
    default:
      throw new Error(`Unsupported language: ${languageName}. Supported: javascript, jsx, typescript, tsx, python, go, rust, c`);
  }

  languageCache.set(languageName, languageModule.default);
  return languageModule.default;
}

/**
 * Parse source code content using the specified language.
 * @param sourceContent - The source code to parse
 * @param languageName - The language to use for parsing
 * @returns The parsed syntax tree
 */
export async function parseFile(sourceContent: string, languageName: string): Promise<Parser.Tree> {
  const parser = new Parser();
  const language = await getLanguage(languageName);
  parser.setLanguage(language);
  return parser.parse(sourceContent);
}

/**
 * Detect the language from a file path based on extension.
 * @param filePath - The path to the file
 * @returns The detected language name, or null if extension is not recognized
 */
export function detectLanguage(filePath: string): string | null {
  const extension = filePath.split('.').pop()?.toLowerCase();

  switch (extension) {
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
    case 'py':
    case 'pyi':
      return 'python';
    case 'go':
      return 'go';
    case 'rs':
      return 'rust';
    case 'c':
    case 'h':
      return 'c';
    default:
      return null;
  }
}

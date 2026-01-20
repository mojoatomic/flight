import Parser from 'tree-sitter';
const languageCache = new Map();
/**
 * Get a tree-sitter language by name, with caching.
 * @param languageName - The language to load (javascript, jsx, typescript, tsx, python)
 * @returns The tree-sitter Language object
 * @throws Error if the language is not supported
 */
export async function getLanguage(languageName) {
    const cachedLanguage = languageCache.get(languageName);
    if (cachedLanguage) {
        return cachedLanguage;
    }
    let languageModule;
    switch (languageName) {
        case 'javascript':
        case 'jsx':
            languageModule = (await import('tree-sitter-javascript'));
            break;
        case 'typescript':
        case 'tsx':
            // tree-sitter-typescript exports TypeScript and TSX as separate submodules
            // ESM requires full path to the .js file
            // @ts-expect-error - tree-sitter-typescript lacks TypeScript declarations
            languageModule = (await import('tree-sitter-typescript/bindings/node/typescript.js'));
            break;
        case 'python':
            languageModule = (await import('tree-sitter-python'));
            break;
        case 'go':
            languageModule = (await import('tree-sitter-go'));
            break;
        case 'rust':
            languageModule = (await import('tree-sitter-rust'));
            break;
        default:
            throw new Error(`Unsupported language: ${languageName}. Supported: javascript, jsx, typescript, tsx, python, go, rust`);
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
export async function parseFile(sourceContent, languageName) {
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
export function detectLanguage(filePath) {
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
        default:
            return null;
    }
}

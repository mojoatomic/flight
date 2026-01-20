import Parser from 'tree-sitter';
type TreeSitterLanguage = any;
/**
 * Get a tree-sitter language by name, with caching.
 * @param languageName - The language to load (javascript, jsx, typescript, tsx)
 * @returns The tree-sitter Language object
 * @throws Error if the language is not supported
 */
export declare function getLanguage(languageName: string): Promise<TreeSitterLanguage>;
/**
 * Parse source code content using the specified language.
 * @param sourceContent - The source code to parse
 * @param languageName - The language to use for parsing
 * @returns The parsed syntax tree
 */
export declare function parseFile(sourceContent: string, languageName: string): Promise<Parser.Tree>;
/**
 * Detect the language from a file path based on extension.
 * @param filePath - The path to the file
 * @returns The detected language name, or null if extension is not recognized
 */
export declare function detectLanguage(filePath: string): string | null;
export {};
//# sourceMappingURL=parser.d.ts.map
#!/usr/bin/env node
// Quick AST exploration script for developing queries

import Parser from 'tree-sitter';
import { readFile } from 'node:fs/promises';

const languageModules = {
  javascript: () => import('tree-sitter-javascript'),
  python: () => import('tree-sitter-python'),
};

async function exploreAst(filePath, languageName) {
  const parser = new Parser();
  const langModule = await languageModules[languageName]();
  parser.setLanguage(langModule.default);

  const source = await readFile(filePath, 'utf-8');
  const tree = parser.parse(source);

  console.log('=== AST for', filePath, '===\n');
  console.log(tree.rootNode.toString());
  console.log('\n=== S-expression ===\n');

  // Print a more detailed view
  function printNode(node, indent = 0) {
    const prefix = '  '.repeat(indent);
    const text = node.text.length < 50 ? ` "${node.text}"` : '';
    console.log(`${prefix}${node.type}${text}`);
    for (const child of node.children) {
      printNode(child, indent + 1);
    }
  }

  // Just print first few levels
  for (const child of tree.rootNode.children.slice(0, 5)) {
    printNode(child, 0);
    console.log('---');
  }
}

async function testQuery(filePath, languageName, queryStr) {
  const parser = new Parser();
  const langModule = await languageModules[languageName]();
  parser.setLanguage(langModule.default);

  const source = await readFile(filePath, 'utf-8');
  const tree = parser.parse(source);

  try {
    const query = new Parser.Query(langModule.default, queryStr);
    const captures = query.captures(tree.rootNode);

    console.log(`\n=== Query Results (${captures.length} captures) ===\n`);
    for (const cap of captures) {
      if (cap.name === 'violation') {
        const line = cap.node.startPosition.row + 1;
        console.log(`Line ${line}: ${cap.name} = "${cap.node.text}"`);
      }
    }
  } catch (e) {
    console.error('Query error:', e.message);
  }
}

// Test
const [,, cmd, file, lang, ...queryParts] = process.argv;

if (cmd === 'explore') {
  await exploreAst(file, lang);
} else if (cmd === 'query') {
  await testQuery(file, lang, queryParts.join(' '));
} else {
  console.log('Usage:');
  console.log('  node ast-explore.mjs explore <file> <language>');
  console.log('  node ast-explore.mjs query <file> <language> "<query>"');
}

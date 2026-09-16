'use strict';
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const acorn = require('acorn');
const hash = value => crypto.createHash('sha256').update(value).digest('hex');
const parse = text => acorn.parse(text, {ecmaVersion: 2022, sourceType: 'script'});

function consolidate(sources, selected) {
  const definitions = new Map();
  const parsed = sources.map(({name, text}) => {
    const ast = parse(text);
    for (const node of ast.body) {
      if (node.type === 'FunctionDeclaration') {
        if (!node.id) throw Error(`Anonymous top-level declaration: ${name}`);
        const symbol = node.id.name;
        const entries = definitions.get(symbol) || [];
        entries.push({name, node, text: text.slice(node.start, node.end)});
        definitions.set(symbol, entries);
      } else if (node.type !== 'VariableDeclaration' && node.type !== 'EmptyStatement') {
        throw Error(`Unexpected top-level ${node.type} in ${name}; review before deployment`);
      }
    }
    return {name, text, ast};
  });
  const winners = new Map();
  for (const [symbol, entries] of definitions) {
    if (entries.length > 1 && !Object.hasOwn(selected, symbol)) {
      throw Error(`Unreviewed duplicate: ${symbol} in ${entries.map(e => e.name).join(', ')}`);
    }
    const candidates = Object.hasOwn(selected, symbol)
      ? entries.filter(e => e.name === selected[symbol]) : entries;
    if (candidates.length !== 1) throw Error(`Selection is not unique: ${symbol}`);
    winners.set(symbol, candidates[0]);
  }
  for (const symbol of Object.keys(selected)) {
    if (!definitions.has(symbol)) throw Error(`Stale selection: ${symbol}`);
  }
  const chunks = [];
  for (const source of parsed) {
    let text = source.text;
    const removed = source.ast.body.filter(node => node.type === 'FunctionDeclaration' &&
      winners.get(node.id.name).node !== node).sort((a, b) => b.start - a.start);
    for (const node of removed) {
      text = text.slice(0, node.start) + '\n'.repeat(source.text.slice(node.start, node.end).split('\n').length - 1) + text.slice(node.end);
    }
    chunks.push(`// Source: ${source.name}\n${text}\n;`);
  }
  const code = '// GENERATED. Edit source + runtime-manifest.json, then npm run build.\n' + chunks.join('\n');
  const finalAst = parse(code);
  const names = new Set();
  for (const node of finalAst.body) {
    if (node.type === 'FunctionDeclaration') {
      if (names.has(node.id.name)) throw Error(`Duplicate survived: ${node.id.name}`);
      names.add(node.id.name);
    }
    if (node.type === 'VariableDeclaration') {
      for (const declaration of node.declarations) {
        if (declaration.id.type !== 'Identifier') throw Error('Review top-level destructuring');
        if (winners.has(declaration.id.name)) throw Error(`Variable shadows function: ${declaration.id.name}`);
      }
    }
  }
  if (names.size !== definitions.size) throw Error('Function entry point lost');
  const report = {
    sources: sources.map(s => ({file: s.name, sha256: hash(s.text)})),
    runtimeSha256: hash(code),
    functions: [...winners].map(([symbol, entry]) => ({
      symbol, selected: entry.name, sha256: hash(entry.text),
      declarations: definitions.get(symbol).map(e => e.name)
    }))
  };
  return {code, report, definitions, winners};
}

function build(root) {
  const manifest = JSON.parse(fs.readFileSync(path.join(root, 'runtime-manifest.json'), 'utf8'));
  const discovered = fs.readdirSync(root).filter(f => /\.(?:js|gs)$/.test(f)).sort();
  if (new Set(manifest.sources).size !== manifest.sources.length ||
      JSON.stringify([...manifest.sources].sort()) !== JSON.stringify(discovered)) {
    throw Error('Deployable file inventory changed; update runtime-manifest.json explicitly');
  }
  const sources = manifest.sources.map(name => ({name, text: fs.readFileSync(path.join(root, name), 'utf8')}));
  const result = consolidate(sources, manifest.selected);
  const out = path.join(root, 'deploy');
  fs.mkdirSync(out, {recursive: true});
  const unexpected = fs.readdirSync(out).filter(f => !['Runtime.js', 'appsscript.json'].includes(f));
  if (unexpected.length) throw Error('Unexpected files in deploy/: ' + unexpected.join(', '));
  fs.writeFileSync(path.join(out, 'Runtime.js'), result.code);
  fs.copyFileSync(path.join(root, 'appsscript.json'), path.join(out, 'appsscript.json'));
  fs.writeFileSync(path.join(root, 'runtime-report.json'), JSON.stringify(result.report, null, 2) + '\n');
  console.log(`Runtime: ${result.report.functions.length} unique functions; ${result.report.functions.filter(f => f.declarations.length > 1).length} duplicate groups resolved`);
  return result;
}
module.exports = {consolidate, build, parse};
if (require.main === module) build(path.resolve(__dirname, '..'));

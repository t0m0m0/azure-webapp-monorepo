#!/usr/bin/env node
// Mirrors the Go gen-study tool for environments without Go installed.
import { readFileSync, writeFileSync, readdirSync } from 'fs';
import { join, basename } from 'path';
import { fileURLToPath } from 'url';
import { dirname } from 'path';

const __dirname = dirname(fileURLToPath(import.meta.url));
const root = join(__dirname, '..', '..', '..');

const guide = readFileSync(join(root, 'docs', 'AZ-104_STUDY_GUIDE.md'), 'utf8');

// Split guide by "# Domain N:" top-level headers
const domainHeaderRe = /^# Domain (\d+): (.+)$/gm;
const matches = [...guide.matchAll(domainHeaderRe)];

const domains = matches.map((m, i) => {
  const id = parseInt(m[1], 10);
  let title = m[2].trim();
  const weightIdx = title.indexOf(' (');
  if (weightIdx > 0) title = title.slice(0, weightIdx);

  const start = m.index + m[0].length;
  const end = i + 1 < matches.length ? matches[i + 1].index : guide.length;
  const content = guide.slice(start, end).trim();

  return { id, title, content, infra_refs: [] };
});

// Read infra/*.tf files
const infraDir = join(root, 'infra');
const infraFiles = {};
for (const f of readdirSync(infraDir)) {
  if (!f.endsWith('.tf')) continue;
  infraFiles[f] = readFileSync(join(infraDir, f), 'utf8');
}

// Read other docs/*.md files (excluding the study guide itself)
const docsDir = join(root, 'docs');
const docFiles = {};
for (const f of readdirSync(docsDir)) {
  if (!f.endsWith('.md') || f === 'AZ-104_STUDY_GUIDE.md') continue;
  docFiles[f] = readFileSync(join(docsDir, f), 'utf8');
}

// Annotate domains with references to actual .tf files
const tfRefRe = /[\w]+\.tf/g;
for (const d of domains) {
  const refs = [...new Set([...d.content.matchAll(tfRefRe)].map(m => m[0]))];
  d.infra_refs = refs.filter(r => infraFiles[r]);
}

const out = { domains, infra_files: infraFiles, doc_files: docFiles };
const outPath = join(__dirname, '..', '..', 'data', 'study_content.json');
writeFileSync(outPath, JSON.stringify(out));

console.log(`wrote ${domains.length} domains, ${Object.keys(infraFiles).length} infra files, ${Object.keys(docFiles).length} doc files`);

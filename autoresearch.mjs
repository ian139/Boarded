#!/usr/bin/env node
import { readFile, readdir, stat } from 'node:fs/promises';
import { createHash } from 'node:crypto';
import { performance } from 'node:perf_hooks';
import { validateAttempt, routes } from './lib/boarded/journal.ts';
import { validateAndSanitizeData } from './lib/boarded/store.ts';

const ENTRY_COUNT = 1000;
const WARMUP_ROUNDS = 100;
const TIMED_ROUNDS = 1000;
const SOURCE_ROOTS = ['app', 'apps/ios', 'components', 'lib', 'packages', 'supabase', 'styles'];
const SOURCE_FILES = ['autoresearch.sh', 'autoresearch.mjs', 'next.config.ts', 'postcss.config.mjs', 'tailwind.config.ts', 'tsconfig.json', 'package.json'];
const SERVED_PUBLIC = 'public';

function buildJournal() {
  const entries = Array.from({ length: ENTRY_COUNT }, (_, index) => {
    const routeId = routes[index % routes.length].id;
    const day = String((index % 28) + 1).padStart(2, '0');
    const sent = index % 3 === 0;
    const input = {
      routeId,
      date: `2026-09-${day}`,
      attempts: (index % 12) + 1,
      conditions: `Fixed conditions ${(index % 10) + 1}: cool, dry, and clear.`,
      notes: `Deterministic journal note ${index}. Focused movement and repeatable beta.`,
    };
    if (Object.keys(validateAttempt(input)).length !== 0) {
      throw new Error(`generated attempt ${index} failed domain validation`);
    }
    return {
      id: `benchmark-entry-${String(index).padStart(4, '0')}`,
      ...input,
      outcome: sent ? 'sent' : 'attempted',
      published: sent,
      caption: sent ? `Fixed send caption ${index}.` : '',
    };
  });
  return {
    entries,
    savedRouteIds: ['redpoint-ridge', 'steep-circuit'],
    likedPostIds: ['maya-redpoint'],
    comments: [],
    followingMaya: true,
    activityRead: false,
  };
}

function checksum(data) {
  const hash = createHash('sha256');
  hash.update(JSON.stringify(data));
  return hash.digest('hex');
}

const EXCLUDED_DIRS = new Set(['.build', '.git', '.next', '.omp', '.temp', 'DerivedData', 'build', 'dist', 'node_modules', 'out', 'vendor', 'xcuserdata', '__pycache__']);
const EXCLUDED_FILES = new Set(['.DS_Store']);

async function fileBytes(path) {
  try {
    const info = await stat(path);
    const name = path.split('/').pop();
    if (info.isFile()) {
      if (EXCLUDED_FILES.has(name) || /\.(?:pyc|pyo|tsbuildinfo)$/.test(name)) return 0;
      return info.size;
    }
    if (!info.isDirectory() || EXCLUDED_DIRS.has(name)) return 0;
    let total = 0;
    for (const child of (await readdir(path)).sort()) total += await fileBytes(`${path}/${child}`);
    return total;
  } catch (error) {
    if (error?.code === 'ENOENT') return 0;
    throw error;
  }
}

async function main() {
  const journal = buildJournal();
  const expectedChecksum = checksum(journal);
  const serialized = JSON.stringify(journal);
  const invalid = JSON.parse(serialized);
  invalid.entries[0].attempts = 0;
  if (validateAndSanitizeData(null) !== null || validateAndSanitizeData(invalid) !== null) {
    throw new Error('invalid journal input was accepted');
  }

  let hydrated;
  const hydrate = () => {
    hydrated = validateAndSanitizeData(JSON.parse(serialized));
    if (!hydrated || hydrated.entries.length !== ENTRY_COUNT) throw new Error('journal hydration failed');
  };
  for (let round = 0; round < WARMUP_ROUNDS; round += 1) hydrate();

  // Metrics cover the maintained roots/files above, time only web-journal hydration, and size public/ assets; they are not whole-app metrics.
  const started = performance.now();
  for (let round = 0; round < TIMED_ROUNDS; round += 1) hydrate();
  const elapsed = performance.now() - started;

  if (checksum(hydrated) !== expectedChecksum || hydrated.entries.length !== ENTRY_COUNT) {
    throw new Error('journal workload correctness checksum failed');
  }
  const maintainedBytes = (await Promise.all([...SOURCE_ROOTS, ...SOURCE_FILES].map(fileBytes)))
    .reduce((sum, bytes) => sum + bytes, 0);
  const servedAssetBytes = await fileBytes(SERVED_PUBLIC);

  console.log(`METRIC journal_workload_ms=${elapsed.toFixed(3)}`);
  console.log(`METRIC maintained_bytes=${maintainedBytes}`);
  console.log(`METRIC served_asset_bytes=${servedAssetBytes}`);
}

main().catch((error) => {
  console.error(`autoresearch workload failed: ${error instanceof Error ? error.message : String(error)}`);
  process.exitCode = 1;
});

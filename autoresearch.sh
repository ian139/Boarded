#!/usr/bin/env bash
set -euo pipefail

export CI=1
export NEXT_TELEMETRY_DISABLED=1
export TZ=UTC
export LC_ALL=C

npm run lint >/dev/null
npm run build >/dev/null

port=43129
server_log="$(mktemp)"
response="$(mktemp)"
server_pid=""
cleanup() {
  if [[ -n "$server_pid" ]]; then
    kill "$server_pid" 2>/dev/null || true
    wait "$server_pid" 2>/dev/null || true
  fi
  rm -f "$server_log" "$response"
}
trap cleanup EXIT

npm run start -- --hostname 127.0.0.1 --port "$port" >"$server_log" 2>&1 &
server_pid=$!
for _ in $(seq 1 60); do
  if curl --fail --silent --show-error "http://127.0.0.1:${port}/" >"$response" 2>/dev/null; then
    break
  fi
  if ! kill -0 "$server_pid" 2>/dev/null; then
    cat "$server_log" >&2
    exit 1
  fi
  sleep 0.25
done
test -s "$response"

node <<'NODE'
const { execFileSync } = require('node:child_process');
const { readFileSync } = require('node:fs');

const maintainedExtensions = new Set([
  '.css', '.js', '.json', '.md', '.mjs', '.plist', '.sql', '.swift',
  '.ts', '.tsx', '.yaml', '.yml',
]);
const maintainedNames = new Set([
  '.env.local.example', '.gitattributes', '.gitignore',
]);
const excluded = new Set(['package-lock.json']);
const paths = execFileSync('git', ['ls-files', '-z'])
  .toString('utf8')
  .split('\0')
  .filter(Boolean)
  .filter((path) => {
    if (excluded.has(path)) return false;
    if (maintainedNames.has(path)) return true;
    const dot = path.lastIndexOf('.');
    return dot >= 0 && maintainedExtensions.has(path.slice(dot));
  })
  .sort();

let bytes = 0;
let lines = 0;
for (const path of paths) {
  const content = readFileSync(path);
  bytes += content.length;
  lines += content.length === 0 ? 0 : content.toString('utf8').split('\n').length;
}

console.log(`METRIC maintained_bytes=${bytes}`);
console.log(`METRIC maintained_files=${paths.length}`);
console.log(`METRIC maintained_lines=${lines}`);
NODE

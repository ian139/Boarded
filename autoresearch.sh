#!/usr/bin/env bash
set -euo pipefail

export CI=1
export TZ=UTC
export LC_ALL=C

exec node autoresearch.mjs

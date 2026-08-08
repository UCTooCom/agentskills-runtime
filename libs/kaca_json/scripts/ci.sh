#!/usr/bin/env bash
set -euo pipefail

WITH_BENCH="${1:-}"

echo "[ci] cjpm build"
cjpm build

echo "[ci] cjpm test"
cjpm test

if [[ "${WITH_BENCH}" == "--with-bench" ]]; then
  echo "[ci] cjpm bench --no-color"
  cjpm bench --no-color
fi

echo "[ci] done"

#!/bin/bash
# Integration test runner for http_lib
set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
TEMP_DIR="/tmp/http_lib_integration_test"

echo "=== http_lib Integration Tests ==="
cd "$PROJECT_DIR"
echo "[1/3] Building library..."
cjpm build 2>&1 | tail -1

echo "[2/3] Creating test project..."
rm -rf "$TEMP_DIR"; mkdir -p "$TEMP_DIR/src"
cp "$SCRIPT_DIR/test_main.cj" "$TEMP_DIR/src/main.cj"
cat > "$TEMP_DIR/cjpm.toml" << EOF
[package]
cjc-version = "1.0.5"
name = "integration_test"
version = "1.0.0"
output-type = "executable"
compile-option = "-Woff unused"
src-dir = "src"
target-dir = "target"
[dependencies]
http_lib = { path = "${PROJECT_DIR}" }
EOF

echo "[3/3] Running integration tests..."
cd "$TEMP_DIR"
cjpm build 2>&1 | tail -1
timeout 15 ./target/release/bin/main
EXIT_CODE=$?
rm -rf "$TEMP_DIR"
exit $EXIT_CODE

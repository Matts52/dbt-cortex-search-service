#!/usr/bin/env bash
# Compile all integration test models using DuckDB to validate Jinja and DDL
# without requiring Snowflake credentials. The compiled SQL is written to
# integration_tests/target/compiled/ for inspection.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}/../integration_tests"

echo "==> Installing dbt packages..."
dbt deps --target duckdb

echo "==> Compiling models with DuckDB adapter..."
dbt compile --target duckdb

echo ""
echo "==> Compiled DDL for Cortex Search Service models:"
echo ""

for model in search_minimal search_with_attributes search_raw_ddl; do
  compiled_file=$(find target/compiled -name "${model}.sql" 2>/dev/null | head -1)
  if [[ -n "$compiled_file" ]]; then
    echo "--- ${model} ---"
    cat "$compiled_file"
    echo ""
  else
    echo "WARNING: compiled file not found for ${model}"
  fi
done

echo "==> Compile tests passed."

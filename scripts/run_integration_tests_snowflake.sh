#!/usr/bin/env bash
# Run the full integration test suite against a live Snowflake account.
#
# Required environment variables:
#   SNOWFLAKE_ACCOUNT   - Snowflake account identifier (e.g. xy12345.us-east-1)
#   SNOWFLAKE_USER      - Snowflake username
#   SNOWFLAKE_PASSWORD  - Snowflake password
#   SNOWFLAKE_DATABASE  - Target database
#   SNOWFLAKE_WAREHOUSE - Warehouse to use for dbt + Cortex Search indexing
#
# Optional:
#   SNOWFLAKE_ROLE      - Snowflake role (default: SYSADMIN)
#   SNOWFLAKE_SCHEMA    - Target schema (default: DBT_CORTEX_SEARCH_SERVICE_TESTS)
set -euo pipefail

: "${SNOWFLAKE_ACCOUNT:?SNOWFLAKE_ACCOUNT must be set}"
: "${SNOWFLAKE_USER:?SNOWFLAKE_USER must be set}"
: "${SNOWFLAKE_PASSWORD:?SNOWFLAKE_PASSWORD must be set}"
: "${SNOWFLAKE_DATABASE:?SNOWFLAKE_DATABASE must be set}"
: "${SNOWFLAKE_WAREHOUSE:?SNOWFLAKE_WAREHOUSE must be set}"

export SNOWFLAKE_ROLE="${SNOWFLAKE_ROLE:-SYSADMIN}"
export SNOWFLAKE_SCHEMA="${SNOWFLAKE_SCHEMA:-DBT_CORTEX_SEARCH_SERVICE_TESTS}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}/../integration_tests"

echo "==> Installing dbt packages..."
dbt deps --target snowflake

echo "==> Building all models (seeds + tables + search services + tests)..."
dbt build --target snowflake

echo "==> Verifying Cortex Search Services exist in Snowflake..."
dbt run-operation assert_search_services_exist --target snowflake

echo "==> Integration tests passed."

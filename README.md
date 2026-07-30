# dbt-cortex-search-service

A dbt package that adds a `cortex_search_service` materialization for creating and managing [Snowflake Cortex Search Services](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-search/cortex-search-overview) directly from dbt.

## Overview

Cortex Search Service is Snowflake's managed semantic search engine. You point it at a text column in a SELECT query and it builds a continuously-refreshed vector index that you can query via REST API or the `SNOWFLAKE.CORTEX.SEARCH_PREVIEW` SQL function.

This package lets you define search services as standard dbt models so they participate in the dbt DAG, resolve `ref()` and `source()` dependencies, and are created idempotently on every `dbt run`.

## Installation

Add to your project's `packages.yml`:

```yaml
packages:
  - package: Matts52/dbt_cortex_search_service
    version: [">=1.0.0", "<2.0.0"]
```

Then run:

```bash
dbt deps
```

Requires dbt 1.5.0 or higher and the `dbt-snowflake` adapter.

## Quick Start

Create a `.sql` file in your `models/` directory with `materialized='cortex_search_service'`:

```sql
-- models/support_search.sql
{{
  config(
    materialized = 'cortex_search_service',
    on_column    = 'content',
    warehouse    = 'COMPUTE_WH',
    target_lag   = '1 hour'
  )
}}

select content
from {{ ref('support_docs') }}
```

Run it:

```bash
dbt run --select support_search
```

Snowflake will build a semantic search index over the `content` column and continuously refresh it within 1 hour of changes to the underlying table.

## Usage Modes

### Default Mode (SELECT body + config)

The model body is the SELECT query for the `AS (...)` clause. All Cortex Search Service options are specified in the `config()` block.

```sql
{{
  config(
    materialized    = 'cortex_search_service',
    on_column       = 'transcript_text',
    attributes      = ['region', 'agent_id', 'priority'],
    warehouse       = 'CORTEX_WH',
    target_lag      = '1 day',
    embedding_model = 'snowflake-arctic-embed-l-v2.0',
    comment         = 'Search index for support transcripts'
  )
}}

select
  transcript_text,
  region,
  agent_id,
  priority
from {{ ref('support_transcripts') }}
where created_date >= current_date - 90
```

This emits:

```sql
CREATE OR REPLACE CORTEX SEARCH SERVICE <db>.<schema>.my_model
ON transcript_text
ATTRIBUTES = region, agent_id, priority
WAREHOUSE = CORTEX_WH
TARGET_LAG = '1 day'
EMBEDDING_MODEL = 'snowflake-arctic-embed-l-v2.0'
COMMENT = 'Search index for support transcripts'
AS (
  SELECT transcript_text, region, agent_id, priority
  FROM <db>.<schema>.support_transcripts
  WHERE created_date >= current_date - 90
)
```

### Raw DDL Mode

Set `raw_ddl=true` to pass the model body directly to Snowflake as the DDL that follows `CREATE OR REPLACE CORTEX SEARCH SERVICE <name>`. Use this to access Snowflake syntax not yet supported by the package's config options, or to future-proof against new clauses.

```sql
{{ config(materialized='cortex_search_service', raw_ddl=true) }}
on transcript_text
attributes region, agent_id
warehouse = CORTEX_WH
target_lag = '1 day'
embedding_model = 'snowflake-arctic-embed-l-v2.0'
comment = 'Raw DDL mode example'
as (
  select transcript_text, region, agent_id
  from {{ ref('support_transcripts') }}
)
```

`ref()` and `source()` calls in the body are still resolved by dbt before the DDL is sent to Snowflake.

## Config Reference

| Config | Required | Type | Description |
|--------|----------|------|-------------|
| `on_column` | Yes* | string | Name of the text column to build the search index on. |
| `warehouse` | Yes* | string | Warehouse used for indexing and serving. |
| `target_lag` | Yes* | string | Max lag between base table and index. E.g. `'1 hour'`, `'1 day'`. |
| `attributes` | No | list or string | Columns available for filtering queries. E.g. `['region', 'category']`. |
| `embedding_model` | No | string | Embedding model override. Default: `snowflake-arctic-embed-m-v1.5`. Cannot be changed after creation — must recreate the service. |
| `comment` | No | string | Description stored with the service in Snowflake. |
| `raw_ddl` | No | bool | When `true`, model body is raw DDL after the service name. Default: `false`. |

\* Required in default mode. Not used in raw DDL mode.

Standard dbt configs also work: `database`, `schema`, `alias`, `tags`, `pre_hook`, `post_hook`, `grants`, `enabled`, etc.

## Upstream Dependencies

Because the model body is standard SQL rendered through Jinja, `ref()` and `source()` calls resolve normally. The search service becomes a downstream node in the dbt DAG:

```sql
-- The search service depends on an upstream model
select content, category, region
from {{ ref('cleaned_support_docs') }}
```

Running `dbt run --select +my_search_service` will build all upstream models first, then create the search service.

## Integration with Cortex Agents

If you use [dbt-cortex-agent](https://github.com/mattsenick/dbt-cortex-agent), you can wire a Cortex Agent tool resource to this search service using `ref()`:

```sql
-- In a cortex_agent model:
{{
  config(
    materialized = 'cortex_agent',
    comment      = 'Support agent with semantic search'
  )
}}
models:
  orchestration: claude-4-sonnet
tools:
  - tool_spec:
      type: "cortex_search"
      name: "SupportSearch"
tool_resources:
  SupportSearch:
    cortex_search_service: "{{ ref('support_search') }}"
```

This creates a proper DAG dependency so the agent is always rebuilt after the search service.

## Querying a Search Service

**Via SQL (for testing and exploration):**

```sql
SELECT PARSE_JSON(
  SNOWFLAKE.CORTEX.SEARCH_PREVIEW(
    '<db>.<schema>.support_search',
    '{
      "query": "how do I reset my password",
      "columns": ["content"],
      "limit": 5
    }'
  )
)['results'] AS results;
```

**With attribute filtering:**

```sql
SELECT PARSE_JSON(
  SNOWFLAKE.CORTEX.SEARCH_PREVIEW(
    '<db>.<schema>.support_search',
    '{
      "query": "billing issue",
      "columns": ["content", "region"],
      "filter": {"column_name": "region", "value": "US"},
      "limit": 10
    }'
  )
)['results'] AS results;
```

**Via REST API:**

```bash
curl -X POST \
  "https://<account>.snowflakecomputing.com/api/v2/databases/<db>/schemas/<schema>/cortex-search-services/<service>:query" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"query": "password reset", "columns": ["content"], "limit": 5}'
```

## Running the Integration Tests

### Compile tests (no Snowflake required)

```bash
bash scripts/run_compile_tests_duckdb.sh
```

This validates Jinja rendering and DDL structure on DuckDB. Compiled SQL is written to `integration_tests/target/compiled/`.

### Full integration tests (requires Snowflake)

```bash
export SNOWFLAKE_ACCOUNT=xy12345.us-east-1
export SNOWFLAKE_USER=my_user
export SNOWFLAKE_PASSWORD=my_password
export SNOWFLAKE_DATABASE=my_db
export SNOWFLAKE_WAREHOUSE=COMPUTE_WH

bash scripts/run_integration_tests_snowflake.sh
```

This runs `dbt build` (seeds + models + tests) followed by `dbt run-operation assert_search_services_exist` to verify the services exist in Snowflake.

## Limitations

- **No RENAME**: Cortex Search Services do not support `ALTER ... RENAME TO`. To rename a service, run it under the new model name and drop the old one manually.
- **Embedding model is immutable**: `EMBEDDING_MODEL` cannot be changed after creation. Use `CREATE OR REPLACE` (which this package always does) or drop and recreate the service.
- **100M row limit**: The source SELECT must return fewer than 100M rows for optimal serving performance.
- **Change tracking**: Automatically enabled on base tables. Target lag must be shorter than the data retention period.
- **OBJECT columns**: Attribute columns cannot be of type `OBJECT`.
- **Snowflake only**: The `cortex_search_service` materialization only executes on the Snowflake adapter. On other adapters it compiles DDL for inspection but does not execute.

## References

- [Cortex Search Service Overview](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-search/cortex-search-overview)
- [CREATE CORTEX SEARCH SERVICE](https://docs.snowflake.com/en/sql-reference/sql/create-cortex-search)
- [ALTER CORTEX SEARCH SERVICE](https://docs.snowflake.com/en/sql-reference/sql/alter-cortex-search)
- [DROP CORTEX SEARCH SERVICE](https://docs.snowflake.com/en/sql-reference/sql/drop-cortex-search)
- [Query a Cortex Search Service](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-search/query-cortex-search-service)
- [SEARCH_PREVIEW function](https://docs.snowflake.com/en/sql-reference/functions/search_preview-snowflake-cortex)

## License

MIT — see [LICENSE](LICENSE).

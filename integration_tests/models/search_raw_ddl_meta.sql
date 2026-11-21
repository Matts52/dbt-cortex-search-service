{{ config(materialized='cortex_search_service', meta={'raw_ddl': true}) }}
on content
attributes category, region
warehouse = {{ env_var('SNOWFLAKE_WAREHOUSE', 'COMPUTE_WH') }}
target_lag = '1 day'
comment = 'Integration test: raw DDL mode set under meta'
as (
  select content, category, region
  from {{ ref('docs_base') }}
)

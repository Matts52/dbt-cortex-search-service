{{ config(materialized='cortex_search_service', raw_ddl=true) }}
on content
attributes = category, region
warehouse = {{ env_var('SNOWFLAKE_WAREHOUSE', 'COMPUTE_WH') }}
target_lag = '1 day'
comment = 'Integration test: raw DDL pass-through mode'
as (
  select content, category, region
  from {{ ref('docs_base') }}
)

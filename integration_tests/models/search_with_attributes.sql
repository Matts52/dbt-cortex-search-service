{{
  config(
    materialized = 'cortex_search_service',
    on_column    = 'content',
    attributes   = ['category', 'region'],
    warehouse    = env_var('SNOWFLAKE_WAREHOUSE', 'COMPUTE_WH'),
    target_lag   = '1 hour',
    comment      = 'Integration test: search service with attribute filtering'
  )
}}

select content, category, region
from {{ ref('docs_base') }}

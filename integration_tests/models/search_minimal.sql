{{
  config(
    materialized = 'cortex_search_service',
    on_column    = 'content',
    warehouse    = env_var('SNOWFLAKE_WAREHOUSE', 'COMPUTE_WH'),
    target_lag   = '1 day'
  )
}}

select content
from {{ ref('docs_base') }}

{{
  config(
    materialized = 'cortex_search_service',
    meta = {
      'on_column':  'content',
      'warehouse':  env_var('SNOWFLAKE_WAREHOUSE', 'COMPUTE_WH'),
      'target_lag': '1 day',
      'attributes': ['category', 'region'],
      'comment':    'Integration test: meta-based config'
    }
  )
}}

select content, category, region
from {{ ref('docs_base') }}

{{ config(materialized='table') }}

select doc_id, content, category, region
from {{ ref('docs_seed') }}

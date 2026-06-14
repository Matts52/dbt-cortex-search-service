-- Validates that the base table has no null content values.
-- A null in the indexed column would be silently skipped by Cortex Search,
-- so we catch it here as a data quality gate.
select count(*) as null_count
from {{ ref('docs_base') }}
where content is null
having count(*) > 0

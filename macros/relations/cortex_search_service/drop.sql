{% macro snowflake__get_drop_cortex_search_service_sql(relation) %}
{#-
--  DDL to drop a Cortex Search Service if it exists.
--
--  Args:
--      relation: SnowflakeRelation - the service to drop
--  Returns: templated string
-#}
    drop cortex search service if exists {{ relation }}
{% endmacro %}

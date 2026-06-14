{%- macro snowflake__get_cortex_search_service_rename_sql(relation, new_name) -%}
{#-
--  Cortex Search Services do not support RENAME via ALTER. This macro raises
--  a compiler error to surface the limitation clearly rather than silently
--  failing or emitting invalid SQL.
--
--  To rename a service: run `dbt run` with the new model name to create a new
--  service, then drop the old one manually with:
--      DROP CORTEX SEARCH SERVICE IF EXISTS <old_name>;
-#}
    {{ exceptions.raise_compiler_error(
        "Cortex Search Services do not support RENAME. "
        ~ "Use `dbt run` to recreate the service under a new model name, "
        ~ "then drop the old one manually: "
        ~ "DROP CORTEX SEARCH SERVICE IF EXISTS " ~ relation ~ ";"
    ) }}
{%- endmacro -%}

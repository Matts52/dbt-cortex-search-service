{#-
--  Verifies that the Cortex Search Services created by `dbt build` actually
--  exist in Snowflake.
--
--  Cortex Search Services are not exposed through INFORMATION_SCHEMA, so
--  existence must be checked via SHOW CORTEX SEARCH SERVICES + RESULT_SCAN,
--  which requires running two statements in sequence — something a singular
--  dbt test (a single SELECT) can't do. This is implemented as a
--  run-operation instead:
--
--      dbt run-operation assert_search_services_exist --target snowflake
--
--  It raises a compiler error (non-zero exit) if any expected service is
--  missing, so it can be wired into CI after `dbt build`.
-#}
{% macro assert_search_services_exist() %}
  {%- if execute -%}
    {%- set expected = ['search_minimal', 'search_with_attributes', 'search_raw_ddl'] -%}
    {%- for model_name in expected -%}
      {%- set rel = ref(model_name) -%}
      {%- do run_query(
          "show cortex search services like '"
          ~ rel.identifier
          ~ "' in schema "
          ~ rel.database ~ "." ~ rel.schema
      ) -%}
      {%- set results = run_query("select count(*) as n from table(result_scan(last_query_id()))") -%}
      {%- set n = results.columns[0].values()[0] -%}
      {%- if n | int < 1 -%}
        {{ exceptions.raise_compiler_error("Expected search service not found: " ~ rel) }}
      {%- else -%}
        {{ log("OK - search service exists: " ~ rel, info=true) }}
      {%- endif -%}
    {%- endfor -%}
    {{ log("All expected Cortex Search Services exist.", info=true) }}
  {%- endif -%}
{% endmacro %}

{#-
--  Verifies that dbt's relation lookup finds the search services built by `dbt build`, which is
--  what `--defer` checks before falling back to the deferred (production) relation. Without the
--  package's snowflake__list_relations_without_caching (enabled by the dispatch config in
--  dbt_project.yml), SHOW OBJECTS leaves search services out and get_relation returns none.
--
--      dbt run-operation assert_search_services_in_relation_cache
-#}
{% macro assert_search_services_in_relation_cache() %}
  {%- if execute -%}
    {%- for model_name in ['search_minimal', 'search_with_attributes'] -%}
      {%- set rel = ref(model_name) -%}
      {%- if adapter.get_relation(rel.database, rel.schema, rel.identifier) is none -%}
        {{ exceptions.raise_compiler_error("Search service not in the relation cache, --defer would skip it: " ~ rel) }}
      {%- else -%}
        {{ log("OK - search service in the relation cache: " ~ rel, info=true) }}
      {%- endif -%}
    {%- endfor -%}
  {%- endif -%}
{% endmacro %}

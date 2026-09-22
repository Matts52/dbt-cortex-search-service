{% macro snowflake__create_or_replace_cortex_search_service() %}
{#-
--  Orchestrates the CREATE OR REPLACE CORTEX SEARCH SERVICE statement for a
--  model using the `cortex_search_service` materialization. Runs pre/post
--  hooks around the main statement, exactly like dbt's built-in
--  materializations.
--
--  Returns: {'relations': [target_relation]}
-#}
  {%- set identifier = model['alias'] -%}

  {%- set target_relation = api.Relation.create(
      identifier=identifier, schema=schema, database=database,
      type='view') -%}

  {{ run_hooks(pre_hooks) }}

  -- build model
  {% call statement('main') -%}
    {{ dbt_cortex_search_service.snowflake__get_create_cortex_search_service_sql(target_relation, sql) }}
  {%- endcall %}

  {{ run_hooks(post_hooks) }}

  {{ return({'relations': [target_relation]}) }}

{% endmacro %}


{% macro snowflake__get_create_cortex_search_service_sql(relation, sql) -%}
{#-
--  Produce the DDL that creates a Cortex Search Service.
--
--  Args:
--  - relation: Union[SnowflakeRelation, str]
--      - SnowflakeRelation - required for relation.render()
--      - str - is already the rendered relation name
--  - sql: str - the compiled body of the model (the SELECT query)
--
--  Two modes, selected by the `raw_ddl` config (default false):
--
--  1. Default mode (raw_ddl=false): the model body is the SELECT query for
--     the AS (...) clause. Required configs: on_column, warehouse, target_lag.
--     Optional configs: attributes (list or string), embedding_model, comment.
--
--  2. Raw DDL mode (raw_ddl=true): the model body is everything that follows
--     `CREATE OR REPLACE CORTEX SEARCH SERVICE <name>` — a direct pass-through
--     to the Snowflake SQL layer. This guarantees forward compatibility with
--     any future CREATE CORTEX SEARCH SERVICE syntax without a package upgrade.
--
--  Returns: a valid DDL statement that creates the search service.
-#}

  {%- set _meta = config.get('meta', default={}) -%}
  {%- set raw_ddl = _meta.get('raw_ddl', config.get('raw_ddl', false)) -%}

  {%- if raw_ddl -%}

    create or replace cortex search service {{ relation }}
    {{ sql }}

  {%- else -%}

    {%- set on_column       = _meta.get('on_column',       config.get('on_column')) -%}
    {%- set warehouse       = _meta.get('warehouse',       config.get('warehouse')) -%}
    {%- set target_lag      = _meta.get('target_lag',      config.get('target_lag')) -%}
    {%- set attributes      = _meta.get('attributes',      config.get('attributes',      none)) -%}
    {%- set embedding_model = _meta.get('embedding_model', config.get('embedding_model', none)) -%}
    {%- set comment         = _meta.get('comment',         config.get('comment',         none)) -%}

    {%- if on_column is none -%}
      {{ exceptions.raise_compiler_error(
          "cortex_search_service requires `on_column` in config. "
          ~ "Example: config(on_column='content', warehouse='COMPUTE_WH', target_lag='1 day')"
      ) }}
    {%- endif -%}
    {%- if warehouse is none -%}
      {{ exceptions.raise_compiler_error(
          "cortex_search_service requires `warehouse` in config. "
          ~ "Example: config(on_column='content', warehouse='COMPUTE_WH', target_lag='1 day')"
      ) }}
    {%- endif -%}
    {%- if target_lag is none -%}
      {{ exceptions.raise_compiler_error(
          "cortex_search_service requires `target_lag` in config. "
          ~ "Example: config(on_column='content', warehouse='COMPUTE_WH', target_lag='1 day')"
      ) }}
    {%- endif -%}

    create or replace cortex search service {{ relation }}
    on {{ on_column }}
    {%- if attributes is not none %}
    attributes {{ dbt_cortex_search_service.cortex_search_service_render_attributes(attributes) }}
    {%- endif %}
    warehouse = {{ warehouse }}
    target_lag = '{{ target_lag }}'
    {%- if embedding_model is not none %}
    embedding_model = '{{ embedding_model }}'
    {%- endif %}
    {%- if comment is not none %}
    comment = {{ dbt_cortex_search_service.cortex_search_service_quote_string(comment) }}
    {%- endif %}
    as (
      {{ sql }}
    )

  {%- endif -%}

{%- endmacro %}


{% macro cortex_search_service_quote_string(value) -%}
{#-
--  Wrap a value in single quotes for use as a SQL string literal, doubling
--  any embedded single quotes so the literal stays well-formed.
-#}
  {{- "'" ~ (value | string | replace("'", "''")) ~ "'" -}}
{%- endmacro %}


{% macro cortex_search_service_render_attributes(attributes) -%}
{#-
--  Render the ATTRIBUTES clause value. Accepts either:
--    - a list ['col1', 'col2'] — joined with ', ', or
--    - a pre-formatted string 'col1, col2' — used as-is.
--  Returns the rendered comma-separated column list.
-#}
  {%- if attributes is string -%}
    {{- attributes -}}
  {%- else -%}
    {{- attributes | join(', ') -}}
  {%- endif -%}
{%- endmacro %}

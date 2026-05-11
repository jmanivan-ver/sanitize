{% macro sanitize_columns(source_relation, columns_config=none) %}
{#
    Main orchestration macro for tag-based data sanitization.

    Args:
        source_relation (str): Name of the source CTE/table to sanitize
        columns_config (dict, optional): Explicit column->tags mapping, e.g.:
            {
                'first_name': ['sanitize:trim', 'sanitize:upper'],
                'last_name': []
            }
            When provided, bypasses model.columns introspection (needed for unit tests).
            When omitted, reads tags from model.columns via schema.yml config.

    Returns:
        str: SELECT statement with sanitization applied to tagged columns

    Usage (normal — reads tags from schema.yml):
        sanitized AS (
            {{ sanitize_columns('renamed') }}
        )

    Usage (explicit config — unit tests / scripted pipelines):
        sanitized AS (
            {{ sanitize_columns('renamed', {
                'first_name': ['sanitize:trim', 'sanitize:upper'],
                'last_name': []
            }) }}
        )
#}

{#- Validate source_relation: must be a plain identifier (letters/digits/underscores) or a dbt Relation object.
    Relation objects (from ref()/source()) are already safely quoted by dbt — only plain strings are checked. -#}
{%- if source_relation is string -%}
    {%- set valid_rel_chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_' -%}
    {%- set rel_valid = (source_relation | length > 0) -%}
    {%- for char in source_relation -%}
        {%- if char not in valid_rel_chars -%}{%- set rel_valid = false -%}{%- endif -%}
    {%- endfor -%}
    {%- if not rel_valid -%}
        {{ exceptions.raise_compiler_error(
            "sanitize: source_relation '" ~ source_relation ~ "' is not a valid identifier. "
            ~ "Pass a plain CTE name (letters, digits, underscores only) or a dbt Relation object from ref()/source()."
        ) }}
    {%- endif -%}
{%- endif -%}

{%- set model_name = this.name -%}
{%- set sanitization_rules = get_sanitization_rules(model_name, columns_config) -%}

{%- if sanitization_rules | length == 0 -%}
    select * from {{ source_relation }}
{%- else -%}
{%- set columns_sql = [] -%}
{%- for column_name, column_config in sanitization_rules.items() -%}
    {%- if column_config.tags | length > 0 -%}
        {%- set reordered_tags = reorder_tags(column_config.tags) -%}
        {%- set optimized_sql = optimize_sql(column_name, reordered_tags) -%}
        {%- set _ = columns_sql.append('        ' ~ optimized_sql ~ ' as ' ~ column_name) -%}
    {%- else -%}
        {%- set _ = columns_sql.append('        ' ~ column_name) -%}
    {%- endif -%}
{%- endfor -%}
    select
{{ columns_sql | join(',\n') }}
    from {{ source_relation }}
{%- endif -%}

{% endmacro %}

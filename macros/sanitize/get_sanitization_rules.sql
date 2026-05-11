{% macro get_sanitization_rules(model_name, columns_config=none) %}
{#
    Extracts sanitization rules for a model's columns.

    Args:
        model_name (str): Name of the model (used for error messages)
        columns_config (dict, optional): Explicit {column_name: [tags]} mapping.
            When provided, used directly — bypasses model.columns introspection.
            When omitted, reads tags from model.columns (populated from schema.yml config).

    Returns:
        dict: Mapping of column_name -> {tags: [...]}
#}

{%- set sanitization_rules = {} -%}

{%- if columns_config is not none -%}

    {#- Explicit columns_config provided (e.g. from unit tests) -#}
    {%- for column_name, tags in columns_config.items() -%}

        {#- Validate column name is a safe SQL identifier (letters, digits, underscores, dots only).
            This is the entry point where column names become SQL expressions — catching injection
            here is more effective than validating the progressively-nested column_expr later. -#}
        {%- set valid_chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_.' -%}
        {%- set col_valid = true -%}
        {%- for char in column_name -%}
            {%- if char not in valid_chars -%}{%- set col_valid = false -%}{%- endif -%}
        {%- endfor -%}
        {%- if not col_valid or column_name | length == 0 -%}
            {{ exceptions.raise_compiler_error(
                "sanitize: column name '" ~ column_name ~ "' contains invalid characters. "
                ~ "Column names must contain only letters, digits, underscores, or dots."
            ) }}
        {%- endif -%}

        {%- set sanitize_tags = [] -%}
        {%- for tag in tags -%}
            {%- if tag.startswith('sanitize:') -%}
                {%- if not is_valid_tag(tag) -%}
                    {{ exceptions.raise_compiler_error(
                        "sanitize: invalid sanitization tag '" ~ tag ~ "' on column '" ~ column_name ~ "'."
                    ) }}
                {%- endif -%}
                {%- set _ = sanitize_tags.append(tag) -%}
            {%- endif -%}
        {%- endfor -%}
        {%- set _ = sanitization_rules.update({
            column_name: {'tags': sanitize_tags}
        }) -%}
    {%- endfor -%}

{%- else -%}

    {#- Fall back to model.columns from schema.yml config -#}
    {%- set columns = model.columns -%}
    {%- for column_name, column_config in columns.items() -%}

        {#- Apply the same safe-identifier guard used for columns_config above.
            schema.yml is developer-controlled, but automated catalog tools or
            copy-paste errors can introduce unexpected characters. -#}
        {%- set valid_chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_.' -%}
        {%- set col_valid = (column_name | length > 0) -%}
        {%- for char in column_name -%}
            {%- if char not in valid_chars -%}{%- set col_valid = false -%}{%- endif -%}
        {%- endfor -%}
        {%- if not col_valid -%}
            {{ exceptions.raise_compiler_error(
                "sanitize: column name '" ~ column_name ~ "' in model.columns contains invalid characters. "
                ~ "Column names must contain only letters, digits, underscores, or dots."
            ) }}
        {%- endif -%}

        {%- set column_tags = column_config.tags | default([]) -%}
        {%- set sanitize_tags = [] -%}
        {%- for tag in column_tags -%}
            {%- if tag.startswith('sanitize:') -%}
                {%- if not is_valid_tag(tag) -%}
                    {{ exceptions.raise_compiler_error(
                        "sanitize: invalid sanitization tag '" ~ tag ~ "' on column '" ~ column_name ~ "'."
                    ) }}
                {%- endif -%}
                {%- set _ = sanitize_tags.append(tag) -%}
            {%- endif -%}
        {%- endfor -%}
        {%- set _ = sanitization_rules.update({
            column_name: {'tags': sanitize_tags}
        }) -%}
    {%- endfor -%}

{%- endif -%}

{{ return(sanitization_rules) }}

{% endmacro %}

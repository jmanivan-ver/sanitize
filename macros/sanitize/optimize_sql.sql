{% macro optimize_sql(column_name, tags) %}
{#
    Generates optimized SQL expression by merging compatible operations.

    Args:
        column_name (str): Name of the column to transform
        tags (list): List of sanitization tags (pre-ordered by priority)

    Returns:
        str: Optimized SQL expression via apply_sanitize_tag dispatch
#}

{%- if tags | length == 0 -%}
    {{ return(column_name) }}
{%- endif -%}

{%- set enable_optimization = var('sanitize_enable_optimization', true) -%}

{%- if not enable_optimization -%}
    {{ return(build_naive_sql(column_name, tags)) }}
{%- endif -%}

{#- Group tags by type from registry -#}
{%- set regex_tags = [] -%}
{%- set case_tags = [] -%}
{%- set simple_tags = [] -%}

{%- for tag in tags -%}
    {%- set metadata = get_tag_metadata(tag) -%}
    {%- if metadata.type == 'regex' -%}
        {%- set _ = regex_tags.append(tag) -%}
    {%- elif metadata.type == 'case' -%}
        {%- set _ = case_tags.append(tag) -%}
    {%- else -%}
        {%- set _ = simple_tags.append(tag) -%}
    {%- endif -%}
{%- endfor -%}

{#- Sort simple_tags by priority (input may be unsorted when called directly) -#}
{%- set simple_with_priority = [] -%}
{%- for tag in simple_tags -%}
    {%- set _ = simple_with_priority.append({'priority': get_tag_metadata(tag).priority, 'tag': tag}) -%}
{%- endfor -%}
{%- set simple_sorted = [] -%}
{%- for item in simple_with_priority | sort(attribute='priority') -%}
    {%- set _ = simple_sorted.append(item.tag) -%}
{%- endfor -%}

{#- Determine the lowest priority among regex and case tags.
    Simple tags with lower priority (e.g. sanitize:trim at 1) must be applied
    before the regex/case batch (e.g. sanitize:strip_special at 2). -#}
{%- set batch_min_priority = 999 -%}
{%- if regex_tags | length > 0 -%}
    {%- set batch_min_priority = get_tag_metadata(regex_tags[0]).priority -%}
{%- endif -%}
{%- if case_tags | length > 0 -%}
    {%- set cp = get_tag_metadata(case_tags[0]).priority -%}
    {%- if cp < batch_min_priority -%}{%- set batch_min_priority = cp -%}{%- endif -%}
{%- endif -%}

{#- Build optimized SQL -#}
{%- set ns = namespace(sql_expr=column_name) -%}

{#- Apply simple tags whose priority precedes the regex/case batch -#}
{%- for tag in simple_sorted -%}
    {%- if get_tag_metadata(tag).priority < batch_min_priority -%}
        {%- set ns.sql_expr = apply_sanitize_tag(ns.sql_expr, tag) | trim -%}
    {%- endif -%}
{%- endfor -%}

{#- Apply regex tags — naive nesting -#}
{%- if regex_tags | length > 1 -%}
    {%- set ns.sql_expr = build_naive_sql(ns.sql_expr, regex_tags) -%}
{%- elif regex_tags | length == 1 -%}
    {%- set ns.sql_expr = apply_sanitize_tag(ns.sql_expr, regex_tags[0]) | trim -%}
{%- endif -%}

{#- Apply CASE tags — merge into single CASE when multiple -#}
{%- if case_tags | length > 1 -%}
    {%- set ns.sql_expr = merge_case_statements(ns.sql_expr, case_tags) -%}
{%- elif case_tags | length == 1 -%}
    {%- set ns.sql_expr = apply_sanitize_tag(ns.sql_expr, case_tags[0]) | trim -%}
{%- endif -%}

{#- Apply remaining simple tags (priority >= batch boundary) -#}
{%- for tag in simple_sorted -%}
    {%- if get_tag_metadata(tag).priority >= batch_min_priority -%}
        {%- set ns.sql_expr = apply_sanitize_tag(ns.sql_expr, tag) | trim -%}
    {%- endif -%}
{%- endfor -%}

{{ return(ns.sql_expr) }}

{% endmacro %}


{% macro build_naive_sql(column_name, tags) %}
{#
    Builds SQL without optimization (naive nesting).
    Used when optimization is disabled or for regex chains.
#}
{%- set ns = namespace(sql_expr=column_name) -%}

{%- for tag in tags -%}
    {%- set ns.sql_expr = apply_sanitize_tag(ns.sql_expr, tag) | trim -%}
{%- endfor -%}

{{ return(ns.sql_expr) }}

{% endmacro %}


{% macro merge_case_statements(column_expr, case_tags) %}
{#
    Flattens multiple CASE expressions into a single CASE with multiple WHEN clauses.

    Example:
        Input:  ['sanitize:nullif_negative', 'sanitize:nullif_future']
        Output: CASE WHEN col < 0 THEN NULL WHEN col > CURRENT_DATE() THEN NULL ELSE col END
#}
{%- set when_clauses = [] -%}

{%- for tag in case_tags -%}
    {%- if tag == 'sanitize:nullif_negative' -%}
        {%- set _ = when_clauses.append("WHEN " ~ column_expr ~ " < 0 THEN NULL") -%}
    {%- elif tag == 'sanitize:nullif_future' -%}
        {%- set _ = when_clauses.append("WHEN " ~ column_expr ~ " > " ~ sanitize__current_date() ~ " THEN NULL") -%}
    {%- elif tag == 'sanitize:nullif_ancient' -%}
        {%- set min_date = var('sanitize_min_date', '1900-01-01') -%}
        {#- Validate min_date is a safe YYYY-MM-DD literal before interpolating into SQL -#}
        {%- set valid_date_chars = '0123456789-' -%}
        {%- set date_valid = (min_date | length == 10) -%}
        {%- for char in min_date -%}
            {%- if char not in valid_date_chars -%}{%- set date_valid = false -%}{%- endif -%}
        {%- endfor -%}
        {%- if not date_valid -%}
            {{ exceptions.raise_compiler_error(
                "sanitize: sanitize_min_date var '" ~ min_date ~ "' is not a valid date. "
                ~ "Expected format: YYYY-MM-DD (e.g. '1900-01-01')."
            ) }}
        {%- endif -%}
        {%- set _ = when_clauses.append("WHEN " ~ column_expr ~ " < '" ~ min_date ~ "' THEN NULL") -%}
    {%- endif -%}
{%- endfor -%}

{%- if when_clauses | length > 0 -%}
    {%- set merged_case = "CASE " ~ when_clauses | join(' ') ~ " ELSE " ~ column_expr ~ " END" -%}
    {{ return(merged_case) }}
{%- else -%}
    {{ return(column_expr) }}
{%- endif -%}

{% endmacro %}

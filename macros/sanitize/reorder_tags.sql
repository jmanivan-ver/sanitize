{% macro reorder_tags(tags) %}
{#
    Reorders tags by priority to ensure correct semantic execution.

    Args:
        tags (list): List of sanitization tags

    Returns:
        list: Tags sorted by priority (lowest to highest)

    Example:
        Input:  ['sanitize:upper', 'sanitize:trim', 'sanitize:nullif_empty']
        Output: ['sanitize:trim', 'sanitize:upper', 'sanitize:nullif_empty']

    Priority levels (execution order):
        1 - Edge cleanup (trim)
        2 - Interior cleanup (normalize_whitespace, strip_special)
        3 - Case conversion (upper, lower, title)
        4 - Null conversion (nullif_empty, nullif_zero, nullif_negative)
        5 - Numeric operations (round_2, round_4, abs)
        6 - Date operations (date_floor, nullif_future, nullif_ancient)
        7 - Complex formatting (normalize_phone)
#}

{%- set tag_priorities = [] -%}

{%- for tag in tags -%}
    {%- set metadata = get_tag_metadata(tag) -%}
    {%- set _ = tag_priorities.append({'priority': metadata.priority, 'tag': tag}) -%}
{%- endfor -%}

{%- set sorted_tags = tag_priorities | sort(attribute='priority') -%}

{%- set reordered = [] -%}
{%- for item in sorted_tags -%}
    {%- set _ = reordered.append(item.tag) -%}
{%- endfor -%}

{{ return(reordered) }}

{% endmacro %}

{% macro get_tag_registry() %}
{#
    Returns the complete registry of allowed sanitization tags with metadata.

    Returns:
        dict: Tag registry with priority, type, combinable, and description
#}

{#
    type field controls how optimize_sql groups and processes tags:
      'simple' — plain function call, no special handling needed
      'regex'  — uses REGEXP_REPLACE, may be merged/optimized
      'case'   — uses CASE expression, may be merged into single CASE
#}
{%- set registry = {
    'sanitize:trim':                 {'priority': 1, 'type': 'simple', 'combinable': true,  'description': 'Remove leading/trailing whitespace'},
    'sanitize:normalize_whitespace': {'priority': 2, 'type': 'regex',  'combinable': true,  'description': 'Collapse multiple spaces to single space'},
    'sanitize:strip_special':        {'priority': 2, 'type': 'regex',  'combinable': true,  'description': 'Remove special characters except spaces'},
    'sanitize:upper':                {'priority': 3, 'type': 'simple', 'combinable': true,  'description': 'Convert to uppercase'},
    'sanitize:lower':                {'priority': 3, 'type': 'simple', 'combinable': true,  'description': 'Convert to lowercase'},
    'sanitize:title':                {'priority': 3, 'type': 'simple', 'combinable': true,  'description': 'Convert to title case'},
    'sanitize:nullif_empty':         {'priority': 4, 'type': 'simple', 'combinable': true,  'description': 'Convert empty strings to NULL'},
    'sanitize:nullif_zero':          {'priority': 4, 'type': 'simple', 'combinable': true,  'description': 'Convert zero to NULL'},
    'sanitize:nullif_negative':      {'priority': 4, 'type': 'case',   'combinable': false, 'description': 'Convert negative numbers to NULL'},
    'sanitize:round_2':              {'priority': 5, 'type': 'simple', 'combinable': true,  'description': 'Round to 2 decimal places'},
    'sanitize:round_4':              {'priority': 5, 'type': 'simple', 'combinable': true,  'description': 'Round to 4 decimal places'},
    'sanitize:abs':                  {'priority': 5, 'type': 'simple', 'combinable': true,  'description': 'Absolute value'},
    'sanitize:date_floor':           {'priority': 6, 'type': 'simple', 'combinable': true,  'description': 'Truncate to day boundary'},
    'sanitize:nullif_future':        {'priority': 6, 'type': 'case',   'combinable': false, 'description': 'Convert future dates to NULL'},
    'sanitize:nullif_ancient':       {'priority': 6, 'type': 'case',   'combinable': false, 'description': 'Convert pre-1900 dates to NULL'},
    'sanitize:normalize_phone':      {'priority': 7, 'type': 'regex',  'combinable': false, 'description': 'Extract digits only from phone numbers'}
} -%}

{#- Custom tag extension is not supported. Raise a clear error if someone sets this var. -#}
{%- if var('sanitize_custom_tags', none) is not none -%}
    {{ exceptions.raise_compiler_error(
        "sanitize: the sanitize_custom_tags var is not supported. "
        ~ "To add custom tags, add them directly to the get_tag_registry macro in your project."
    ) }}
{%- endif -%}

{{ return(registry) }}

{% endmacro %}


{% macro is_valid_tag(tag) %}
{#
    Returns true if the tag exists in the registry, false otherwise.
#}
{%- set registry = get_tag_registry() -%}
{{ return(tag in registry) }}
{% endmacro %}


{% macro get_tag_metadata(tag) %}
{#
    Returns the registry metadata dict for a specific tag.
    Raises a compiler error if the tag is not found.
#}
{%- set registry = get_tag_registry() -%}
{%- if tag not in registry -%}
    {{ exceptions.raise_compiler_error(
        "sanitize: unknown tag '" ~ tag ~ "'. "
        ~ "Supported tags: " ~ registry.keys() | list | join(', ') ~ "."
    ) }}
{%- endif -%}
{{ return(registry[tag]) }}
{% endmacro %}

{% macro apply_sanitize_tag(column_expr, tag) %}
{#
    Routes a sanitize tag to its SQL expression for the current adapter.

    Args:
        column_expr (str): Trusted SQL identifier or nested SQL expression to transform.
            SECURITY: this value is interpolated directly into SQL. It must be a
            column name sourced from model.columns or a pre-validated columns_config
            dict — never a user-supplied string from an external source.
        tag (str): Sanitize tag from the registry (e.g. 'sanitize:trim')

    Returns:
        str: SQL expression with transformation applied

    Adapter behaviour:
        Two tags are adapter-specific (resolved via adapter.dispatch):
          sanitize:normalize_whitespace — regex dialect differs per engine
          sanitize:nullif_future        — CURRENT_DATE vs CURRENT_DATE()
        All other tags produce identical SQL across all adapters.
        Unrecognised adapters fall back to default__ variants (ANSI SQL).

    Examples:
        {{ sanitize_columns('source', {'first_name': ['sanitize:trim']}) }}
        -- Returns: TRIM(first_name)
#}
{%- if tag == 'sanitize:trim' -%}
TRIM({{ column_expr }})
{%- elif tag == 'sanitize:normalize_whitespace' -%}
{{ sanitize__regexp_whitespace(column_expr) -}}
{%- elif tag == 'sanitize:strip_special' -%}
{{ sanitize__strip_special(column_expr) -}}
{%- elif tag == 'sanitize:upper' -%}
UPPER({{ column_expr }})
{%- elif tag == 'sanitize:lower' -%}
LOWER({{ column_expr }})
{%- elif tag == 'sanitize:title' -%}
{{ sanitize__title(column_expr) -}}
{%- elif tag == 'sanitize:nullif_empty' -%}
NULLIF({{ column_expr }}, '')
{%- elif tag == 'sanitize:nullif_zero' -%}
NULLIF({{ column_expr }}, 0)
{%- elif tag == 'sanitize:nullif_negative' -%}
CASE WHEN {{ column_expr }} < 0 THEN NULL ELSE {{ column_expr }} END
{%- elif tag == 'sanitize:round_2' -%}
ROUND({{ column_expr }}, 2)
{%- elif tag == 'sanitize:round_4' -%}
ROUND({{ column_expr }}, 4)
{%- elif tag == 'sanitize:abs' -%}
ABS({{ column_expr }})
{%- elif tag == 'sanitize:date_floor' -%}
{{ sanitize__date_trunc_day(column_expr) -}}
{%- elif tag == 'sanitize:nullif_future' -%}
CASE WHEN {{ column_expr }} > {{ sanitize__current_date() }} THEN NULL ELSE {{ column_expr }} END
{%- elif tag == 'sanitize:nullif_ancient' -%}
CASE WHEN {{ column_expr }} < '1900-01-01' THEN NULL ELSE {{ column_expr }} END
{%- elif tag == 'sanitize:normalize_phone' -%}
{{ sanitize__normalize_phone(column_expr) -}}
{%- else -%}
{%- set known_tags = get_tag_registry().keys() | list -%}
{{ exceptions.raise_compiler_error(
    "sanitize: unknown sanitize tag '" ~ tag ~ "'. "
    ~ "Supported tags: " ~ known_tags | join(', ') ~ "."
) }}
{%- endif %}
{% endmacro %}


{# ============================================================
   ADAPTER DISPATCH MACROS
   ============================================================
   dbt resolves adapter.dispatch() by trying {adapter}__{macro}
   first, then falling back to default__{macro} silently.

   If your adapter is not listed below, the default__ variant
   is used automatically — no error is raised. Verify the
   default__ SQL is correct for your engine before deploying.
   To add support for a new adapter, add a {adapter}__ variant
   following the same pattern as the databricks__ macros below.
   ============================================================ #}

{# ============================================================
   sanitize__regexp_whitespace
   Dispatches \s regex escaping — differs across SQL engines:
     Databricks/Spark: Java regex — [\\s]+ needed in SQL string
     default         : explicit char class, universally safe
   ============================================================ #}

{% macro sanitize__regexp_whitespace(column_expr) %}
    {{ return(adapter.dispatch('sanitize__regexp_whitespace', 'sanitize')(column_expr)) }}
{% endmacro %}

{% macro default__sanitize__regexp_whitespace(column_expr) -%}
REGEXP_REPLACE({{ column_expr }}, '[ \t\r\n]+', ' ')
{%- endmacro %}

{% macro databricks__sanitize__regexp_whitespace(column_expr) -%}
REGEXP_REPLACE({{ column_expr }}, '[\\s]+', ' ')
{%- endmacro %}


{# ============================================================
   sanitize__date_trunc_day
   default : DATE_TRUNC('day', col)
   ============================================================ #}

{% macro sanitize__date_trunc_day(column_expr) %}
    {{ return(adapter.dispatch('sanitize__date_trunc_day', 'sanitize')(column_expr)) }}
{% endmacro %}

{% macro default__sanitize__date_trunc_day(column_expr) -%}
DATE_TRUNC('day', {{ column_expr }})
{%- endmacro %}


{# ============================================================
   sanitize__current_date
   default    : CURRENT_DATE    (ANSI SQL)
   databricks : CURRENT_DATE()
   ============================================================ #}

{% macro sanitize__current_date() %}
    {{ return(adapter.dispatch('sanitize__current_date', 'sanitize')()) }}
{% endmacro %}

{% macro default__sanitize__current_date() -%}
CURRENT_DATE
{%- endmacro %}

{% macro databricks__sanitize__current_date() -%}
CURRENT_DATE()
{%- endmacro %}


{# ============================================================
   sanitize__strip_special
   Databricks/Spark REGEXP_REPLACE replaces all occurrences by default.
   ============================================================ #}

{% macro sanitize__strip_special(column_expr) %}
    {{ return(adapter.dispatch('sanitize__strip_special', 'sanitize')(column_expr)) }}
{% endmacro %}

{% macro default__sanitize__strip_special(column_expr) -%}
REGEXP_REPLACE({{ column_expr }}, '[^A-Za-z0-9 ]', '')
{%- endmacro %}


{# ============================================================
   sanitize__normalize_phone
   Databricks/Spark REGEXP_REPLACE replaces all occurrences by default.
   ============================================================ #}

{% macro sanitize__normalize_phone(column_expr) %}
    {{ return(adapter.dispatch('sanitize__normalize_phone', 'sanitize')(column_expr)) }}
{% endmacro %}

{% macro default__sanitize__normalize_phone(column_expr) -%}
REGEXP_REPLACE({{ column_expr }}, '[^0-9]', '')
{%- endmacro %}


{# ============================================================
   sanitize__title
   Uses INITCAP — supported by Databricks and most ANSI engines.
   ============================================================ #}

{% macro sanitize__title(column_expr) %}
    {{ return(adapter.dispatch('sanitize__title', 'sanitize')(column_expr)) }}
{% endmacro %}

{% macro default__sanitize__title(column_expr) -%}
INITCAP({{ column_expr }})
{%- endmacro %}

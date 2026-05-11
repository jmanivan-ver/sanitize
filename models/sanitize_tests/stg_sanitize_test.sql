with source as (

    select * from {{ ref('raw_sanitize_test') }}

),

renamed as (

    select
        id,
        col_trim,
        col_normalize_whitespace,
        col_strip_special,
        col_upper,
        col_lower,
        col_title,
        col_nullif_empty,
        col_nullif_zero,
        col_nullif_negative,
        col_round_2,
        col_round_4,
        col_abs,
        col_date_floor,
        col_nullif_future,
        col_nullif_ancient,
        col_normalize_phone

    from source

),

sanitized as (
    {{ sanitize_columns('renamed', {
        'id': [],
        'col_trim':                 ['sanitize:trim'],
        'col_normalize_whitespace': ['sanitize:normalize_whitespace'],
        'col_strip_special':        ['sanitize:strip_special'],
        'col_upper':                ['sanitize:upper'],
        'col_lower':                ['sanitize:lower'],
        'col_title':                ['sanitize:title'],
        'col_nullif_empty':         ['sanitize:nullif_empty'],
        'col_nullif_zero':          ['sanitize:nullif_zero'],
        'col_nullif_negative':      ['sanitize:nullif_negative'],
        'col_round_2':              ['sanitize:round_2'],
        'col_round_4':              ['sanitize:round_4'],
        'col_abs':                  ['sanitize:abs'],
        'col_date_floor':           ['sanitize:date_floor'],
        'col_nullif_future':        ['sanitize:nullif_future'],
        'col_nullif_ancient':       ['sanitize:nullif_ancient'],
        'col_normalize_phone':      ['sanitize:normalize_phone']
    }) }}
)

select * from sanitized

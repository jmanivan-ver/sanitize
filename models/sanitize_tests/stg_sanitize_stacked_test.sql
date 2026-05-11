-- Test model for optimization strategy coverage.
-- Tags are deliberately declared in the WRONG priority order on every column
-- to prove that reorder_tags() corrects them before SQL is generated.
-- Also exercises 2-way and 3-way CASE merging and regex + simple tag nesting order.

with source as (

    select * from {{ ref('raw_sanitize_stacked_test') }}

),

renamed as (

    select
        id,
        col_priority_str,
        col_priority_chain,
        col_regex_chain,
        col_case_2_numeric,
        col_case_2_date,
        col_case_3_date
    from source

),

sanitized as (
    {{ sanitize_columns('renamed', {
        'id':                [],
        'col_priority_str':  ['sanitize:nullif_empty', 'sanitize:trim'],
        'col_priority_chain':['sanitize:nullif_empty', 'sanitize:upper', 'sanitize:trim'],
        'col_regex_chain':   ['sanitize:upper', 'sanitize:strip_special', 'sanitize:trim'],
        'col_case_2_numeric':['sanitize:nullif_zero', 'sanitize:nullif_negative'],
        'col_case_2_date':   ['sanitize:nullif_future', 'sanitize:nullif_ancient'],
        'col_case_3_date':   ['sanitize:date_floor', 'sanitize:nullif_future', 'sanitize:nullif_ancient']
    }) }}
)

select * from sanitized

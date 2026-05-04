with source as (
    select * from {{ source('portal', 'portal_guide_statistic_user_views_in_portal') }}
)

select * from source

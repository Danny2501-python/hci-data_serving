with source as (
    select * from {{ source('rpu_portal', 'portal_guide_statistic_user_views_in_portal') }}

)

select * from source

with source as (
    select * from {{ source('rpu_portal', 'portal_guide_core_portal_report') }}

)

select * from source

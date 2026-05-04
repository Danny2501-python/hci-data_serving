with source as (
    select * from {{ source('portal', 'portal_guide_core_portal_report') }}
)

select * from source

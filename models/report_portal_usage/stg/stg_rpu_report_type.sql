with source as (
    select * from {{ source('rpu_portal', 'portal_guide_core_report_type') }}

)

select * from source

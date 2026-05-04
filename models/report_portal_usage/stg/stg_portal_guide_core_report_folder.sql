with source as (
    select * from {{ source('portal', 'portal_guide_core_report_folder') }}
)

select * from source

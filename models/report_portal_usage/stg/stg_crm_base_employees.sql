with source as (
    select * from {{ source('crm_base', 'stag_employees') }}
)

select * from source

with source as (
    select * from {{ source('rpu_crm_base', 'stag_employees') }}


)

select * from source

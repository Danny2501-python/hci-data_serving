with source as (
    select * from {{ source('portal', 'portal_guide_core_employee') }}
)

select
    id,
    email,
    "name" as user_name

from source

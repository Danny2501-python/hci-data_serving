select
    user_id,
    employee,
    team,
    department
from {{ source('rtc_base', 'view_stag_employees_user') }}
where brand_etl = 8

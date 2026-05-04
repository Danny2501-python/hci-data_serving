with se as (
    select * from {{ ref('stg_resc_employees') }}
)
select 
    employee, 
    employee_code, 
    department,
    kn_user_id, 
    pr_user_id, 
    user_id as old_user_id
from se

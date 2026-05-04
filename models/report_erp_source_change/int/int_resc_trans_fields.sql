with v as (
    select * from {{ ref('stg_resc_trans_field') }}
),
se as (
    select * from {{ ref('int_resc_employees_matched') }}
)
select 
    v.id as crm_id, v.booking, v.old_data, v.new_data, 
    v.date_changed as stag_date_changed, v.brand_etl,
    se.employee as user_changed
from v
left join se on 
    (v.brand_etl = 1 and se.kn_user_id = v.write_uid) or 
    (v.brand_etl = 3 and se.pr_user_id = v.write_uid) or
    (v.brand_etl = 0 and se.old_user_id = v.write_uid)

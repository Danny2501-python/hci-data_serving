select 
        se.employee as nhan_vien,
        se.work_email,
        se.user_id,
        se.brand_etl
from {{source('kso_crm_base','view_stag_employees_user')}} se
where brand_etl =1
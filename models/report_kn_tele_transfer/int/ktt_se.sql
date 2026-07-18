select   se.employee,
        se.work_email,
        se.user_id,
        se.brand_etl
from {{source('data','view_stag_employees_user')}} se 
where brand_etl =1
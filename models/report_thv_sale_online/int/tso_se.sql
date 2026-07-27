/*select   se.employee,
        se.work_email,
        se.user_id,
        se.brand_etl
from {{source('thv','view_stag_employees_user')}} se 
where brand_etl =8*/

select se.name employee,
        se.work_email,
        se.user_id,
        se.brand_etl
from {{source('thv','hr_employee')}} se where brand_etl =8 
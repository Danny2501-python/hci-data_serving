--=========================
-- Bang hr employee Kangnam
--==============================
select MIN(id) as id, MIN(user_id) as user_id, employee_code 
from {{source('pre_tns','hr_employee')}} 
where brand_etl = 1 GROUP BY employee_code
--=========================
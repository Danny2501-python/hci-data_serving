select user_id,
		brand_etl,
		employee,
		department,
		department_id
from {{ source('raw_data', 'view_stag_employees_user') }} 

 
select *
from {{ source('stem_erp', 'hr_department_sector') }}

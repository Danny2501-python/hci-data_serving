select *
from {{ source('stem_erp', 'hr_group_job') }}

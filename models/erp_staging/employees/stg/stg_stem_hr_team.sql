select *
from {{ source('stem_erp', 'hr_team') }}

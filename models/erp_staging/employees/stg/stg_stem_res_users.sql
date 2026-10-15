select *
from {{ source('stem_erp', 'res_users') }}

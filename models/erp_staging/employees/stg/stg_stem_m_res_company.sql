select *
from {{ source('stem_erp', 'm_res_company') }}

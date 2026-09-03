select *
from {{ source('indvs_erp', 'res_brand') }}

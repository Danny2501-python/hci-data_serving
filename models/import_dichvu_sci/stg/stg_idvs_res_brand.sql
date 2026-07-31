select *
from {{ source('idvs_erp', 'res_brand') }}

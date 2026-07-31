select *
from {{ source('idvs_erp', 'product_template') }}

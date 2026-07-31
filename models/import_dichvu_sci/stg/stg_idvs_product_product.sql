select *
from {{ source('idvs_erp', 'product_product') }}

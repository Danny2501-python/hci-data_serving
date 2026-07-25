select *
from {{ source('stps_erp', 'product_product') }}

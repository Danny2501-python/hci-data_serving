select *
from {{ source('stps_erp', 'product_template') }}

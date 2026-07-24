select *
from {{ source('stps_erp', 'import_product_service_analyst') }}

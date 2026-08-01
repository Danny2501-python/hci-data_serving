select *
from {{ source('ibgs_erp', 'product_pricelist') }}

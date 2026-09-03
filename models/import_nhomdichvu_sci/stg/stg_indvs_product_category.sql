select *
from {{ source('indvs_erp', 'product_category') }}

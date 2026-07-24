select *
from {{ source('sptr_erp', 'crm_line_product') }}

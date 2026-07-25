select *
from {{ source('sptr_erp', 'crm_account_payment_product_detail') }}

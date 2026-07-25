select *
from {{ source('sptr_erp', 'crm_transfer_payment') }}

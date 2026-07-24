select *
from {{ source('sptr_erp', 'account_payment') }}

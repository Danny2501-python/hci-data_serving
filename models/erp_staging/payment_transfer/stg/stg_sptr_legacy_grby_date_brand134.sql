-- Tương tự stg_sptr_legacy_brand134 nhưng cho stag_payment_transfer_grby_date.
select *
from {{ source('sptr_legacy', 'stag_payment_transfer_grby_date') }}
where brand_etl in (1, 3, 4)

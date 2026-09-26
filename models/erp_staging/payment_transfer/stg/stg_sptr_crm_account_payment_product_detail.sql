-- Lọc is_delete=true — xem chú thích đầy đủ ở stg_sptr_crm_account_payment_detail.sql (cùng lỗi,
-- cùng cách xử lý).
select *
from {{ source('sptr_erp', 'crm_account_payment_product_detail') }}
where coalesce(is_delete, false) = false

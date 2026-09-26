-- Lọc is_delete=true — xem chú thích đầy đủ ở stg_sptr_crm_account_payment_detail.sql (cùng lỗi,
-- cùng cách xử lý). Chỉ lọc is_delete ở DÒNG điều chuyển (bảng này) — is_delete ở bảng HEADER
-- crm_transfer_payment CHƯA xử lý (ctp chỉ được left join lấy thêm thông tin ma_phieu/payment_date
-- trong int_sptr_transfer_base.sql, không quyết định dòng nào bị loại) — nếu phát hiện lệch do
-- header bị xoá mà dòng con không đánh dấu, cần xử lý riêng.
select *
from {{ source('sptr_erp', 'crm_transfer_payment_line') }}
where coalesce(is_delete, false) = false

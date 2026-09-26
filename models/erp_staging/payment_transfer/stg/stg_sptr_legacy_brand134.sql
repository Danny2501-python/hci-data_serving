-- Toàn bộ phần brand 1/3/4 (kn/pr/hh) của bảng đích thật. KHÔNG đóng băng như brand_etl=0 -- phần
-- crm_id có giao dịch gần đây (int_sptr_recent_crm_scope) sẽ được tính lại từ ERP nguồn; phần còn lại
-- (crm_id "nguội") lấy nguyên từ đây làm phần tiếp nối lịch sử -- xem LOGIC.md mục "Phạm vi tính lại".
-- KHÔNG lọc snapshot_date như products/employees: đã xác nhận (id, brand_etl) là khoá duy nhất, không
-- lịch sử hoá.
-- (2026-09-26) Đọc qua stg_sptr_legacy_all (bảng hiện tại + bồi từ backup đóng băng
-- stag_payment_transfer_backup_20260926 khi bảng hiện tại mất dữ liệu) thay vì đọc thẳng source.
select *
from {{ ref('stg_sptr_legacy_all') }}
where brand_etl in (1, 3, 4)

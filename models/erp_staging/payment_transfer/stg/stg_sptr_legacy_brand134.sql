-- Toàn bộ phần brand 1/3/4 (kn/pr/hh) của bảng đích thật. KHÔNG đóng băng như brand_etl=0 -- phần
-- crm_id có giao dịch gần đây (int_sptr_recent_crm_scope) sẽ được tính lại từ ERP nguồn; phần còn lại
-- (crm_id "nguội") lấy nguyên từ đây làm phần tiếp nối lịch sử -- xem LOGIC.md mục "Phạm vi tính lại".
-- KHÔNG lọc snapshot_date như products/employees: đã xác nhận (id, brand_etl) là khoá duy nhất, không
-- lịch sử hoá.
select *
from {{ source('sptr_legacy', 'stag_payment_transfer') }}
where brand_etl in (1, 3, 4)

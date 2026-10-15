-- Phần dữ liệu hệ thống cũ (brand_etl = 0) trong bảng stag_payment_transfer thật — đóng băng, không có
-- ETL nào tái tạo được. Xem sources.yml.
-- (2026-09-26) Đọc qua stg_sptr_legacy_all (bảng hiện tại + bồi từ backup đóng băng
-- stag_payment_transfer_backup_20260926 khi bảng hiện tại mất dữ liệu) thay vì đọc thẳng source.
select *
from {{ ref('stg_sptr_legacy_all') }}
where brand_etl = 0

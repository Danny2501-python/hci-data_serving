-- Phần dữ liệu hệ thống cũ (brand_etl = 0) trong bảng stag_payment_transfer_grby_date thật — đóng băng,
-- không có ETL nào tái tạo được. Xem sources.yml.
select *
from {{ source('sptr_legacy', 'stag_payment_transfer_grby_date') }}
where brand_etl = 0

-- Tương đương write_temp_crm_id_update(): các crm_id (brand 1/3/4) có phát sinh/cập nhật giao dịch
-- trong khoảng gần đây -- CHỈ những crm_id này mới được tính lại từ ERP nguồn; phần còn lại lấy từ bảng
-- đích thật (xem stg_sptr_legacy_brand134). Bắt buộc phải giữ đúng phạm vi này: nguồn ERP chi tiết
-- (crm_account_payment_detail...) chỉ còn lưu ~2 tháng gần nhất, không phải kho lưu trữ đầy đủ -- xem
-- knowledge.md.
with crm_limit as (
    select crm_id, payment_date, brand_etl
    from {{ ref('stg_sptr_account_payment') }}
    where greatest(payment_date, write_date) >= greatest(date_trunc('month', current_date - interval '1 month')::date, date '2025-12-01')
    union all
    select crm_id, payment_date, brand_etl
    from {{ ref('stg_sptr_crm_transfer_payment') }}
    where greatest(payment_date, write_date) >= greatest(date_trunc('month', current_date - interval '1 month')::date, date '2025-12-01')
)
select crm_id, max(payment_date) as payment_date, brand_etl
from crm_limit
where coalesce(crm_id, 0) <> 0 and brand_etl in (1, 2, 3, 4)
group by crm_id, brand_etl

-- Tương đương fix_product_id trong quentk_1_stag_crm_New_sys.py: quét TOÀN BỘ bảng đích thật (mọi
-- brand) lấy các dòng gần đây để tra cứu product_id "tốt nhất đã biết" theo (clineid, brand_id), dùng
-- vá lại các dòng mới tính ra product_id = 0/NULL. Giờ đọc trực tiếp từ bảng thật (đã coi là nguồn hợp
-- lệ cho phần "nguội") thay vì tự vá trong tập vừa tính như draft đầu tiên.
select clineid, brand_id, max(product_id) as product_id
from (
    select clineid, brand_id, product_id, payment_date, write_date from {{ ref('stg_sptr_legacy_brand0') }}
    union all
    select clineid, brand_id, product_id, payment_date, write_date from {{ ref('stg_sptr_legacy_brand134') }}
) x
where greatest(payment_date, write_date::date) >= greatest(date_trunc('month', current_date - interval '1 month')::date, date '2025-12-01')
group by clineid, brand_id

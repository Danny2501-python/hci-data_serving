-- Khách hàng đến cửa / thành công — theo ĐÚNG logic hiện có trong workbook "KANGNAM - BỘ CHỈ SỐ
-- KINH DOANH - 2025.twbx" (cặp field KHÔNG giới hạn kênh MD: cd_customer_come/cd_customer_come_
-- deposit — KHÁC với ô "(MD)" hiển thị trên dashboard, 2 khái niệm khác nhau, user đã xác nhận so
-- sánh đúng là với cặp không-MD) — xem LOGIC.md mục 4f, lịch sử trao đổi 2026-09-15.
-- Nguồn report_crm_lead_customer_out_sold — bảng ngoài dbt, job Python/Airflow tạo (xem
-- quentk_3_report_crm_lead_customer_out_sold_New_sys.py). ⚠ ÁP DỤNG CHO KANGNAM/PARIS (brand_etl
-- 1/3) — Hồng Hà/Tiêu Hóa Việt CHƯA có logic tương ứng (dù bảng nguồn giờ đã có đủ dữ liệu THV,
-- brand_etl=8, sau khi backfill).
--
-- (2026-09-15) brand_etl của bảng gốc đã được backfill/đồng bộ lại ĐÚNG — đã đối chiếu new_product
-- khớp 100% với sandbox (cùng tổng dòng, cùng phân bố brand_etl, cùng số liệu theo tháng). Dùng
-- THẲNG brand_etl, KHÔNG cần suy ra từ report_brand (text) như bản trước nữa.
--
-- Định nghĩa (đúng theo Custom SQL + calculated field gốc trong workbook Kangnam — đã bỏ hoàn toàn
-- logic CBNV/Đối ngoại/TPM/bảo hành/no_kpi/amount_paid tự đặt ra trước đó, xem lịch sử trao đổi
-- 2026-09-15):
--   Dedupe: 1 dòng/(crm_id, brand_etl), lấy dòng có total_received cao nhất (hoà thì lấy clineid lớn
--     nhất) — giống hệt `DISTINCT ON (crm_id, brand_etl) ORDER BY ... COALESCE(total_received,0) DESC,
--     clineid` trong Custom SQL gốc của workbook.
--   "Đến cửa" = customer_come = 'yes' OR (customer_come IS NULL AND arrival_date IS NOT NULL).
--   "Thành công" = "Đến cửa" + type_customer_arrived IN ('deposit','outsold_return','success',
--     'success_return') — ĐÚNG tập "Set_success" của workbook (CÓ tính cả 'deposit').
--   Thời gian: dùng report_date (KHÔNG phải arrival_date như bản trước) — đúng theo cách workbook
--     gốc group theo tháng.
-- Đã đối chiếu số liệu ra khớp với workbook trước khi chốt (Kangnam T8/2026: 4.313 đến cửa/3.187
-- thành công) — xem lịch sử trao đổi 2026-09-15.

{{ config(materialized='table') }}

with dedup as (
    select distinct on (crm_id, brand_etl)
        crm_id,
        brand_etl,
        report_company as chi_nhanh,
        report_date,
        arrival_date,
        customer_come,
        type_customer_arrived,
        total_received,
        clineid
    from {{ ref('stg_rtds_report_crm_lead_customer_out_sold') }}
    where brand_etl in (1, 3)
    order by crm_id, brand_etl, coalesce(total_received, 0) desc, clineid
)
select
    crm_id,
    case brand_etl when 1 then 'Kangnam' when 3 then 'Paris' end as brand,
    chi_nhanh,
    extract(year from report_date)::int as nam,
    extract(month from report_date)::int as thang,
    (type_customer_arrived in ('deposit', 'outsold_return', 'success', 'success_return')) as da_thanh_cong
from dedup
where report_date is not null
  and (customer_come = 'yes' or (customer_come is null and arrival_date is not null))

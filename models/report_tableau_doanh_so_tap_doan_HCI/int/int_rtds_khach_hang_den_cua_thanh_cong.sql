-- Khách hàng đến cửa / thành công — theo ĐÚNG logic hiện có trong workbook "KANGNAM - BỘ CHỈ SỐ
-- KINH DOANH - 2025.twbx" (cặp field KHÔNG giới hạn kênh MD: cd_customer_come/cd_customer_come_
-- deposit — KHÁC với ô "(MD)" hiển thị trên dashboard, 2 khái niệm khác nhau, user đã xác nhận so
-- sánh đúng là với cặp không-MD) — xem LOGIC.md mục 4f, lịch sử trao đổi 2026-09-15.
-- Nguồn report_crm_lead_customer_out_sold — bảng ngoài dbt, job Python/Airflow tạo (xem
-- quentk_3_report_crm_lead_customer_out_sold_New_sys.py). ⚠ CHỈ ÁP DỤNG CHO KANGNAM/PARIS (brand
-- 1/3). Hồng Hà/Tiêu Hóa Việt dùng bảng gốc khác — xem int_rtds_khach_hang_den_cua_thanh_cong_hh_
-- thv.sql (Custom SQL gốc của workbook Kangnam vốn chỉ dựng cho Kangnam/Paris nên chỉ giữ 2 brand
-- này ở đây; nếu sau này cần Hồng Hà từ chính bảng này, sẽ làm thêm giống mẫu bên dưới).
--
-- ⚠⚠ (2026-09-15) PHÁT HIỆN — bảng này CŨNG có lỗ hổng dữ liệu giống crm_lead: brand_etl chỉ đáng
-- tin cho dữ liệu TỪ ~T8/2025 trở đi (đã backfill/đồng bộ đúng, khớp 100% với sandbox). Dữ liệu
-- TRƯỚC đó vẫn nằm ở `brand_etl=0` (2.692.618 dòng, `report_date` giảm mạnh đúng từ T8/2025 —
-- KHÔNG PHẢI lỗi backfill, mà do chính hệ thống nguồn chưa gắn brand cho giai đoạn đó). Bảng này có
-- sẵn cột `brand_id` (KHÁC `brand_etl`) đối chiếu khớp gần tuyệt đối với `brand_etl` đã đúng
-- (brand_etl=1↔brand_id=1: 249.813/249.816; brand_etl=3↔brand_id=3: khớp 100%) — dùng `brand_id` để
-- nhận diện đúng brand cho phần dữ liệu cũ (`brand_etl=0`) này. User chốt quy tắc (2026-09-15):
-- **TRƯỚC ~T8/2025 dùng `brand_id`, TỪ ~T8/2025 dùng `brand_etl`** — thực hiện bằng điều kiện
-- `(brand_etl = 0 AND brand_id IN (1,3)) OR brand_etl IN (1,3)` (tự nhiên bám theo trạng thái gắn
-- brand thật của dữ liệu, không hard-code 1 mốc ngày cụ thể — nếu có vài dòng lẻ tẻ SAU T8/2025 vẫn
-- chưa kịp gắn brand_etl thì vẫn được `brand_id` "vớt" đúng, không bỏ sót).
-- ⚠ DEDUPE: đổi từ `DISTINCT ON (crm_id, brand_etl)` sang `DISTINCT ON (crm_id, brand_etl, brand_id)`
-- — BẮT BUỘC, vì mọi dòng "cũ" (brand_etl=0) của CẢ Kangnam LẪN Paris đều dùng chung giá trị
-- `brand_etl=0`, nếu chỉ dedupe theo `(crm_id, brand_etl)` sẽ TRỘN LẪN 2 booking khác brand nhưng
-- trùng số `crm_id` (do id có thể trùng chéo giữa các brand, đã xác minh nhiều lần trong dự án này)
-- thành 1 dòng — mất dữ liệu/sai brand. Thêm `brand_id` vào khoá dedupe tách đúng 2 nhánh
-- (crm_id,0,1)=Kangnam cũ, (crm_id,0,3)=Paris cũ, (crm_id,1,1)=Kangnam mới, (crm_id,3,3)=Paris mới.
-- `brand` output lấy từ `brand_id` (đáng tin ở CẢ 2 giai đoạn), không dùng `brand_etl` nữa (=0 ở giai
-- đoạn cũ, không map được sang tên brand).
-- Thử tính lại Kangnam T1-T7/2025 bằng brand_id: 2.221/2.904/3.113/3.021/3.040/3.646/4.197 khách đến
-- cửa/tháng — cao hơn hẳn và hợp lý hơn nhiều so với số cũ (143-1.003) — xem lịch sử trao đổi
-- 2026-09-15.
--
-- Định nghĩa (đúng theo Custom SQL + calculated field gốc trong workbook Kangnam — đã bỏ hoàn toàn
-- logic CBNV/Đối ngoại/TPM/bảo hành/no_kpi/amount_paid tự đặt ra ban đầu, xem lịch sử trao đổi
-- 2026-09-15):
--   "Đến cửa" = customer_come = 'yes' OR (customer_come IS NULL AND arrival_date IS NOT NULL).
--   "Thành công" = "Đến cửa" + type_customer_arrived IN ('deposit','outsold_return','success',
--     'success_return') — ĐÚNG tập "Set_success" của workbook (CÓ tính cả 'deposit').
--   Thời gian: dùng report_date (KHÔNG phải arrival_date) — đúng theo cách workbook gốc group theo
--     tháng.
-- Đã đối chiếu số liệu ra khớp với workbook trước khi chốt (Kangnam T8/2026: 4.313 đến cửa/3.187
-- thành công) — xem lịch sử trao đổi 2026-09-15.

{{ config(materialized='table') }}

with dedup as (
    select distinct on (crm_id, brand_etl, brand_id)
        crm_id,
        brand_etl,
        brand_id,
        report_company as chi_nhanh,
        report_date,
        arrival_date,
        customer_come,
        type_customer_arrived,
        total_received,
        clineid,
        source_id,
        category_source_id,
        source
    from {{ ref('stg_rtds_report_crm_lead_customer_out_sold') }}
    where (brand_etl = 0 and brand_id in (1, 3))
       or brand_etl in (1, 3)
    order by crm_id, brand_etl, brand_id, coalesce(total_received, 0) desc, clineid
)
select
    crm_id,
    -- (2026-09-26) brand_etl 1/3 (giai đoạn mới) → lấy theo brand_etl; chỉ dữ liệu cũ brand_etl=0 mới
    -- dựa vào brand_id. Trước đây dùng thẳng brand_id → 3 dòng brand_etl=1 có brand_id NULL (2024-05-02)
    -- ra brand NULL, sinh 1 dòng "brand NULL" trong report_rtds_doanh_so_target_thang_tableau.
    case coalesce(nullif(brand_etl, 0), brand_id) when 1 then 'Kangnam' when 3 then 'Paris' end as brand,
    chi_nhanh,
    extract(year from report_date)::int as nam,
    extract(month from report_date)::int as thang,
    (type_customer_arrived in ('deposit', 'outsold_return', 'success', 'success_return')) as da_thanh_cong,
    -- (2026-09-26) MD/ML đúng quy tắc workbook "Bộ chỉ số kinh doanh" (cùng cột source_id /
    -- category_source_id / source workbook đọc từ bảng out_sold) — biến thể KHÁCH HÀNG rtds_nhom_md_ml_khach (cờ is_source_md), macros/rtds_nhom_md_ml.sql.
    {{ rtds_nhom_md_ml_khach('source_id', 'category_source_id', 'source') }} as nhom_md_ml
from dedup
where report_date is not null
  and (customer_come = 'yes' or (customer_come is null and arrival_date is not null))

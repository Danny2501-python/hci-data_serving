-- Khách hàng đến cửa / thành công — Hồng Hà (brand_etl=4) và Tiêu Hóa Việt (brand_etl=8), lấy TRỰC
-- TIẾP từ bảng gốc (crm_lead/crm_line/stag_products/m_res_company/stag_sources), KHÔNG dùng
-- report_crm_lead_customer_out_sold như Kangnam/Paris (xem int_rtds_khach_hang_den_cua_thanh_cong.sql)
-- vì bảng đó CỐ Ý loại `brand_etl NOT IN (0, 4)` ngay trong ETL gốc
-- (quentk_3_report_crm_lead_customer_out_sold_New_sys.py, dòng `WHERE ... AND cl.brand_etl NOT IN
-- (0, 4)`) — Hồng Hà (brand_etl=4 thật) KHÔNG BAO GIỜ xuất hiện trong bảng report đó. Đây KHÔNG PHẢI
-- lỗi đồng bộ như tưởng ban đầu (xem điều tra 2026-09-15 trong LOGIC.md mục 4f) mà là do chính script
-- gốc chủ động loại trừ — nên phải quay lại bảng gốc cho 2 thương hiệu này.
--
-- Định nghĩa (user chốt 2026-09-15 — giống hệt logic ban đầu áp dụng cho Kangnam/Paris trước khi đổi
-- sang logic workbook Kangnam, nay áp dụng lại cho Hồng Hà/THV):
--   "Đến cửa" = crm_lead.customer_come = 'yes'
--     VÀ nguồn KHÔNG phải CBNV/Đối ngoại/Thuê phòng mổ — match theo TÊN nguồn qua stag_sources
--       (KHÔNG dùng lại danh sách source_id `kpi_exclude_source_ids_*` trong dbt_project.yml — danh
--       sách đó copy riêng từ sheet GB_result của Kangnam, không có gì đảm bảo đúng cho Hồng Hà/THV).
--     VÀ type_crm_id <> 3 (loại khách hàng bảo hành) — data check: brand_etl 4/8 hiện chỉ có
--       type_crm_id IN (2,14), không có giá trị 3 nào (điều kiện này hiện là no-op, giữ lại cho đúng
--       công thức và phòng khi phát sinh dữ liệu type_crm_id=3 sau này).
--     VÀ KHÔNG PHẢI toàn bộ line dịch vụ (crm_line) đều is_no_kpi (join view_stag_products theo
--       product_id + brand_etl). crm_line_product: đã kiểm tra brand_etl=4/8 có 0 dòng — KHÔNG dùng.
--   "Thành công" = "Đến cửa" + crm_lead.amount_paid > 0.
--   Thời gian: dùng arrival_date (KHÔNG dùng report_date/booking_date).
--   Chi nhánh: m_res_company.name, join (company_id, brand_etl) — company_id có thể trùng tên KHÁC
--     NHAU tuỳ brand_etl (VD id=57: 'TRUNG TÂM NỘI SOI DR GIANG' ở brand_etl=4 nhưng 'Phòng Khám Tiêu
--     Hóa Việt' ở brand_etl=8) — PHẢI join kèm brand_etl, không chỉ company_id.
-- Data check trước khi chốt (2026-09-15): customer_come='yes' Hồng Hà 13.488 dòng/THV 15.745 dòng,
-- amount_paid>0 trong số đó Hồng Hà ~78,6%/THV ~69,4% — hợp lý.
--
-- ⚠⚠⚠ LỌC RÁC CLONE (phát hiện + user xác nhận 2026-09-15, sau khi build thử số liệu 2025 cho
-- dashboard mới thấy Hồng Hà/THV trùng số y hệt nhau ở 2024/2025) — hệ thống `brand_etl=8` (THV)
-- được **CLONE TỪ `brand_etl=4` (Hồng Hà)**, nên mang theo toàn bộ dữ liệu cũ của BV Hồng Hà, gây
-- đếm trùng (4.968 crm_id xuất hiện ở cả 2 brand; "khách đến cửa" 2024=7/7, 2025=3.780/3.780 trùng
-- khít giữa 2 brand). Bằng chứng xác định ngày clone = **2026-01-13**:
--   - company_id=24 (BV HỒNG HÀ) trong brand_etl=8: 6.794 dòng, arrival_date 2023-02-18 → 2026-01-08
--     (dừng NGAY TRƯỚC ngày clone) → rác clone.
--   - company_id NULL trong brand_etl=8: 3.044 dòng, arrival_date TOÀN BỘ = 2026-01-13 (đúng 1 ngày,
--     chính là ngày clone), 3.036/3.044 có bản sao ở brand_etl=4 → rác clone.
--   - company_id=32 (BV HỒNG HÀ HCM): 83 dòng, → 2025-07-12 → rác clone.
--   - company_id=57 (PHÒNG KHÁM TIÊU HÓA VIỆT): 5.824 dòng, arrival_date 2026-01-15 → hiện tại (bắt
--     đầu NGAY SAU ngày clone) → DỮ LIỆU THV THẬT, giữ lại.
-- ⇒ Quy tắc: `brand_etl=4` lấy TOÀN BỘ (Hồng Hà); `brand_etl=8` CHỈ lấy `company_id = 57`. Cố ý
-- hard-code 57 (không đưa thành var) — đây là master-data ổn định định nghĩa "THV là gì", để ngay
-- cạnh phần giải thích cho dễ đọc/audit. Lưu ý 57 ở brand_etl=4 là 'TRUNG TÂM NỘI SOI DR GIANG'
-- (thuộc Hồng Hà) — KHÔNG ảnh hưởng vì nhánh brand_etl=4 lấy hết, không lọc theo company_id.
-- Hệ quả: giải thích luôn bất thường "THV T1/2026 tỷ lệ thành công chỉ ~10,5%" ghi nhận trước đó —
-- do lẫn 3.044 dòng rác clone (amount_paid=0) vào T1/2026; lọc xong tự hết.

{{ config(materialized='table') }}

with base as (
    select
        cl.id as crm_id,
        cl.brand_etl,
        cl.company_id,
        cl.customer_come,
        cl.arrival_date,
        cl.type_crm_id,
        cl.amount_paid,
        cl.source_id
    from {{ ref('stg_rtds_crm_lead') }} cl
    where cl.brand_etl in (4, 8)
      and cl.type = 'opportunity'
      and cl.active
      and (cl.brand_etl = 4 or cl.company_id = 57)
),

products as (
    select crm_id, brand_etl, product_id
    from {{ ref('stg_rtds_crm_line') }}
    where brand_etl in (4, 8)
),

no_kpi_agg as (
    select
        p.crm_id,
        p.brand_etl,
        bool_and(coalesce(vsp.is_no_kpi, false)) as toan_bo_no_kpi
    from products p
    left join {{ ref('stg_rtds_view_stag_products') }} vsp
        on vsp.product_id = p.product_id and vsp.brand_etl = p.brand_etl
    group by 1, 2
),

source_flag as (
    select
        b.crm_id,
        b.brand_etl,
        (
            coalesce(ss.source ilike '%cbnv%', false)
            or coalesce(ss.source ilike '%đối ngoại%', false)
            or coalesce(ss.source ilike '%thuê phòng mổ%', false)
            or coalesce(ss.source ilike '%tpm%', false)
        ) as nguon_bi_loai
    from base b
    left join {{ ref('stg_rtds_stag_sources') }} ss on ss.old_id = b.source_id
)

select
    b.crm_id,
    case b.brand_etl when 4 then 'Hồng Hà' when 8 then 'Tiêu Hóa Việt' end as brand,
    mrc.name as chi_nhanh,
    extract(year from b.arrival_date)::int as nam,
    extract(month from b.arrival_date)::int as thang,
    (b.amount_paid > 0) as da_thanh_cong
from base b
left join {{ ref('stg_rtds_m_res_company') }} mrc
    on mrc.id = b.company_id and mrc.brand_etl = b.brand_etl
left join no_kpi_agg nk on nk.crm_id = b.crm_id and nk.brand_etl = b.brand_etl
left join source_flag sf on sf.crm_id = b.crm_id and sf.brand_etl = b.brand_etl
where b.customer_come = 'yes'
  and b.arrival_date is not null
  and b.type_crm_id <> 3
  and not coalesce(sf.nguon_bi_loai, false)
  and not coalesce(nk.toan_bo_no_kpi, false)

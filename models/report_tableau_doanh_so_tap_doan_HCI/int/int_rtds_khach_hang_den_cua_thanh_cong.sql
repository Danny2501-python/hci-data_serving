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

-- ⚠⚠ (2026-10-01) LỖI "CHI NHÁNH KHÁC THƯƠNG HIỆU" — ĐÃ FIX (user chốt).
-- Triệu chứng: report_rtds_doanh_so_target_thang_tableau có dòng brand = 'Kangnam' nhưng chi_nhanh là
-- chi nhánh Paris ('BỆNH VIỆN RĂNG HÀM MẶT THẨM MỸ PARIS', 'NHA KHOA PARIS …'), doanh số + target NULL.
-- Nguyên nhân: `chi_nhanh` = report_company = chi nhánh ĐẾN CỬA, đi CẶP với `report_brand_id`
-- (= field thuonghieuphanquyen/chinhanhphanquyen của workbook KANGNAM, xem
-- quentk_3_report_crm_lead_customer_out_sold_New_sys.py: report_* = arrival_* từ
-- stag_crm_booking_arrival_company, fallback về chi nhánh hẹn lịch). Trước đây `brand` lại lấy từ
-- brand_etl/brand_id = thương hiệu của BOOKING → ghép lệch trục. Đo trên DB (2026-10-01):
--   brand_etl=0, brand_id=1, report_brand_id=3 → 2.381 dòng / 864 booking (2021-11 → 2024-08)
--   brand_etl=0, brand_id=3, report_brand_id=1 →    40 dòng /   8 booking (2022-02 → 2025-03)
--   brand_etl=1, cả brand_id lẫn report_brand_id NULL → 3 dòng (2024-05-02)
-- Toàn bộ nằm ở khúc dữ liệu cũ brand_etl=0; 2025-2026 không bị ảnh hưởng. Các cặp chi nhánh đều
-- CÙNG ĐỊA BÀN (KANGNAM 84 ↔ BV RHM TM PARIS, KANGNAM ĐÀ NẴNG ↔ PARIS ĐÀ NẴNG, KANGNAM NGHỆ AN ↔
-- PARIS VINH …) — khách đến cửa ở cơ sở của thương hiệu kia.
-- FIX: `brand_key` lấy report_brand_id TRƯỚC (đúng cặp với chi nhánh), fallback brand_etl/brand_id khi
-- NULL. Dùng CHUNG cho brand + hậu tố ma_khach + join m_res_company gộp chi nhánh (phải cùng 1 trục,
-- nếu để ma_khach theo brand_id cũ thì 1 khách sẽ bị đếm thành 2 trong cùng brand).
-- report_brand_id chỉ nhận giá trị 1 / 3 / NULL trong tập dữ liệu này (đã kiểm) → không sinh brand NULL.
--
-- ⚠ CHƯA FIX (user chốt 2026-10-01 chỉ ghi nhận, chưa sửa) — "TÊN CHI NHÁNH ĐÓNG BĂNG": `chi_nhanh` lấy
-- TEXT THÔ report_company (snapshot lúc ETL), không tra m_res_company.name theo report_company_id như
-- nhánh doanh số/target → cùng 1 chi nhánh bị TÁCH LÀM 2 DÒNG khi chi nhánh đổi tên:
--   company 20 (Paris): 'NHA KHOA PARIS NGUYỄN THÁI HỌC' (text cũ, 5.351 khách đến cửa 2021-2025)
--                    vs 'NHA KHOA PARIS NGUYỄN T.M KHAI' (tên hiện tại, dùng ở doanh số/target)
--   company 40 (Kangnam): 'VIỆN THẨM MỸ KANGNAM THÁI NGUYÊN' (598 khách) vs 'CTCP KANGNAM BEAUTY & HEALTH'
-- 2026 không lệch (text nguồn đã cập nhật). Cách sửa khi được phép: chi_nhanh = coalesce(mrc_gop.name,
-- report_company) — join mrc_gop đã có sẵn ngay bên dưới, chỉ cần đổi biểu thức chi_nhanh.

{{ config(materialized='table') }}

{# (2026-10-01) Trục thương hiệu DUY NHẤT của model — xem khối ⚠⚠ phía trên. #}
{% set brand_key = 'coalesce(d.report_brand_id, nullif(d.brand_etl, 0), d.brand_id)' %}

-- (2026-09-28) User chốt: khách chỉ mua sản phẩm tách riêng nhóm 'SP' — KHÔNG nằm trong MD/ML (tổng
-- KHĐC/KHTC giữ nguyên = MD + ML + SP, cách đếm ở report_rtds_khach_hang_den_cua_thanh_cong). Bảng out_sold có 1 dòng / crm_line (dịch vụ); booking KHÔNG có crm_line thì lấy
-- 1 dòng crm_line_product đầu tiên (product_category 'SAN PHAM', channel_code KH099) → booking "chỉ sản
-- phẩm" = MỌI dòng của booking đều product_category = 'SAN PHAM' (tính trên toàn bộ dòng, TRƯỚC dedupe).
-- Booking chỉ sản phẩm → nhom_md_ml = 'SP'.
with booking_chi_san_pham as (
    select
        crm_id,
        brand_etl,
        brand_id,
        bool_and(coalesce(product_category, '') = 'SAN PHAM') as chi_san_pham
    from {{ ref('stg_rtds_report_crm_lead_customer_out_sold') }}
    where (brand_etl = 0 and brand_id in (1, 3))
       or brand_etl in (1, 3)
    group by 1, 2, 3
),

dedup as (
    select distinct on (crm_id, brand_etl, brand_id)
        crm_id,
        brand_etl,
        brand_id,
        -- (2026-10-01) report_brand_id = thương hiệu của CHI NHÁNH ĐẾN CỬA (field thuonghieuphanquyen
        -- của workbook KANGNAM) — đi CẶP với report_company_id/report_company. Xem comment "Lỗi chi
        -- nhánh khác thương hiệu" ở đầu file.
        report_brand_id,
        report_company as chi_nhanh,
        report_company_id,
        report_date,
        arrival_date,
        customer_come,
        type_customer_arrived,
        total_received,
        clineid,
        source_id,
        category_source_id,
        source,
        code_customer,
        partner_id
    from {{ ref('stg_rtds_report_crm_lead_customer_out_sold') }}
    where (brand_etl = 0 and brand_id in (1, 3))
       or brand_etl in (1, 3)
    order by crm_id, brand_etl, brand_id, coalesce(total_received, 0) desc, clineid
)
select
    d.crm_id,
    -- (2026-09-26) brand_etl 1/3 (giai đoạn mới) → lấy theo brand_etl; chỉ dữ liệu cũ brand_etl=0 mới
    -- dựa vào brand_id. Trước đây dùng thẳng brand_id → 3 dòng brand_etl=1 có brand_id NULL (2024-05-02)
    -- ra brand NULL, sinh 1 dòng "brand NULL" trong report_rtds_doanh_so_target_thang_tableau.
    case {{ brand_key }} when 1 then 'Kangnam' when 3 then 'Paris' end as brand,
    -- (2026-09-29) Gộp chi nhánh theo var rtds_gop_chi_nhanh (BV Thẩm mỹ KN 12 → KN Sài Gòn 4 từ 01/08/2026)
    case
        when mrc_gop.id is not null and mrc_gop.id is distinct from d.report_company_id then mrc_gop.name
        else d.chi_nhanh
    end as chi_nhanh,
    extract(year from d.report_date)::int as nam,
    extract(month from d.report_date)::int as thang,
    (d.type_customer_arrived in ('deposit', 'outsold_return', 'success', 'success_return')) as da_thanh_cong,
    -- (2026-09-26) MD/ML đúng quy tắc workbook "Bộ chỉ số kinh doanh" (cùng cột source_id /
    -- category_source_id / source workbook đọc từ bảng out_sold) — biến thể KHÁCH HÀNG rtds_nhom_md_ml_khach (cờ is_source_md), macros/rtds_nhom_md_ml.sql.
    -- (2026-09-28) booking chỉ sản phẩm → SP (xem đầu CTE booking_chi_san_pham).
    case
        when b.chi_san_pham then 'SP'
        else {{ rtds_nhom_md_ml_khach('d.source_id', 'd.category_source_id', 'd.source') }}
    end as nhom_md_ml,
    b.chi_san_pham,
    -- (2026-09-27) Mã khách để đếm theo KHÁCH HÀNG (user chốt, khớp workbook: COUNTD(code_customer + '_' +
    -- brand_id)). Thiếu code_customer → partner_id → crm_id (không bỏ mất booking).
    coalesce(nullif(d.code_customer, ''), 'p' || d.partner_id::text, 'crm' || d.crm_id::text)
        || '_' || ({{ brand_key }})::text as ma_khach,
    -- (2026-10-13, user chốt) Nguồn của booking — tên GỐC theo stag_sources (giống int_rtds_kangnam/paris:
    -- nguon = source, nhom_nguon_khach = newcat_source), không ánh xạ chéo brand. Dùng cho khách theo nguồn ở
    -- report_rtds_doanh_so_thang (khách nhiều booking khác nguồn trong tháng được đếm ở MỌI nguồn).
    d.source_id::int as source_id,
    ss.source as nguon,
    ss.newcat_source as nhom_nguon_khach
from dedup d
left join {{ ref('stg_rtds_stag_sources') }} ss on ss.old_id = d.source_id
left join {{ ref('stg_rtds_m_res_company') }} mrc_gop
    on mrc_gop.id = {{ rtds_company_id_gop('d.report_company_id', 'd.report_date', brand_key) }}
   and mrc_gop.brand_etl = {{ brand_key }}
left join booking_chi_san_pham b
    on b.crm_id = d.crm_id and b.brand_etl = d.brand_etl and b.brand_id is not distinct from d.brand_id
where d.report_date is not null
  and (d.customer_come = 'yes' or (d.customer_come is null and d.arrival_date is not null))

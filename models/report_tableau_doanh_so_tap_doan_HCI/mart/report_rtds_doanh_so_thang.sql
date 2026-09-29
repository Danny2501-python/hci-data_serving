-- Bảng tổng hợp THEO THÁNG cho tab "Doanh số" — dùng làm nguồn kéo lên Tableau cho nhẹ (group by
-- trước, không phải transaction-level như report_rtds_doanh_so — 374K dòng). Cần xem chi tiết từng
-- giao dịch/khách hàng thì quay lại report_rtds_doanh_so.
--
-- Grain: 1 dòng = 1 brand + năm + tháng + nguồn hệ thống (CRM/EHC) + chi nhánh + nhóm dịch vụ +
-- nguồn + nhóm nguồn khách. Vẫn khớp brand+nam+thang để join bảng kế hoạch (target) ở Tableau
-- (target chỉ có grain brand+nam+thang, group thêm chiều khác ở đây không ảnh hưởng join đó).
--
-- tong_so_tien = sum(so_tien), tự động bỏ qua các dòng so_tien NULL (phiếu Tạm ứng/Miễn giảm/Thu 0đ/
-- Chi BHYT của EHC — xem chú thích trong int_rtds_hongha.sql/int_rtds_thv.sql) — nhưng so_giao_dich
-- (count(*)) vẫn đếm cả các dòng đó vì đếm số giao dịch, không phải số tiền.

-- (2026-09-28) User chốt: ghi ra đúng tên bảng Tableau đang dùng `report_doanh_so_HCI_thang` (tên cũ
-- của model này trước khi đổi tên 2026-08-28 — datasource "report_doanh_so_HCI (new_product)" của
-- workbook vẫn trỏ bảng đó) → dbt thay bảng cũ. Thêm cột his_service_type, source_id; nhom_md_ml
-- có thêm 'SP' (sản phẩm KN/PR, không thuộc MD/ML).
-- (2026-09-28) Thêm 3 cột lead/booking Kangnam/Paris (so_sdt_verify, so_booking_tao, so_lich_hen_kh) — DÒNG
-- RIÊNG union từ int_rtds_lead_booking_thang (tong_so_tien/so_giao_dich NULL); dòng doanh số có 3 cột này
-- NULL. ⚠ report_rtds_doanh_so_thang_tableau lọc bỏ dòng lead (so_giao_dich IS NULL).
-- (2026-09-29) Thêm số KHÁCH ĐẾN CỬA / THÀNH CÔNG cả 4 brand (user chốt, cộng cả THV) — DÒNG RIÊNG:
--   * chi tiết brand × năm × tháng × chi nhánh × MD/ML/SP (nguồn NULL) từ report_rtds_khach_hang_den_cua_thanh_cong
--     → so_khach_den_cua, so_khach_thanh_cong (MD + ML + SP = tổng chi nhánh; bỏ dòng 0).
--   * 'Tổng brand' (1 dòng/brand × tháng) từ 2 int khách → so_khach_den_cua_brand, so_khach_thanh_cong_brand = khách
--     DUY NHẤT cả brand (cộng chi nhánh có thể trùng ~0,2%). Đếm theo mã khách (code_customer + brand) như workbook.
--   ⚠ Không SUM qua nhiều tháng (trùng khách quay lại) — lũy kế xem report_rtds_doanh_so_target_thang_tableau.
{{ config(materialized='table', alias='report_doanh_so_thang_HCI') }}

select
    brand,
    nam,
    thang,
    nguon_he_thong,
    chi_nhanh,
    nhom_dich_vu,
    nguon,
    nhom_nguon_khach,
    nhom_md_ml,  -- (2026-09-26) MD/ML, xem macros/rtds_nhom_md_ml.sql
    sum(so_tien) as tong_so_tien,
    count(*) as so_giao_dich,
    count(distinct ma_khach_hang) as so_khach_hang,
    count(distinct ma_booking) as so_booking,
    null::bigint as so_sdt_verify,
    null::bigint as so_booking_tao,
    null::bigint as so_lich_hen_kh,
    null::bigint as so_sdt_verify_brand,
    null::bigint as so_booking_tao_brand,
    null::bigint as so_lich_hen_kh_brand,
    null::bigint as so_khach_den_cua,
    null::bigint as so_khach_thanh_cong,
    null::bigint as so_khach_den_cua_brand,
    null::bigint as so_khach_thanh_cong_brand
from {{ ref('report_rtds_doanh_so') }}
group by 1, 2, 3, 4, 5, 6, 7, 8, 9

union all

select
    brand, nam, thang, nguon_he_thong, chi_nhanh, nhom_dich_vu, nguon, nhom_nguon_khach, nhom_md_ml,
    null::numeric as tong_so_tien,
    null::bigint as so_giao_dich,
    null::bigint as so_khach_hang,
    null::bigint as so_booking,
    so_sdt_verify,
    so_booking_tao,
    so_lich_hen_kh,
    -- (2026-09-28) SĐT duy nhất cả brand × tháng — chỉ có trên dòng chi_nhanh = 'Tổng brand'
    so_sdt_verify_brand,
    so_booking_tao_brand,
    so_lich_hen_kh_brand,
    null::bigint as so_khach_den_cua,
    null::bigint as so_khach_thanh_cong,
    null::bigint as so_khach_den_cua_brand,
    null::bigint as so_khach_thanh_cong_brand
from {{ ref('int_rtds_lead_booking_thang') }}

union all

-- (2026-09-29) Khách đến cửa / thành công theo chi nhánh × MD/ML/SP
select
    brand, nam, thang,
    'CRM' as nguon_he_thong,
    chi_nhanh,
    cast(null as varchar) as nhom_dich_vu,
    cast(null as varchar) as nguon,
    cast(null as varchar) as nhom_nguon_khach,
    nhom_md_ml,
    null::numeric as tong_so_tien,
    null::bigint as so_giao_dich,
    null::bigint as so_khach_hang,
    null::bigint as so_booking,
    null::bigint as so_sdt_verify,
    null::bigint as so_booking_tao,
    null::bigint as so_lich_hen_kh,
    null::bigint as so_sdt_verify_brand,
    null::bigint as so_booking_tao_brand,
    null::bigint as so_lich_hen_kh_brand,
    so_khach_den_cua::bigint,
    so_khach_thanh_cong::bigint,
    null::bigint as so_khach_den_cua_brand,
    null::bigint as so_khach_thanh_cong_brand
from {{ ref('report_rtds_khach_hang_den_cua_thanh_cong') }}
where coalesce(so_khach_den_cua, 0) + coalesce(so_khach_thanh_cong, 0) > 0

union all

-- (2026-09-29) Khách DUY NHẤT cả brand × tháng — dòng 'Tổng brand'
select
    brand, nam, thang,
    'CRM' as nguon_he_thong,
    'Tổng brand' as chi_nhanh,
    cast(null as varchar) as nhom_dich_vu,
    cast(null as varchar) as nguon,
    cast(null as varchar) as nhom_nguon_khach,
    cast(null as text) as nhom_md_ml,
    null::numeric as tong_so_tien,
    null::bigint as so_giao_dich,
    null::bigint as so_khach_hang,
    null::bigint as so_booking,
    null::bigint as so_sdt_verify,
    null::bigint as so_booking_tao,
    null::bigint as so_lich_hen_kh,
    null::bigint as so_sdt_verify_brand,
    null::bigint as so_booking_tao_brand,
    null::bigint as so_lich_hen_kh_brand,
    null::bigint as so_khach_den_cua,
    null::bigint as so_khach_thanh_cong,
    count(distinct ma_khach) as so_khach_den_cua_brand,
    count(distinct ma_khach) filter (where da_thanh_cong) as so_khach_thanh_cong_brand
from (
    select brand, nam, thang, ma_khach, da_thanh_cong from {{ ref('int_rtds_khach_hang_den_cua_thanh_cong') }}
    union all
    select brand, nam, thang, ma_khach, da_thanh_cong from {{ ref('int_rtds_khach_hang_den_cua_thanh_cong_hh_thv') }}
) k
group by 1, 2, 3

-- Tổng hợp THEO THÁNG số khách hàng đến cửa / thành công theo brand + chi nhánh — CẢ 4 THƯƠNG HIỆU:
-- Kangnam/Paris (nguồn report_crm_lead_customer_out_sold, xem int_rtds_khach_hang_den_cua_thanh_
-- cong.sql) + Hồng Hà/Tiêu Hóa Việt (nguồn crm_lead/crm_line trực tiếp, xem int_rtds_khach_hang_den_
-- cua_thanh_cong_hh_thv.sql — 2 brand này KHÔNG dùng report_crm_lead_customer_out_sold vì bảng đó cố
-- ý loại brand_etl=4 ngay trong ETL gốc). Dùng làm mẫu số cho 2 chỉ số "Doanh số KPI / Khách
-- hàng đến cửa" và "Doanh số KPI / Khách hàng thành công" trên Tableau. Join sang
-- report_rtds_doanh_so_thang qua brand + chi_nhanh + nam + thang (cùng cách join bảng target hiện tại —
-- xem comment trong report_rtds_doanh_so_thang.sql).
-- Grain nguồn (cả 2 int model) đã lọc sẵn = "đã đến cửa" theo đúng định nghĩa của từng cặp brand
-- (2 định nghĩa CỐ Ý khác nhau — xem comment trong từng file int — không phải lỗi không nhất quán),
-- nên mỗi dòng nguồn là 1 booking đã đến cửa, không cần filter lại.
--
-- ⚠ (2026-09-27) ĐẾM THEO KHÁCH HÀNG, không theo booking (user chốt, khớp workbook "Bộ chỉ số kinh doanh":
-- COUNTD(code_customer + '_' + brand_id)) — cột ma_khach ở 2 model int:
--   so_khach_den_cua    = số khách DUY NHẤT có ≥1 booking đến cửa trong (brand, chi nhánh, tháng)
--   so_khach_thanh_cong = số khách duy nhất có ≥1 booking đến cửa + thành công
--   Dòng nhom_md_ml = 'MD': khách có ≥1 booking nguồn MD (đúng field "(MD)" workbook)
--   Dòng nhom_md_ml = 'ML': = tổng − MD (khách KHÔNG có booking MD nào) → MD + ML = tổng trong 1 dòng
--                           brand × chi nhánh × tháng.
-- HỆ QUẢ (đã đo T8/2026 Kangnam): số khách KHÔNG cộng dồn tuyệt đối — cộng các chi nhánh cao hơn tổng
-- brand ~0,2% (khách đến nhiều chi nhánh), cộng nhiều tháng bị trùng khách quay lại (T7+T8 ~4%) →
-- Tableau KHÔNG nên SUM số khách qua nhiều tháng (quý/năm) để ra "số khách của kỳ".

{{ config(materialized='table') }}

with base as (
    select brand, chi_nhanh, nam, thang, da_thanh_cong, nhom_md_ml, ma_khach
    from {{ ref('int_rtds_khach_hang_den_cua_thanh_cong') }}
    union all
    select brand, chi_nhanh, nam, thang, da_thanh_cong, nhom_md_ml, ma_khach
    from {{ ref('int_rtds_khach_hang_den_cua_thanh_cong_hh_thv') }}
),

dem as (
    select
        brand,
        chi_nhanh,
        nam,
        thang,
        count(distinct ma_khach) as kh,
        count(distinct ma_khach) filter (where nhom_md_ml = 'MD') as kh_md,
        count(distinct ma_khach) filter (where da_thanh_cong) as tc,
        count(distinct ma_khach) filter (where da_thanh_cong and nhom_md_ml = 'MD') as tc_md
    from base
    group by 1, 2, 3, 4
)

select brand, chi_nhanh, nam, thang, 'MD' as nhom_md_ml,
       kh_md as so_khach_den_cua, tc_md as so_khach_thanh_cong
from dem
union all
select brand, chi_nhanh, nam, thang, 'ML' as nhom_md_ml,
       kh - kh_md as so_khach_den_cua, tc - tc_md as so_khach_thanh_cong
from dem

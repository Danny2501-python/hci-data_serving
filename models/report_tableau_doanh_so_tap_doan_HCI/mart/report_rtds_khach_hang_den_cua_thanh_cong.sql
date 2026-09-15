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
-- nên count(*) ở đây chính là so_khach_den_cua, không cần filter lại.

{{ config(materialized='table') }}

with base as (
    select crm_id, brand, chi_nhanh, nam, thang, da_thanh_cong
    from {{ ref('int_rtds_khach_hang_den_cua_thanh_cong') }}
    union all
    select crm_id, brand, chi_nhanh, nam, thang, da_thanh_cong
    from {{ ref('int_rtds_khach_hang_den_cua_thanh_cong_hh_thv') }}
)

select
    brand,
    chi_nhanh,
    nam,
    thang,
    count(*) as so_khach_den_cua,
    count(*) filter (where da_thanh_cong) as so_khach_thanh_cong
from base
group by 1, 2, 3, 4

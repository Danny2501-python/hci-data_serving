-- Tổng hợp THEO THÁNG số khách hàng đến cửa / thành công theo brand + chi nhánh — dùng làm mẫu số
-- cho 2 chỉ số "Doanh số KPI / Khách hàng đến cửa" và "Doanh số KPI / Khách hàng thành công" trên
-- Tableau. Join sang mart_rtds_doanh_so_thang qua brand + chi_nhanh + nam + thang (cùng cách join
-- bảng target hiện tại — xem comment trong mart_rtds_doanh_so_thang.sql).
-- ⚠ Số liệu phụ thuộc bảng nguồn report_crm_lead_customer_out_sold đang bị lỗi đồng bộ (xem
-- int_rtds_khach_hang_den_cua_thanh_cong.sql) — build lại model này sau khi bảng nguồn được backfill
-- đúng để có số chính thức.

{{ config(materialized='table') }}

select
    brand,
    chi_nhanh,
    nam,
    thang,
    count(*) filter (where da_den_cua) as so_khach_den_cua,
    count(*) filter (where da_thanh_cong) as so_khach_thanh_cong
from {{ ref('int_rtds_khach_hang_den_cua_thanh_cong') }}
group by 1, 2, 3, 4

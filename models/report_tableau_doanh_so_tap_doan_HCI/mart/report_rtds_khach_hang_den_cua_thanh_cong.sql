-- Tổng hợp THEO THÁNG số khách hàng đến cửa / thành công theo brand + chi nhánh (cả 4 thương hiệu
-- Kangnam/Paris/Hồng Hà/Tiêu Hóa Việt — xem int_rtds_khach_hang_den_cua_thanh_cong.sql) — dùng làm
-- mẫu số cho 2 chỉ số "Doanh số KPI / Khách
-- hàng đến cửa" và "Doanh số KPI / Khách hàng thành công" trên Tableau. Join sang
-- report_rtds_doanh_so_thang qua brand + chi_nhanh + nam + thang (cùng cách join bảng target hiện tại —
-- xem comment trong report_rtds_doanh_so_thang.sql).
-- Grain nguồn (int_rtds_khach_hang_den_cua_thanh_cong) đã lọc sẵn = "đã đến cửa" (theo định nghĩa
-- user chốt 2026-09-15), nên count(*) ở đây chính là so_khach_den_cua, không cần filter lại.

{{ config(materialized='table') }}

select
    brand,
    chi_nhanh,
    nam,
    thang,
    count(*) as so_khach_den_cua,
    count(*) filter (where da_thanh_cong) as so_khach_thanh_cong
from {{ ref('int_rtds_khach_hang_den_cua_thanh_cong') }}
group by 1, 2, 3, 4

-- Bảng tổng hợp THEO THÁNG cho tab "Doanh số" — dùng làm nguồn kéo lên Tableau cho nhẹ (group by
-- trước, không phải transaction-level như mart_rtds_doanh_so — 374K dòng). Cần xem chi tiết từng
-- giao dịch/khách hàng thì quay lại mart_rtds_doanh_so.
--
-- Grain: 1 dòng = 1 brand + năm + tháng + nguồn hệ thống (CRM/EHC) + chi nhánh + nhóm dịch vụ +
-- nguồn + nhóm nguồn khách. Vẫn khớp brand+nam+thang để join bảng kế hoạch (target) ở Tableau
-- (target chỉ có grain brand+nam+thang, group thêm chiều khác ở đây không ảnh hưởng join đó).
--
-- tong_so_tien = sum(so_tien), tự động bỏ qua các dòng so_tien NULL (phiếu Tạm ứng/Miễn giảm/Thu 0đ/
-- Chi BHYT của EHC — xem chú thích trong int_rtds_hongha.sql/int_rtds_thv.sql) — nhưng so_giao_dich
-- (count(*)) vẫn đếm cả các dòng đó vì đếm số giao dịch, không phải số tiền.

{{ config(materialized='table') }}

select
    brand,
    nam,
    thang,
    nguon_he_thong,
    chi_nhanh,
    nhom_dich_vu,
    nguon,
    nhom_nguon_khach,
    sum(so_tien) as tong_so_tien,
    count(*) as so_giao_dich,
    count(distinct ma_khach_hang) as so_khach_hang,
    count(distinct ma_booking) as so_booking
from {{ ref('report_doanh_so_HCI') }}
group by 1, 2, 3, 4, 5, 6, 7, 8

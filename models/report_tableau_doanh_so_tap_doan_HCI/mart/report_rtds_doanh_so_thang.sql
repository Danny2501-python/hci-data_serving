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
{{ config(materialized='table', alias='report_doanh_so_HCI_thang') }}

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
    count(distinct ma_booking) as so_booking
from {{ ref('report_rtds_doanh_so') }}
group by 1, 2, 3, 4, 5, 6, 7, 8, 9

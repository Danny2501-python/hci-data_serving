-- Bảng report cuối cho tab "Doanh số" — báo cáo Tableau, gộp 4 thương hiệu HCI (Kangnam, Paris,
-- Hồng Hà, Tiêu Hóa Việt), grain 1 dòng = 1 giao dịch/khách hàng+booking. Xem thiết kế đầy đủ
-- (bảng ánh xạ cột → nguồn) trong lịch sử trao đổi 2026-08-27 trước khi sửa cột.
-- CHỈ doanh số thực tế (KHÔNG có kế hoạch/chỉ tiêu — để bảng riêng, join ở Tableau qua
-- brand+nam+thang, xem lý do trong thiết kế đã duyệt).
-- ⚠⚠ (2026-09-11) Kangnam/Paris: `so_tien` là "DOANH SỐ TÍNH KPI" (đã loại nguồn CBNV/đối ngoại/TPM/
-- bác sĩ hợp tác nội bộ + sản phẩm is_no_kpi, khớp sheet GB_result trong Tableau workbook KANGNAM),
-- KHÔNG PHẢI "doanh số tổng" thô nữa — xem chi tiết int_rtds_kangnam.sql. Hồng Hà/THV không đổi
-- (vẫn là doanh số tổng, hệ EHC không có khái niệm is_kpi_branch tương ứng).

{{ config(materialized='table') }}

select * from {{ ref('int_rtds_kangnam') }}
union all
select * from {{ ref('int_rtds_paris') }}
union all
select * from {{ ref('int_rtds_hongha') }}
union all
select * from {{ ref('int_rtds_thv') }}

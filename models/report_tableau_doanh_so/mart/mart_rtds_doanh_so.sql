-- Bảng report cuối cho tab "Doanh số" — báo cáo Tableau, gộp 4 thương hiệu HCI (Kangnam, Paris,
-- Hồng Hà, Tiêu Hóa Việt), grain 1 dòng = 1 giao dịch/khách hàng+booking. Xem thiết kế đầy đủ
-- (bảng ánh xạ cột → nguồn) trong lịch sử trao đổi 2026-08-27 trước khi sửa cột.
-- CHỈ doanh số thực tế (KHÔNG có kế hoạch/chỉ tiêu — để bảng riêng, join ở Tableau qua
-- brand+nam+thang, xem lý do trong thiết kế đã duyệt).

{{ config(materialized='table') }}

select * from {{ ref('int_rtds_kangnam') }}
union all
select * from {{ ref('int_rtds_paris') }}
union all
select * from {{ ref('int_rtds_hongha') }}
union all
select * from {{ ref('int_rtds_thv') }}

-- Bảng doanh số theo tháng "cho Tableau" — bản đã xử lý lỗ hổng dữ liệu 2025 (quyết định của
-- người dùng, 2026-08-31, xem data_demo/history.md mục 0ggg và trao đổi cùng ngày):
--   - Năm >= 2026: lấy THẲNG từ mart_rtds_doanh_so_thang (nguồn CRM/EHC qua dbt, cập nhật liên
--     tục — đã kiểm tra 2026 đủ dữ liệu T1-T8 cho cả 4 thương hiệu, không có lỗ hổng).
--   - Năm = 2025: lấy từ seed_doanh_so_2025_mockup (số đã xác nhận thủ công, đang dùng trong
--     data_demo/dashboard.html) — VÌ nguồn CRM/EHC cho 2025 còn thiếu mạnh (kiểm tra 2026-08-31:
--     Kangnam thiếu hẳn T1-T6/2025, Paris thiếu 5/12 tháng, Tiêu Hóa Việt cả năm rất thấp bất
--     thường so với số đã xác nhận) — dùng lại đúng vấn đề đã ghi trong data_demo/history.md
--     mục 2c (lý do dashboard.html bỏ nguồn dbt hồi 2026-08-08).
-- Cột "nguon_du_lieu" để phân biệt rõ dòng nào tới từ DB sống, dòng nào từ số mockup tĩnh — audit
-- lại dễ dàng khi nguồn CRM/EHC 2025 được vá (nếu vá xong, xoá nhánh UNION dưới, chỉ còn đọc DB).
--
-- Grain năm>=2026: brand+nam+thang+nguon_he_thong+chi_nhanh+nhom_dich_vu+nguon+nhom_nguon_khach.
-- Grain năm=2025 (từ seed): chỉ có brand+nam+thang (mockup không có breakdown chi tiết hơn) — các
-- cột breakdown còn lại để NULL, KHÔNG suy diễn phân bổ ngược.

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
    tong_so_tien,
    so_giao_dich,
    so_khach_hang,
    so_booking,
    'DB_LIVE' as nguon_du_lieu
from {{ ref('mart_rtds_doanh_so_thang') }}
where nam >= 2026

union all

select
    brand,
    nam,
    thang,
    cast(null as text) as nguon_he_thong,
    cast(null as varchar) as chi_nhanh,
    cast(null as text) as nhom_dich_vu,
    cast(null as varchar) as nguon,
    cast(null as varchar) as nhom_nguon_khach,
    tong_so_tien,
    cast(null as bigint) as so_giao_dich,
    cast(null as bigint) as so_khach_hang,
    cast(null as bigint) as so_booking,
    'MOCKUP_2025' as nguon_du_lieu
from {{ ref('seed_doanh_so_2025_mockup') }}

-- Bảng doanh số theo tháng "cho Tableau" — bản đã xử lý lỗ hổng dữ liệu 2025 (quyết định của
-- người dùng, 2026-08-31, xem data_demo/history.md mục 0ggg và trao đổi cùng ngày):
--   - Năm >= 2026: lấy THẲNG từ report_rtds_doanh_so_thang (nguồn CRM/EHC qua dbt, cập nhật liên
--     tục — đã kiểm tra 2026 đủ dữ liệu T1-T8 cho cả 4 thương hiệu, không có lỗ hổng).
--   - Năm = 2025: lấy từ seed_doanh_so_2025_mockup (số đã xác nhận thủ công, đang dùng trong
--     data_demo/dashboard.html) — VÌ nguồn CRM/EHC cho 2025 còn thiếu mạnh (kiểm tra 2026-08-31:
--     Kangnam thiếu hẳn T1-T6/2025, Paris thiếu 5/12 tháng, Tiêu Hóa Việt cả năm rất thấp bất
--     thường so với số đã xác nhận) — dùng lại đúng vấn đề đã ghi trong data_demo/history.md
--     mục 2c (lý do dashboard.html bỏ nguồn dbt hồi 2026-08-08).
-- Cột "nguon_du_lieu" để phân biệt rõ dòng nào tới từ DB sống, dòng nào từ số mockup tĩnh — audit
-- lại dễ dàng khi nguồn CRM/EHC 2025 được vá (nếu vá xong, xoá nhánh UNION dưới, chỉ còn đọc DB).
--
-- Grain năm>=2026 (chưa bị "số chốt" ghi đè): brand+nam+thang+nguon_he_thong+chi_nhanh+nhom_dich_vu+
-- nguon+nhom_nguon_khach. Grain năm=2025 (từ seed) và grain của "số chốt" (xem dưới): chỉ có
-- brand+nam+thang (không có breakdown chi tiết hơn) — các cột breakdown còn lại để NULL, KHÔNG suy
-- diễn phân bổ ngược.
--
-- (2026-09-16) THÊM lớp "số chốt" cho Hồng Hà/Tiêu Hóa Việt qua seed
-- seed_doanh_so_chot_hongha_thv (user tự import số đã chốt/đối soát thủ công — KHÁC luồng dbt tự
-- động, dùng để đưa NGAY số đúng lên báo cáo trong lúc luồng tự động còn đang cần điều chỉnh) —
-- GHI ĐÈ số của report_rtds_doanh_so_thang (nam>=2026) cho ĐÚNG brand+nam+thang có mặt trong seed,
-- TRỪ THÁNG HIỆN TẠI (tháng đang chạy chưa "chốt" xong, luôn ưu tiên số live để theo dõi tiến độ
-- real-time). Luồng dbt cũ (int_rtds_hongha.sql/int_rtds_thv.sql → report_rtds_doanh_so →
-- report_rtds_doanh_so_thang) VẪN GIỮ NGUYÊN chạy song song, KHÔNG bị thay thế — seed chỉ ghi đè ở
-- bước cuối cùng này (đúng ý user: "vẫn giữ luồng cũ để điều chỉnh sau, seed tạm thay số lên báo
-- cáo"). "Tháng hiện tại" xác định động bằng current_date tại thời điểm build model — do đó cần
-- build lại model này (dbt run) mỗi khi sang tháng mới để "nhả" tháng vừa qua ra khỏi diện live và
-- (nếu seed đã có số) chuyển sang dùng số chốt.
-- ⚠ (2026-09-16) `seed_doanh_so_chot_hongha_thv` CHỈ được điền cho năm >= 2026 — năm 2025 đã có
-- `seed_doanh_so_2025_mockup` riêng (nhánh UNION cuối, luôn áp dụng cho year=2025 KHÔNG điều kiện).
-- Đã CHẶN CỨNG bằng `s.nam >= 2026` trong `seed_ap_dung` bên dưới — nếu ai lỡ điền dòng năm 2025 vào
-- seed_doanh_so_chot_hongha_thv (VD copy nhầm số đã có sẵn trong seed_doanh_so_2025_mockup), dòng đó
-- sẽ tự động bị BỎ QUA thay vì cộng trùng đôi với nhánh MOCKUP_2025.

{{ config(materialized='table') }}

with current_period as (
    select
        extract(year from current_date)::int as nam_hien_tai,
        extract(month from current_date)::int as thang_hien_tai
),

live as (
    select
        brand, nam, thang, nguon_he_thong, chi_nhanh, nhom_dich_vu, nguon, nhom_nguon_khach,
        tong_so_tien, so_giao_dich, so_khach_hang, so_booking
    from {{ ref('report_rtds_doanh_so_thang') }}
    where nam >= 2026
),

-- (2026-09-26) Bật/tắt ghi đè số chốt bằng var `rtds_ap_dung_so_chot` (dbt_project.yml). Hiện TẮT:
-- báo cáo dùng số tính dbt, seed vẫn giữ nguyên dữ liệu để so sánh (query thẳng bảng seed khi cần).
seed_chot as (
    select brand, nam, thang, tong_so_tien
    from {{ ref('seed_doanh_so_chot_hongha_thv') }}
    where nam >= 2026
      and {{ 'true' if var('rtds_ap_dung_so_chot', false) else 'false' }}
),

live_khong_bi_ghi_de as (
    select l.*
    from live l
    cross join current_period cp
    where (l.nam = cp.nam_hien_tai and l.thang = cp.thang_hien_tai)
       or not exists (
           select 1 from seed_chot s
           where s.brand = l.brand and s.nam = l.nam and s.thang = l.thang
       )
),

seed_ap_dung as (
    select
        s.brand,
        s.nam,
        s.thang,
        cast(null as text) as nguon_he_thong,
        cast(null as varchar) as chi_nhanh,
        cast(null as text) as nhom_dich_vu,
        cast(null as varchar) as nguon,
        cast(null as varchar) as nhom_nguon_khach,
        s.tong_so_tien,
        cast(null as bigint) as so_giao_dich,
        cast(null as bigint) as so_khach_hang,
        cast(null as bigint) as so_booking
    from seed_chot s
    cross join current_period cp
    where not (s.nam = cp.nam_hien_tai and s.thang = cp.thang_hien_tai)
)

select *, 'DB_LIVE' as nguon_du_lieu from live_khong_bi_ghi_de

union all

select *, 'SEED_CHOT_HHTHV' as nguon_du_lieu from seed_ap_dung

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

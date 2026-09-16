-- Bảng PHẲNG cấp thương hiệu cho Tableau — gộp doanh số + kế hoạch cùng 1 dòng/brand+năm+tháng,
-- KHÔNG breakdown chi nhánh/nguồn/nhóm dịch vụ (dùng cho 2 trang "So với cùng kỳ 2025" và "So với
-- Kế hoạch 2026" cấp thương hiệu — muốn breakdown chi tiết hơn quay lại
-- report_rtds_doanh_so_thang_tableau/report_rtds_target_thang_tableau).
--
-- Thiết kế CỐ TÌNH tránh Tableau Relationship/LOD: mọi phép gộp (kể cả dòng "HCI Group") đã tính
-- SẴN trong SQL này — Tableau chỉ cần calculated field SUM(IF [nam]=2025 THEN...) đơn giản, không
-- rủi ro fan-out. "HCI Group" = tổng 4 thương hiệu, CHỈ tính khi CẢ 4 thương hiệu cùng có giá trị ở
-- đúng field đó tháng đó (đúng quy tắc computeGroup() trong data_demo/dashboard.html mục 3/0xx —
-- đã đối chiếu khớp chính xác F1 T1/2026=136,38% khi build data_demo/tableau/build_twbx.py
-- 2026-08-31, xem data_demo/history.md mục 0ggg) — tính riêng cho tong_so_tien và target (2 field
-- độc lập, 1 brand có thể có doanh số nhưng chưa có KH tháng đó hoặc ngược lại).
--
-- (2026-09-15) Thêm so_khach_den_cua/so_khach_thanh_cong (nguồn report_rtds_khach_hang_den_cua_
-- thanh_cong, xem file đó + LOGIC.md mục 4f) để lên 2 chỉ số "Doanh số KPI / Khách hàng đến cửa" và
-- "Doanh số KPI / Khách hàng thành công". Nguồn `report_rtds_khach_hang_den_cua_thanh_cong` giờ đã có
-- ĐỦ 4 thương hiệu (Kangnam/Paris từ report_crm_lead_customer_out_sold + Hồng Hà/THV từ crm_lead/
-- crm_line trực tiếp — xem int_rtds_khach_hang_den_cua_thanh_cong_hh_thv.sql) — KHÔNG còn tình trạng
-- Hồng Hà thiếu dữ liệu như phát hiện ban đầu (hoá ra chỉ do report_crm_lead_customer_out_sold cố ý
-- loại brand_etl=4, không phải Hồng Hà thật sự thiếu data).
--
-- ⚠ (2026-09-15) Rule "HCI Group" cho 2 field khách hàng KHÁC với tong_so_tien/target — user chốt:
-- Tiêu Hóa Việt mới hoạt động từ 2026-01-15 (không có dữ liệu 2024/2025), nếu áp cùng rule "đủ cả 4
-- thương hiệu" như tong_so_tien/target thì dòng "HCI Group" của 2 field khách hàng sẽ NULL toàn bộ
-- các năm cũ, không so sánh YoY cấp tập đoàn được. User quyết định: "HCI Group" của
-- so_khach_den_cua/so_khach_thanh_cong CHỈ tính tổng Kangnam+Paris+Hồng Hà (đủ CẢ 3 thương hiệu này,
-- KHÔNG cần/KHÔNG cộng Tiêu Hóa Việt) — xem CTE `hci_group_customer` bên dưới, tách riêng khỏi
-- `hci_group_revenue` (vẫn giữ nguyên rule cũ, đủ cả 4, cho tong_so_tien/target).

{{ config(materialized='table') }}

with revenue as (
    select brand, nam, thang, sum(tong_so_tien) as tong_so_tien
    from {{ ref('report_rtds_doanh_so_thang_tableau') }}
    group by 1, 2, 3
),

target as (
    select brand, nam, thang, sum(target) as target
    from {{ ref('report_rtds_target_thang_tableau') }}
    where nam = 2026
    group by 1, 2, 3
),

customer as (
    select
        brand,
        nam,
        thang,
        sum(so_khach_den_cua) as so_khach_den_cua,
        sum(so_khach_thanh_cong) as so_khach_thanh_cong
    from {{ ref('report_rtds_khach_hang_den_cua_thanh_cong') }}
    group by 1, 2, 3
),

combined as (
    select
        coalesce(r.brand, t.brand, c.brand) as brand,
        coalesce(r.nam, t.nam, c.nam) as nam,
        coalesce(r.thang, t.thang, c.thang) as thang,
        r.tong_so_tien,
        t.target,
        c.so_khach_den_cua,
        c.so_khach_thanh_cong
    from revenue r
    full outer join target t
        on r.brand = t.brand and r.nam = t.nam and r.thang = t.thang
    full outer join customer c
        on c.brand = coalesce(r.brand, t.brand) and c.nam = coalesce(r.nam, t.nam) and c.thang = coalesce(r.thang, t.thang)
),

hci_group_revenue as (
    select
        nam,
        thang,
        case when count(tong_so_tien) = 4 then sum(tong_so_tien) end as tong_so_tien,
        case when count(target) = 4 then sum(target) end as target
    from combined
    group by nam, thang
),

hci_group_customer as (
    select
        nam,
        thang,
        case when count(so_khach_den_cua) = 3 then sum(so_khach_den_cua) end as so_khach_den_cua,
        case when count(so_khach_thanh_cong) = 3 then sum(so_khach_thanh_cong) end as so_khach_thanh_cong
    from combined
    where brand in ('Kangnam', 'Paris', 'Hồng Hà')
    group by nam, thang
),

hci_group as (
    select
        coalesce(r.nam, c.nam) as nam,
        coalesce(r.thang, c.thang) as thang,
        r.tong_so_tien,
        r.target,
        c.so_khach_den_cua,
        c.so_khach_thanh_cong
    from hci_group_revenue r
    full outer join hci_group_customer c on r.nam = c.nam and r.thang = c.thang
)

select brand, nam, thang, tong_so_tien, target, so_khach_den_cua, so_khach_thanh_cong from combined
union all
select 'HCI Group' as brand, nam, thang, tong_so_tien, target, so_khach_den_cua, so_khach_thanh_cong from hci_group

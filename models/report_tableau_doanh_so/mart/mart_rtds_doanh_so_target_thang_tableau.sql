-- Bảng PHẲNG cấp thương hiệu cho Tableau — gộp doanh số + kế hoạch cùng 1 dòng/brand+năm+tháng,
-- KHÔNG breakdown chi nhánh/nguồn/nhóm dịch vụ (dùng cho 2 trang "So với cùng kỳ 2025" và "So với
-- Kế hoạch 2026" cấp thương hiệu — muốn breakdown chi tiết hơn quay lại
-- mart_rtds_doanh_so_thang_tableau/mart_rtds_target_thang_tableau).
--
-- Thiết kế CỐ TÌNH tránh Tableau Relationship/LOD: mọi phép gộp (kể cả dòng "HCI Group") đã tính
-- SẴN trong SQL này — Tableau chỉ cần calculated field SUM(IF [nam]=2025 THEN...) đơn giản, không
-- rủi ro fan-out. "HCI Group" = tổng 4 thương hiệu, CHỈ tính khi CẢ 4 thương hiệu cùng có giá trị ở
-- đúng field đó tháng đó (đúng quy tắc computeGroup() trong data_demo/dashboard.html mục 3/0xx —
-- đã đối chiếu khớp chính xác F1 T1/2026=136,38% khi build data_demo/tableau/build_twbx.py
-- 2026-08-31, xem data_demo/history.md mục 0ggg) — tính riêng cho tong_so_tien và target (2 field
-- độc lập, 1 brand có thể có doanh số nhưng chưa có KH tháng đó hoặc ngược lại).

{{ config(materialized='table') }}

with revenue as (
    select brand, nam, thang, sum(tong_so_tien) as tong_so_tien
    from {{ ref('mart_rtds_doanh_so_thang_tableau') }}
    group by 1, 2, 3
),

target as (
    select brand, nam, thang, sum(target) as target
    from {{ ref('mart_rtds_target_thang_tableau') }}
    where nam = 2026
    group by 1, 2, 3
),

combined as (
    select
        coalesce(r.brand, t.brand) as brand,
        coalesce(r.nam, t.nam) as nam,
        coalesce(r.thang, t.thang) as thang,
        r.tong_so_tien,
        t.target
    from revenue r
    full outer join target t
        on r.brand = t.brand and r.nam = t.nam and r.thang = t.thang
),

hci_group as (
    select
        nam,
        thang,
        case when count(tong_so_tien) = 4 then sum(tong_so_tien) end as tong_so_tien,
        case when count(target) = 4 then sum(target) end as target
    from combined
    group by nam, thang
)

select brand, nam, thang, tong_so_tien, target from combined
union all
select 'HCI Group' as brand, nam, thang, tong_so_tien, target from hci_group

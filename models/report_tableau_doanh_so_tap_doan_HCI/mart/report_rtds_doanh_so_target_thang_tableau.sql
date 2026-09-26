-- Bảng PHẲNG cho Tableau — gộp doanh số + kế hoạch + khách hàng.
-- ⚠ (2026-09-26) ĐỔI GRAIN: 1 dòng = brand + năm + tháng + CHI NHÁNH (trước đây brand + năm + tháng),
-- thêm cột tách nguồn MD/ML (user chốt). Tổng theo brand vẫn đúng khi SUM các dòng chi nhánh; dòng
-- "HCI Group" vẫn tính SẴN ở cấp tập đoàn với chi_nhanh = 'HCI Group'. Tableau: mọi calculated field
-- phải dùng SUM (không dùng MIN/ATTR theo dòng) vì 1 brand-tháng giờ có nhiều dòng.
--   - chi_nhanh: tên chuẩn m_res_company — doanh số KN/PR (mrc.name), Hồng Hà 'BỆNH VIỆN HỒNG HÀ',
--     THV 'Phòng Khám Tiêu Hóa Việt' (int_rtds_hongha/thv), target (report_rtds_target_thang_tableau
--     đã chuẩn hoá tên theo company_id), khách hàng (report_company / m_res_company).
--     Doanh số 2025 lấy từ seed_doanh_so_2025_mockup (chỉ có tổng theo brand) → dòng 2025 có
--     chi_nhanh NULL, không tách MD/ML.
--   - MD/ML: xem macros/rtds_nhom_md_ml.sql (KN/PR + nguồn ERP Hồng Hà theo workbook "Bộ chỉ số kinh
--     doanh"; Hồng Hà fallback nhóm hoa hồng EHC; THV theo nhom_md_ml_baocao của hahth; khách hàng
--     theo nguồn CRM). *_md + *_ml = tổng (nhóm "Khác" tính vào ML).
--
-- Thiết kế CỐ TÌNH tránh Tableau Relationship/LOD: mọi phép gộp (kể cả dòng "HCI Group") đã tính
-- SẴN trong SQL này. "HCI Group" = tổng 4 thương hiệu, CHỈ tính khi CẢ 4 thương hiệu cùng có giá trị
-- ở đúng field đó tháng đó (quy tắc computeGroup() của data_demo/dashboard.html) — tính riêng cho
-- tong_so_tien và target (2 field độc lập).
--
-- (2026-09-15) so_khach_den_cua/so_khach_thanh_cong từ report_rtds_khach_hang_den_cua_thanh_cong
-- (Kangnam/Paris từ report_crm_lead_customer_out_sold + Hồng Hà/THV từ crm_lead) — xem LOGIC.md mục 4f.
-- ⚠ Rule "HCI Group" cho 2 field khách hàng: CHỈ tổng Kangnam+Paris+Hồng Hà (đủ cả 3, không cộng THV
-- — THV mới hoạt động từ 2026-01-15, cộng vào thì năm cũ NULL hết, mất so sánh YoY). User chốt.

{{ config(materialized='table') }}

-- Khoá join chi nhánh dùng coalesce(chi_nhanh, '') vì FULL JOIN không hỗ trợ IS NOT DISTINCT FROM.
with revenue as (
    select
        brand, nam, thang, coalesce(chi_nhanh, '') as cn,
        sum(tong_so_tien) as tong_so_tien,
        sum(tong_so_tien) filter (where nhom_md_ml = 'MD') as doanh_so_md,
        sum(tong_so_tien) filter (where nhom_md_ml = 'ML') as doanh_so_ml
    from {{ ref('report_rtds_doanh_so_thang_tableau') }}
    group by 1, 2, 3, 4
),

target as (
    select brand, nam, thang, coalesce(chi_nhanh, '') as cn, sum(target) as target
    from {{ ref('report_rtds_target_thang_tableau') }}
    where nam = 2026
    group by 1, 2, 3, 4
),

customer as (
    select
        brand, nam, thang, coalesce(chi_nhanh, '') as cn,
        sum(so_khach_den_cua) as so_khach_den_cua,
        sum(so_khach_thanh_cong) as so_khach_thanh_cong,
        sum(so_khach_den_cua) filter (where nhom_md_ml = 'MD') as so_khach_den_cua_md,
        sum(so_khach_den_cua) filter (where nhom_md_ml = 'ML') as so_khach_den_cua_ml,
        sum(so_khach_thanh_cong) filter (where nhom_md_ml = 'MD') as so_khach_thanh_cong_md,
        sum(so_khach_thanh_cong) filter (where nhom_md_ml = 'ML') as so_khach_thanh_cong_ml
    from {{ ref('report_rtds_khach_hang_den_cua_thanh_cong') }}
    group by 1, 2, 3, 4
),

combined as (
    select
        coalesce(r.brand, t.brand, c.brand) as brand,
        coalesce(r.nam, t.nam, c.nam) as nam,
        coalesce(r.thang, t.thang, c.thang) as thang,
        nullif(coalesce(r.cn, t.cn, c.cn), '') as chi_nhanh,
        r.tong_so_tien,
        t.target,
        c.so_khach_den_cua,
        c.so_khach_thanh_cong,
        r.doanh_so_md,
        r.doanh_so_ml,
        c.so_khach_den_cua_md,
        c.so_khach_den_cua_ml,
        c.so_khach_thanh_cong_md,
        c.so_khach_thanh_cong_ml
    from revenue r
    full outer join target t
        on r.brand = t.brand and r.nam = t.nam and r.thang = t.thang and r.cn = t.cn
    full outer join customer c
        on c.brand = coalesce(r.brand, t.brand) and c.nam = coalesce(r.nam, t.nam)
       and c.thang = coalesce(r.thang, t.thang) and c.cn = coalesce(r.cn, t.cn)
),

-- Tổng theo brand (sum các chi nhánh) — làm đầu vào cho quy tắc "HCI Group" (đếm theo brand).
brand_total as (
    select
        brand, nam, thang,
        sum(tong_so_tien) as tong_so_tien,
        sum(target) as target,
        sum(so_khach_den_cua) as so_khach_den_cua,
        sum(so_khach_thanh_cong) as so_khach_thanh_cong,
        sum(doanh_so_md) as doanh_so_md,
        sum(doanh_so_ml) as doanh_so_ml,
        sum(so_khach_den_cua_md) as so_khach_den_cua_md,
        sum(so_khach_den_cua_ml) as so_khach_den_cua_ml,
        sum(so_khach_thanh_cong_md) as so_khach_thanh_cong_md,
        sum(so_khach_thanh_cong_ml) as so_khach_thanh_cong_ml
    from combined
    group by 1, 2, 3
),

hci_group_revenue as (
    select
        nam,
        thang,
        case when count(tong_so_tien) = 4 then sum(tong_so_tien) end as tong_so_tien,
        case when count(target) = 4 then sum(target) end as target,
        -- MD/ML: cùng điều kiện đủ 4 thương hiệu như tong_so_tien
        case when count(tong_so_tien) = 4 then sum(doanh_so_md) end as doanh_so_md,
        case when count(tong_so_tien) = 4 then sum(doanh_so_ml) end as doanh_so_ml
    from brand_total
    group by nam, thang
),

hci_group_customer as (
    select
        nam,
        thang,
        case when count(so_khach_den_cua) = 3 then sum(so_khach_den_cua) end as so_khach_den_cua,
        case when count(so_khach_thanh_cong) = 3 then sum(so_khach_thanh_cong) end as so_khach_thanh_cong,
        case when count(so_khach_den_cua) = 3 then sum(so_khach_den_cua_md) end as so_khach_den_cua_md,
        case when count(so_khach_den_cua) = 3 then sum(so_khach_den_cua_ml) end as so_khach_den_cua_ml,
        case when count(so_khach_thanh_cong) = 3 then sum(so_khach_thanh_cong_md) end as so_khach_thanh_cong_md,
        case when count(so_khach_thanh_cong) = 3 then sum(so_khach_thanh_cong_ml) end as so_khach_thanh_cong_ml
    from brand_total
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
        c.so_khach_thanh_cong,
        r.doanh_so_md,
        r.doanh_so_ml,
        c.so_khach_den_cua_md,
        c.so_khach_den_cua_ml,
        c.so_khach_thanh_cong_md,
        c.so_khach_thanh_cong_ml
    from hci_group_revenue r
    full outer join hci_group_customer c on r.nam = c.nam and r.thang = c.thang
)

select
    brand, nam, thang, chi_nhanh,
    tong_so_tien, target, so_khach_den_cua, so_khach_thanh_cong,
    doanh_so_md, doanh_so_ml,
    so_khach_den_cua_md, so_khach_den_cua_ml,
    so_khach_thanh_cong_md, so_khach_thanh_cong_ml
from combined

union all

select
    'HCI Group' as brand, nam, thang, 'HCI Group' as chi_nhanh,
    tong_so_tien, target, so_khach_den_cua, so_khach_thanh_cong,
    doanh_so_md, doanh_so_ml,
    so_khach_den_cua_md, so_khach_den_cua_ml,
    so_khach_thanh_cong_md, so_khach_thanh_cong_ml
from hci_group

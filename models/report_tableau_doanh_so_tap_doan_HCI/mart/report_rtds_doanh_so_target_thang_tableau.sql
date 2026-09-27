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
),

-- ============================================================================================
-- (2026-09-27) LŨY KẾ CÙNG KỲ cho scorecard (user chốt): năm nay = T1 → THÁNG HIỆN TẠI (theo
-- current_date, tính cả tháng đang dở), năm trước = T1 → cùng tháng đó, ĐỦ CẢ THÁNG. Trước đây
-- scorecard SUM cả năm nên so 2026 T1-T9 với 2025 đủ 12 tháng (không cùng kỳ).
-- Số khách lũy kế = số khách DUY NHẤT cả kỳ (COUNT DISTINCT ma_khach trên toàn kỳ), KHÔNG cộng các
-- tháng (cộng tháng sẽ đếm trùng khách quay lại). Ra 1 dòng/brand + 1 dòng HCI Group với
-- chi_nhanh = 'Lũy kế cùng kỳ', nam = năm hiện tại, thang = tháng hiện tại; CÁC CỘT CŨ = NULL trên dòng
-- này nên các sheet đang SUM cột cũ không bị ảnh hưởng. Chỉ dùng cột *_luy_ke* trên dòng này.
-- ============================================================================================
ky as (
    select
        extract(year from current_date)::int as nam_nay,
        extract(month from current_date)::int as thang_nay
),

lk_doanh_so as (
    select
        b.brand,
        sum(b.tong_so_tien) filter (where b.nam = k.nam_nay) as doanh_so_luy_ke,
        sum(b.tong_so_tien) filter (where b.nam = k.nam_nay - 1) as doanh_so_luy_ke_cung_ky_nam_truoc,
        sum(b.target) filter (where b.nam = k.nam_nay) as target_luy_ke,
        sum(b.doanh_so_md) filter (where b.nam = k.nam_nay) as doanh_so_md_luy_ke,
        sum(b.doanh_so_ml) filter (where b.nam = k.nam_nay) as doanh_so_ml_luy_ke
    from brand_total b
    cross join ky k
    where b.nam in (k.nam_nay, k.nam_nay - 1)
      and b.thang <= k.thang_nay
    group by 1
),

lk_khach_nguon as (
    select brand, nam, thang, da_thanh_cong, nhom_md_ml, ma_khach
    from {{ ref('int_rtds_khach_hang_den_cua_thanh_cong') }}
    union all
    select brand, nam, thang, da_thanh_cong, nhom_md_ml, ma_khach
    from {{ ref('int_rtds_khach_hang_den_cua_thanh_cong_hh_thv') }}
),

-- Khách MD lũy kế = khách có ≥1 booking nguồn MD trong kỳ; ML = tổng − MD (tính ở lk_brand, cùng
-- quy ước với report_rtds_khach_hang_den_cua_thanh_cong) → MD + ML = tổng.
lk_khach as (
    select
        n.brand,
        count(distinct n.ma_khach) filter (where n.nam = k.nam_nay) as so_khach_den_cua_luy_ke,
        count(distinct n.ma_khach) filter (where n.nam = k.nam_nay - 1) as so_khach_den_cua_luy_ke_cung_ky_nam_truoc,
        count(distinct n.ma_khach) filter (where n.nam = k.nam_nay and n.da_thanh_cong) as so_khach_thanh_cong_luy_ke,
        count(distinct n.ma_khach) filter (where n.nam = k.nam_nay - 1 and n.da_thanh_cong) as so_khach_thanh_cong_luy_ke_cung_ky_nam_truoc,
        count(distinct n.ma_khach) filter (where n.nam = k.nam_nay and n.nhom_md_ml = 'MD') as so_khach_den_cua_md_luy_ke,
        count(distinct n.ma_khach) filter (where n.nam = k.nam_nay and n.da_thanh_cong and n.nhom_md_ml = 'MD') as so_khach_thanh_cong_md_luy_ke
    from lk_khach_nguon n
    cross join ky k
    where n.nam in (k.nam_nay, k.nam_nay - 1)
      and n.thang <= k.thang_nay
    group by 1
),

-- (2026-09-27) Chỉ tiêu chi tiết lũy kế cho scorecard MD/ML dashboard "Tổng quan TH - 2026" — từ
-- ggs_target_company_source, đúng mapping Custom SQL Query4 của workbook "Bộ chỉ số kinh doanh":
--   id_nhom 2 (DS MKT) = MD, id_nhom 3 (DS nguồn CN) = ML (user chốt; khớp macro rtds_nhom_md_ml —
--   khối ❶ nguồn CN = ML), id_nhom 8 source 81/82 = số khách đến cửa / thành công (MD).
-- Chỉ lấy target_type = 'business_indicator' (bỏ dòng 'mkt_cvr' chi tiết theo dịch vụ).
-- Lũy kế CHỈ có giá trị khi ĐỦ mọi tháng T1 → tháng hiện tại (user chốt: thiếu tháng → "Chưa có chỉ
-- tiêu"). Hiện chỉ Kangnam đủ; Paris chỉ T1-T3, Hồng Hà rời rạc, THV không có. Kangnam: MD + ML
-- ≈ 93-96% target tổng (phần còn lại thuộc nhóm khác) — user chốt giữ đúng số được giao.
lk_target_ct_thang as (
    select
        t.brand,
        extract(month from t.time)::int as thang,
        sum(t.target_fixed) filter (where t.id_nhom = 2) as target_md,
        sum(t.target_fixed) filter (where t.id_nhom = 3) as target_ml,
        sum(t.target_fixed) filter (where t.id_nhom = 8 and t.source_id = 81) as target_khach_den_cua_md,
        sum(t.target_fixed) filter (where t.id_nhom = 8 and t.source_id = 82) as target_khach_thanh_cong_md
    from {{ ref('stg_rtds_ggs_target_company_source') }} t
    cross join ky k
    where t.active
      and t.target_type = 'business_indicator'
      and extract(year from t.time)::int = k.nam_nay
      and extract(month from t.time)::int <= k.thang_nay
    group by 1, 2
),

lk_target_ct as (
    select
        t.brand,
        case when count(t.target_md) = max(k.thang_nay) then sum(t.target_md) end as target_md_luy_ke,
        case when count(t.target_ml) = max(k.thang_nay) then sum(t.target_ml) end as target_ml_luy_ke,
        case when count(t.target_khach_den_cua_md) = max(k.thang_nay) then sum(t.target_khach_den_cua_md) end as target_khach_den_cua_md_luy_ke,
        case when count(t.target_khach_thanh_cong_md) = max(k.thang_nay) then sum(t.target_khach_thanh_cong_md) end as target_khach_thanh_cong_md_luy_ke
    from lk_target_ct_thang t
    cross join ky k
    group by 1
),

lk_brand as (
    select
        coalesce(d.brand, c.brand) as brand,
        d.doanh_so_luy_ke, d.doanh_so_luy_ke_cung_ky_nam_truoc, d.target_luy_ke,
        c.so_khach_den_cua_luy_ke, c.so_khach_den_cua_luy_ke_cung_ky_nam_truoc,
        c.so_khach_thanh_cong_luy_ke, c.so_khach_thanh_cong_luy_ke_cung_ky_nam_truoc,
        d.doanh_so_md_luy_ke, d.doanh_so_ml_luy_ke,
        tc.target_md_luy_ke, tc.target_ml_luy_ke,
        c.so_khach_den_cua_md_luy_ke,
        c.so_khach_den_cua_luy_ke - c.so_khach_den_cua_md_luy_ke as so_khach_den_cua_ml_luy_ke,
        c.so_khach_thanh_cong_md_luy_ke,
        c.so_khach_thanh_cong_luy_ke - c.so_khach_thanh_cong_md_luy_ke as so_khach_thanh_cong_ml_luy_ke,
        tc.target_khach_den_cua_md_luy_ke,
        tc.target_khach_thanh_cong_md_luy_ke
    from lk_doanh_so d
    full outer join lk_khach c on c.brand = d.brand
    left join lk_target_ct tc on tc.brand = coalesce(d.brand, c.brand)
),

-- HCI Group lũy kế: cùng quy tắc với dòng tháng — doanh số/target chỉ khi đủ 4 brand; khách = tổng
-- Kangnam + Paris + Hồng Hà (đủ cả 3, không cộng THV). Mã khách có kèm brand nên cộng giữa các brand
-- không bị trùng. ⚠ Thứ tự cột lk_hci PHẢI khớp lk_brand (lk_all union theo vị trí).
lk_hci as (
    select
        case when count(doanh_so_luy_ke) = 4 then sum(doanh_so_luy_ke) end as doanh_so_luy_ke,
        case when count(doanh_so_luy_ke_cung_ky_nam_truoc) = 4 then sum(doanh_so_luy_ke_cung_ky_nam_truoc) end as doanh_so_luy_ke_cung_ky_nam_truoc,
        case when count(target_luy_ke) = 4 then sum(target_luy_ke) end as target_luy_ke,
        case when count(so_khach_den_cua_luy_ke) filter (where brand in ('Kangnam','Paris','Hồng Hà')) = 3
             then sum(so_khach_den_cua_luy_ke) filter (where brand in ('Kangnam','Paris','Hồng Hà')) end as so_khach_den_cua_luy_ke,
        case when count(so_khach_den_cua_luy_ke_cung_ky_nam_truoc) filter (where brand in ('Kangnam','Paris','Hồng Hà')) = 3
             then sum(so_khach_den_cua_luy_ke_cung_ky_nam_truoc) filter (where brand in ('Kangnam','Paris','Hồng Hà')) end as so_khach_den_cua_luy_ke_cung_ky_nam_truoc,
        case when count(so_khach_thanh_cong_luy_ke) filter (where brand in ('Kangnam','Paris','Hồng Hà')) = 3
             then sum(so_khach_thanh_cong_luy_ke) filter (where brand in ('Kangnam','Paris','Hồng Hà')) end as so_khach_thanh_cong_luy_ke,
        case when count(so_khach_thanh_cong_luy_ke_cung_ky_nam_truoc) filter (where brand in ('Kangnam','Paris','Hồng Hà')) = 3
             then sum(so_khach_thanh_cong_luy_ke_cung_ky_nam_truoc) filter (where brand in ('Kangnam','Paris','Hồng Hà')) end as so_khach_thanh_cong_luy_ke_cung_ky_nam_truoc,
        case when count(doanh_so_md_luy_ke) = 4 then sum(doanh_so_md_luy_ke) end as doanh_so_md_luy_ke,
        case when count(doanh_so_ml_luy_ke) = 4 then sum(doanh_so_ml_luy_ke) end as doanh_so_ml_luy_ke,
        case when count(target_md_luy_ke) = 4 then sum(target_md_luy_ke) end as target_md_luy_ke,
        case when count(target_ml_luy_ke) = 4 then sum(target_ml_luy_ke) end as target_ml_luy_ke,
        case when count(so_khach_den_cua_md_luy_ke) filter (where brand in ('Kangnam','Paris','Hồng Hà')) = 3
             then sum(so_khach_den_cua_md_luy_ke) filter (where brand in ('Kangnam','Paris','Hồng Hà')) end as so_khach_den_cua_md_luy_ke,
        case when count(so_khach_den_cua_ml_luy_ke) filter (where brand in ('Kangnam','Paris','Hồng Hà')) = 3
             then sum(so_khach_den_cua_ml_luy_ke) filter (where brand in ('Kangnam','Paris','Hồng Hà')) end as so_khach_den_cua_ml_luy_ke,
        case when count(so_khach_thanh_cong_md_luy_ke) filter (where brand in ('Kangnam','Paris','Hồng Hà')) = 3
             then sum(so_khach_thanh_cong_md_luy_ke) filter (where brand in ('Kangnam','Paris','Hồng Hà')) end as so_khach_thanh_cong_md_luy_ke,
        case when count(so_khach_thanh_cong_ml_luy_ke) filter (where brand in ('Kangnam','Paris','Hồng Hà')) = 3
             then sum(so_khach_thanh_cong_ml_luy_ke) filter (where brand in ('Kangnam','Paris','Hồng Hà')) end as so_khach_thanh_cong_ml_luy_ke,
        case when count(target_khach_den_cua_md_luy_ke) filter (where brand in ('Kangnam','Paris','Hồng Hà')) = 3
             then sum(target_khach_den_cua_md_luy_ke) filter (where brand in ('Kangnam','Paris','Hồng Hà')) end as target_khach_den_cua_md_luy_ke,
        case when count(target_khach_thanh_cong_md_luy_ke) filter (where brand in ('Kangnam','Paris','Hồng Hà')) = 3
             then sum(target_khach_thanh_cong_md_luy_ke) filter (where brand in ('Kangnam','Paris','Hồng Hà')) end as target_khach_thanh_cong_md_luy_ke
    from lk_brand
),

lk_all as (
    select * from lk_brand
    union all
    select 'HCI Group' as brand, * from lk_hci
)

-- (2026-09-27) Cột lũy kế MD/ML: chỉ có giá trị trên dòng 'Lũy kế cùng kỳ' (dòng tháng/HCI Group =
-- NULL qua macro rtds_cot_luy_ke_md_ml_null). target_khach_*_ml_luy_ke, chi_phi_ads_luy_ke: CHƯA có
-- nguồn → NULL giữ chỗ để Tableau dựng sẵn scorecard Tổng quan ("Chưa có chỉ tiêu", Chi phí ads,
-- ROAS = doanh_so_luy_ke / chi_phi_ads_luy_ke) — khi có nguồn chỉ cần sửa dbt.
select
    brand, nam, thang, chi_nhanh,
    tong_so_tien, target, so_khach_den_cua, so_khach_thanh_cong,
    doanh_so_md, doanh_so_ml,
    so_khach_den_cua_md, so_khach_den_cua_ml,
    so_khach_thanh_cong_md, so_khach_thanh_cong_ml,
    null::numeric as doanh_so_luy_ke, null::numeric as doanh_so_luy_ke_cung_ky_nam_truoc,
    null::numeric as target_luy_ke,
    null::bigint as so_khach_den_cua_luy_ke, null::bigint as so_khach_den_cua_luy_ke_cung_ky_nam_truoc,
    null::bigint as so_khach_thanh_cong_luy_ke, null::bigint as so_khach_thanh_cong_luy_ke_cung_ky_nam_truoc,
    {{ rtds_cot_luy_ke_md_ml_null() }}
from combined

union all

select
    'HCI Group' as brand, nam, thang, 'HCI Group' as chi_nhanh,
    tong_so_tien, target, so_khach_den_cua, so_khach_thanh_cong,
    doanh_so_md, doanh_so_ml,
    so_khach_den_cua_md, so_khach_den_cua_ml,
    so_khach_thanh_cong_md, so_khach_thanh_cong_ml,
    null::numeric as doanh_so_luy_ke, null::numeric as doanh_so_luy_ke_cung_ky_nam_truoc,
    null::numeric as target_luy_ke,
    null::bigint as so_khach_den_cua_luy_ke, null::bigint as so_khach_den_cua_luy_ke_cung_ky_nam_truoc,
    null::bigint as so_khach_thanh_cong_luy_ke, null::bigint as so_khach_thanh_cong_luy_ke_cung_ky_nam_truoc,
    {{ rtds_cot_luy_ke_md_ml_null() }}
from hci_group

union all

select
    l.brand, k.nam_nay as nam, k.thang_nay as thang, 'Lũy kế cùng kỳ' as chi_nhanh,
    null::numeric as tong_so_tien, null::numeric as target,
    null::bigint as so_khach_den_cua, null::bigint as so_khach_thanh_cong,
    null::numeric as doanh_so_md, null::numeric as doanh_so_ml,
    null::bigint as so_khach_den_cua_md, null::bigint as so_khach_den_cua_ml,
    null::bigint as so_khach_thanh_cong_md, null::bigint as so_khach_thanh_cong_ml,
    l.doanh_so_luy_ke, l.doanh_so_luy_ke_cung_ky_nam_truoc, l.target_luy_ke,
    l.so_khach_den_cua_luy_ke, l.so_khach_den_cua_luy_ke_cung_ky_nam_truoc,
    l.so_khach_thanh_cong_luy_ke, l.so_khach_thanh_cong_luy_ke_cung_ky_nam_truoc,
    l.doanh_so_md_luy_ke::numeric, l.doanh_so_ml_luy_ke::numeric,
    l.target_md_luy_ke::numeric, l.target_ml_luy_ke::numeric,
    l.so_khach_den_cua_md_luy_ke::bigint, l.so_khach_den_cua_ml_luy_ke::bigint,
    l.so_khach_thanh_cong_md_luy_ke::bigint, l.so_khach_thanh_cong_ml_luy_ke::bigint,
    l.target_khach_den_cua_md_luy_ke::numeric, null::numeric as target_khach_den_cua_ml_luy_ke,
    l.target_khach_thanh_cong_md_luy_ke::numeric, null::numeric as target_khach_thanh_cong_ml_luy_ke,
    null::numeric as chi_phi_ads_luy_ke
from lk_all l
cross join ky k

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
--     theo nguồn CRM). *_md + *_ml = tổng (nhóm "Khác" tính vào ML). (2026-09-28) Kangnam/Paris: sản phẩm
--     tách cột *_sp → *_md + *_ml + *_sp = tổng.
--
-- Thiết kế CỐ TÌNH tránh Tableau Relationship/LOD: mọi phép gộp (kể cả dòng "HCI Group") đã tính
-- SẴN trong SQL này. "HCI Group" = tổng 4 thương hiệu, CHỈ tính khi CẢ 4 thương hiệu cùng có giá trị
-- ở đúng field đó tháng đó (quy tắc computeGroup() của data_demo/dashboard.html) — tính riêng cho
-- tong_so_tien và target (2 field độc lập).
--
-- (2026-09-15) so_khach_den_cua/so_khach_thanh_cong từ report_rtds_khach_hang_den_cua_thanh_cong
-- (Kangnam/Paris từ report_crm_lead_customer_out_sold + Hồng Hà/THV từ crm_lead) — xem LOGIC.md mục 4f.
-- ⚠ Rule "HCI Group" cho field khách hàng: (2026-09-29) = Kangnam + Paris + Hồng Hà + THV, điều kiện cần ĐỦ
-- KN + PR + HH (THV mới hoạt động từ 2026-01-15 — tháng/năm chưa có THV vẫn ra số, không mất YoY). User chốt.

{{ config(materialized='table') }}

-- Khoá join chi nhánh dùng coalesce(chi_nhanh, '') vì FULL JOIN không hỗ trợ IS NOT DISTINCT FROM.
with revenue as (
    select
        brand, nam, thang, coalesce(chi_nhanh, '') as cn,
        sum(tong_so_tien) as tong_so_tien,
        sum(tong_so_tien) filter (where nhom_md_ml = 'MD') as doanh_so_md,
        sum(tong_so_tien) filter (where nhom_md_ml = 'ML') as doanh_so_ml,
        -- (2026-09-28) Doanh số sản phẩm KN/PR (nhóm 'SAN PHAM') tách riêng, không thuộc MD/ML
        sum(tong_so_tien) filter (where nhom_md_ml = 'SP') as doanh_so_sp
    from {{ ref('report_rtds_doanh_so_thang_tableau') }}
    group by 1, 2, 3, 4
),

-- (2026-09-28) Thêm target chi tiết THEO THÁNG × chi nhánh từ ggs_target_company_source (user chốt):
--   target_md = id_nhom 2 (DS MKT) + target_ml = id_nhom 3 (DS nguồn CN) — target_type 'business_indicator'
--   (cùng mapping dòng lũy kế lk_target_ct_thang); target_sp = id_nhom 100 'DS Sản phẩm' (target_type
--   'cosmetic') — đi cặp doanh_so_sp. Chi nhánh = m_res_company.name theo (company_id, brand_id) như
--   report_rtds_target_thang_tableau. Hiện: Kangnam đủ 9 chi nhánh × 12 tháng (MD/ML/SP); Paris MD/ML T1-T3;
--   Hồng Hà MD/ML 1 tháng; THV không có. MD + ML ≈ 93-96% target tổng (phần còn lại thuộc nhóm khác).
target as (
    select brand, nam, thang, cn,
        sum(target) as target,
        sum(target_md) as target_md,
        sum(target_ml) as target_ml,
        sum(target_sp) as target_sp
    from (
        select brand, nam, thang, coalesce(chi_nhanh, '') as cn, target,
               null::numeric as target_md, null::numeric as target_ml, null::numeric as target_sp
        from {{ ref('report_rtds_target_thang_tableau') }}
        where nam = 2026
        union all
        select
            t.brand,
            extract(year from t.time)::int as nam,
            extract(month from t.time)::int as thang,
            coalesce(mrc.name, t.company, '') as cn,
            null::numeric as target,
            case when t.id_nhom = 2 and t.target_type = 'business_indicator' then t.target_fixed end as target_md,
            case when t.id_nhom = 3 and t.target_type = 'business_indicator' then t.target_fixed end as target_ml,
            case when t.id_nhom = 100 then t.target_fixed end as target_sp
        from {{ ref('stg_rtds_ggs_target_company_source') }} t
        left join {{ ref('stg_rtds_m_res_company') }} mrc
               on mrc.id = {{ rtds_company_id_gop('t.company_id', 't.time', 't.brand_id') }}  -- (2026-09-29) Gộp chi nhánh theo var rtds_gop_chi_nhanh (BV Thẩm mỹ KN 12 → KN Sài Gòn 4 từ 01/08/2026)
              and mrc.brand_etl = t.brand_id
        where t.active
          and extract(year from t.time)::int = 2026
          and ((t.id_nhom in (2, 3) and t.target_type = 'business_indicator') or t.id_nhom = 100)
    ) u
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
        sum(so_khach_thanh_cong) filter (where nhom_md_ml = 'ML') as so_khach_thanh_cong_ml,
        -- (2026-09-28) Khách chỉ mua sản phẩm (KN/PR) tách riêng, không thuộc MD/ML
        sum(so_khach_den_cua) filter (where nhom_md_ml = 'SP') as so_khach_den_cua_sp,
        sum(so_khach_thanh_cong) filter (where nhom_md_ml = 'SP') as so_khach_thanh_cong_sp
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
        c.so_khach_thanh_cong_ml,
        r.doanh_so_sp,
        c.so_khach_den_cua_sp,
        c.so_khach_thanh_cong_sp,
        t.target_md,
        t.target_ml,
        t.target_sp
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
        sum(so_khach_thanh_cong_ml) as so_khach_thanh_cong_ml,
        sum(doanh_so_sp) as doanh_so_sp,
        sum(so_khach_den_cua_sp) as so_khach_den_cua_sp,
        sum(so_khach_thanh_cong_sp) as so_khach_thanh_cong_sp,
        sum(target_md) as target_md,
        sum(target_ml) as target_ml,
        sum(target_sp) as target_sp
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
        case when count(tong_so_tien) = 4 then sum(doanh_so_ml) end as doanh_so_ml,
        case when count(tong_so_tien) = 4 then sum(doanh_so_sp) end as doanh_so_sp,
        -- target chi tiết: chỉ khi ĐỦ 4 brand cùng có (cùng quy tắc dòng lũy kế) — hiện luôn NULL vì chỉ Kangnam đủ
        case when count(target_md) = 4 then sum(target_md) end as target_md,
        case when count(target_ml) = 4 then sum(target_ml) end as target_ml,
        case when count(target_sp) = 4 then sum(target_sp) end as target_sp
    from brand_total
    group by nam, thang
),

-- (2026-09-29) User chốt: chỉ số KHÔNG phải chỉ tiêu cộng cả THV → khách HCI Group = KN + PR + HH + THV. Điều kiện
-- vẫn cần ĐỦ KN + PR + HH (THV mới từ 2026 — tháng thiếu THV như 2025 vẫn có số, THV tính 0).
hci_group_customer as (
    select
        nam,
        thang,
        case when count(so_khach_den_cua) filter (where brand in ('Kangnam', 'Paris', 'Hồng Hà')) = 3 then sum(so_khach_den_cua) end as so_khach_den_cua,
        case when count(so_khach_thanh_cong) filter (where brand in ('Kangnam', 'Paris', 'Hồng Hà')) = 3 then sum(so_khach_thanh_cong) end as so_khach_thanh_cong,
        case when count(so_khach_den_cua) filter (where brand in ('Kangnam', 'Paris', 'Hồng Hà')) = 3 then sum(so_khach_den_cua_md) end as so_khach_den_cua_md,
        case when count(so_khach_den_cua) filter (where brand in ('Kangnam', 'Paris', 'Hồng Hà')) = 3 then sum(so_khach_den_cua_ml) end as so_khach_den_cua_ml,
        case when count(so_khach_thanh_cong) filter (where brand in ('Kangnam', 'Paris', 'Hồng Hà')) = 3 then sum(so_khach_thanh_cong_md) end as so_khach_thanh_cong_md,
        case when count(so_khach_thanh_cong) filter (where brand in ('Kangnam', 'Paris', 'Hồng Hà')) = 3 then sum(so_khach_thanh_cong_ml) end as so_khach_thanh_cong_ml,
        case when count(so_khach_den_cua) filter (where brand in ('Kangnam', 'Paris', 'Hồng Hà')) = 3 then sum(so_khach_den_cua_sp) end as so_khach_den_cua_sp,
        case when count(so_khach_thanh_cong) filter (where brand in ('Kangnam', 'Paris', 'Hồng Hà')) = 3 then sum(so_khach_thanh_cong_sp) end as so_khach_thanh_cong_sp
    from brand_total
    group by nam, thang
),

-- (2026-09-29) Chi phí ads THEO THÁNG (user chốt đưa vào bảng này): int_rtds_chi_phi_ads chỉ có brand × tháng × kênh
-- (không có chi nhánh) → mỗi brand × tháng 1 dòng riêng chi_nhanh = 'Tổng brand' (các cột khác NULL); HCI Group =
-- KN + PR + HH + THV (chỉ khi tháng đó có đủ KN + PR). ROAS tháng trên Tableau = SUM(doanh_so_md) / SUM(chi_phi_ads).
ads_thang as (
    select brand, nam, thang, sum(chi_phi_ads) as chi_phi_ads
    from {{ ref('int_rtds_chi_phi_ads') }}
    group by 1, 2, 3
    having sum(chi_phi_ads) <> 0
),

ads_hci as (
    select
        nam,
        thang,
        case when count(*) filter (where brand in ('Kangnam', 'Paris')) = 2 then sum(chi_phi_ads) end as chi_phi_ads
    from ads_thang
    group by 1, 2
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
        c.so_khach_thanh_cong_ml,
        r.doanh_so_sp,
        c.so_khach_den_cua_sp,
        c.so_khach_thanh_cong_sp,
        r.target_md,
        r.target_ml,
        r.target_sp,
        a.chi_phi_ads
    from hci_group_revenue r
    full outer join hci_group_customer c on r.nam = c.nam and r.thang = c.thang
    left join ads_hci a on a.nam = coalesce(r.nam, c.nam) and a.thang = coalesce(r.thang, c.thang)
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
        sum(b.doanh_so_ml) filter (where b.nam = k.nam_nay) as doanh_so_ml_luy_ke,
        sum(b.doanh_so_sp) filter (where b.nam = k.nam_nay) as doanh_so_sp_luy_ke
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

-- Khách MD lũy kế = khách có ≥1 booking nguồn MD trong kỳ; (2026-09-28) ML = khách có booking dịch vụ
-- (nhom_md_ml <> 'SP') − MD; SP = tổng − khách có booking dịch vụ (tính ở lk_brand, cùng quy ước với
-- report_rtds_khach_hang_den_cua_thanh_cong) → MD + ML + SP = tổng.
lk_khach as (
    select
        n.brand,
        count(distinct n.ma_khach) filter (where n.nam = k.nam_nay) as so_khach_den_cua_luy_ke,
        count(distinct n.ma_khach) filter (where n.nam = k.nam_nay - 1) as so_khach_den_cua_luy_ke_cung_ky_nam_truoc,
        count(distinct n.ma_khach) filter (where n.nam = k.nam_nay and n.da_thanh_cong) as so_khach_thanh_cong_luy_ke,
        count(distinct n.ma_khach) filter (where n.nam = k.nam_nay - 1 and n.da_thanh_cong) as so_khach_thanh_cong_luy_ke_cung_ky_nam_truoc,
        count(distinct n.ma_khach) filter (where n.nam = k.nam_nay and n.nhom_md_ml = 'MD') as so_khach_den_cua_md_luy_ke,
        count(distinct n.ma_khach) filter (where n.nam = k.nam_nay and n.da_thanh_cong and n.nhom_md_ml = 'MD') as so_khach_thanh_cong_md_luy_ke,
        count(distinct n.ma_khach) filter (where n.nam = k.nam_nay and n.nhom_md_ml <> 'SP') as so_khach_den_cua_dv_luy_ke,
        count(distinct n.ma_khach) filter (where n.nam = k.nam_nay and n.da_thanh_cong and n.nhom_md_ml <> 'SP') as so_khach_thanh_cong_dv_luy_ke
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
        sum(t.target_fixed) filter (where t.id_nhom = 8 and t.source_id = 82) as target_khach_thanh_cong_md,
        sum(t.target_fixed) filter (where t.id_nhom = 100) as target_sp
    from {{ ref('stg_rtds_ggs_target_company_source') }} t
    cross join ky k
    where t.active
      and (t.target_type = 'business_indicator' or t.id_nhom = 100)  -- (2026-09-28) + target SP (type 'cosmetic')
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
        case when count(t.target_khach_thanh_cong_md) = max(k.thang_nay) then sum(t.target_khach_thanh_cong_md) end as target_khach_thanh_cong_md_luy_ke,
        case when count(t.target_sp) = max(k.thang_nay) then sum(t.target_sp) end as target_sp_luy_ke
    from lk_target_ct_thang t
    cross join ky k
    group by 1
),

-- (2026-09-28) Chi phí ads lũy kế T1 → tháng hiện tại (int_rtds_chi_phi_ads: Kangnam, Paris, Hồng Hà,
-- THV). User chốt (phương án 1a): CHỈ tính các tháng CÓ chi phí ads (> 0) — tử số ROAS
-- (doanh_so_md_roas_luy_ke) cũng chỉ cộng DS MD của đúng các tháng đó, để ROAS không bị thổi phồng khi
-- nguồn ads thiếu tháng (Hồng Hà/THV chỉ có từ T9/2026). KN/PR có ads đủ mọi tháng → không đổi.
-- ads_tu_thang = tháng đầu tiên có chi phí ads trong kỳ (Tableau ghi chú "tính từ T..").
lk_ads_thang as (
    select a.brand, a.thang, sum(a.chi_phi_ads) as chi_phi_ads
    from {{ ref('int_rtds_chi_phi_ads') }} a
    cross join ky k
    where a.nam = k.nam_nay
      and a.thang <= k.thang_nay
    group by 1, 2
    having sum(a.chi_phi_ads) > 0
),

lk_ads as (
    select
        a.brand,
        sum(a.chi_phi_ads) as chi_phi_ads_luy_ke,
        sum(b.doanh_so_md) as doanh_so_md_roas_luy_ke,
        min(a.thang) as ads_tu_thang
    from lk_ads_thang a
    cross join ky k
    left join brand_total b on b.brand = a.brand and b.nam = k.nam_nay and b.thang = a.thang
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
        c.so_khach_den_cua_dv_luy_ke - c.so_khach_den_cua_md_luy_ke as so_khach_den_cua_ml_luy_ke,
        c.so_khach_thanh_cong_md_luy_ke,
        c.so_khach_thanh_cong_dv_luy_ke - c.so_khach_thanh_cong_md_luy_ke as so_khach_thanh_cong_ml_luy_ke,
        tc.target_khach_den_cua_md_luy_ke,
        tc.target_khach_thanh_cong_md_luy_ke,
        ads.chi_phi_ads_luy_ke,
        -- Tử số ROAS: DS MD các tháng CÓ chi phí ads (brand chưa có nguồn ads → NULL)
        ads.doanh_so_md_roas_luy_ke,
        ads.ads_tu_thang,
        -- (2026-09-28) Sản phẩm lũy kế (KN/PR) — không thuộc MD/ML
        d.doanh_so_sp_luy_ke,
        c.so_khach_den_cua_luy_ke - c.so_khach_den_cua_dv_luy_ke as so_khach_den_cua_sp_luy_ke,
        c.so_khach_thanh_cong_luy_ke - c.so_khach_thanh_cong_dv_luy_ke as so_khach_thanh_cong_sp_luy_ke,
        tc.target_sp_luy_ke
    from lk_doanh_so d
    full outer join lk_khach c on c.brand = d.brand
    left join lk_target_ct tc on tc.brand = coalesce(d.brand, c.brand)
    left join lk_ads ads on ads.brand = coalesce(d.brand, c.brand)
),

-- HCI Group lũy kế: cùng quy tắc với dòng tháng — doanh số/target chỉ khi đủ 4 brand; khách = tổng
-- (2026-09-29) KN + PR + HH + THV (cần đủ KN + PR + HH; target khách vẫn chỉ KN + PR + HH). Mã khách có kèm brand nên cộng giữa các brand
-- không bị trùng. ⚠ Thứ tự cột lk_hci PHẢI khớp lk_brand (lk_all union theo vị trí).
lk_hci as (
    select
        case when count(doanh_so_luy_ke) = 4 then sum(doanh_so_luy_ke) end as doanh_so_luy_ke,
        case when count(doanh_so_luy_ke_cung_ky_nam_truoc) = 4 then sum(doanh_so_luy_ke_cung_ky_nam_truoc) end as doanh_so_luy_ke_cung_ky_nam_truoc,
        case when count(target_luy_ke) = 4 then sum(target_luy_ke) end as target_luy_ke,
        case when count(so_khach_den_cua_luy_ke) filter (where brand in ('Kangnam','Paris','Hồng Hà')) = 3
             then sum(so_khach_den_cua_luy_ke) end as so_khach_den_cua_luy_ke,
        case when count(so_khach_den_cua_luy_ke_cung_ky_nam_truoc) filter (where brand in ('Kangnam','Paris','Hồng Hà')) = 3
             then sum(so_khach_den_cua_luy_ke_cung_ky_nam_truoc) end as so_khach_den_cua_luy_ke_cung_ky_nam_truoc,
        case when count(so_khach_thanh_cong_luy_ke) filter (where brand in ('Kangnam','Paris','Hồng Hà')) = 3
             then sum(so_khach_thanh_cong_luy_ke) end as so_khach_thanh_cong_luy_ke,
        case when count(so_khach_thanh_cong_luy_ke_cung_ky_nam_truoc) filter (where brand in ('Kangnam','Paris','Hồng Hà')) = 3
             then sum(so_khach_thanh_cong_luy_ke_cung_ky_nam_truoc) end as so_khach_thanh_cong_luy_ke_cung_ky_nam_truoc,
        case when count(doanh_so_md_luy_ke) = 4 then sum(doanh_so_md_luy_ke) end as doanh_so_md_luy_ke,
        case when count(doanh_so_ml_luy_ke) = 4 then sum(doanh_so_ml_luy_ke) end as doanh_so_ml_luy_ke,
        case when count(target_md_luy_ke) = 4 then sum(target_md_luy_ke) end as target_md_luy_ke,
        case when count(target_ml_luy_ke) = 4 then sum(target_ml_luy_ke) end as target_ml_luy_ke,
        case when count(so_khach_den_cua_md_luy_ke) filter (where brand in ('Kangnam','Paris','Hồng Hà')) = 3
             then sum(so_khach_den_cua_md_luy_ke) end as so_khach_den_cua_md_luy_ke,
        case when count(so_khach_den_cua_ml_luy_ke) filter (where brand in ('Kangnam','Paris','Hồng Hà')) = 3
             then sum(so_khach_den_cua_ml_luy_ke) end as so_khach_den_cua_ml_luy_ke,
        case when count(so_khach_thanh_cong_md_luy_ke) filter (where brand in ('Kangnam','Paris','Hồng Hà')) = 3
             then sum(so_khach_thanh_cong_md_luy_ke) end as so_khach_thanh_cong_md_luy_ke,
        case when count(so_khach_thanh_cong_ml_luy_ke) filter (where brand in ('Kangnam','Paris','Hồng Hà')) = 3
             then sum(so_khach_thanh_cong_ml_luy_ke) end as so_khach_thanh_cong_ml_luy_ke,
        case when count(target_khach_den_cua_md_luy_ke) filter (where brand in ('Kangnam','Paris','Hồng Hà')) = 3
             then sum(target_khach_den_cua_md_luy_ke) filter (where brand in ('Kangnam','Paris','Hồng Hà')) end as target_khach_den_cua_md_luy_ke,
        case when count(target_khach_thanh_cong_md_luy_ke) filter (where brand in ('Kangnam','Paris','Hồng Hà')) = 3
             then sum(target_khach_thanh_cong_md_luy_ke) filter (where brand in ('Kangnam','Paris','Hồng Hà')) end as target_khach_thanh_cong_md_luy_ke,
        -- Chi phí ads / tử số ROAS HCI Group: (2026-09-29) user chốt cộng CẢ 4 brand (KN + PR + HH + THV — HH/THV
        -- chỉ các tháng có ads, hiện từ T9/2026), vẫn cần đủ KN + PR. ads_tu_thang = tháng sớm nhất.
        case when count(chi_phi_ads_luy_ke) filter (where brand in ('Kangnam','Paris')) = 2
             then sum(chi_phi_ads_luy_ke) end as chi_phi_ads_luy_ke,
        case when count(doanh_so_md_roas_luy_ke) filter (where brand in ('Kangnam','Paris')) = 2
             then sum(doanh_so_md_roas_luy_ke) end as doanh_so_md_roas_luy_ke,
        case when count(chi_phi_ads_luy_ke) filter (where brand in ('Kangnam','Paris')) = 2
             then min(ads_tu_thang) end as ads_tu_thang,
        case when count(doanh_so_luy_ke) = 4 then sum(doanh_so_sp_luy_ke) end as doanh_so_sp_luy_ke,
        case when count(so_khach_den_cua_sp_luy_ke) filter (where brand in ('Kangnam','Paris','Hồng Hà')) = 3
             then sum(so_khach_den_cua_sp_luy_ke) end as so_khach_den_cua_sp_luy_ke,
        case when count(so_khach_thanh_cong_sp_luy_ke) filter (where brand in ('Kangnam','Paris','Hồng Hà')) = 3
             then sum(so_khach_thanh_cong_sp_luy_ke) end as so_khach_thanh_cong_sp_luy_ke,
        case when count(target_sp_luy_ke) = 4 then sum(target_sp_luy_ke) end as target_sp_luy_ke
    from lk_brand
),

lk_all as (
    select * from lk_brand
    union all
    select 'HCI Group' as brand, * from lk_hci
)

-- (2026-09-27) Cột lũy kế MD/ML: chỉ có giá trị trên dòng 'Lũy kế cùng kỳ' (dòng tháng/HCI Group =
-- NULL qua macro rtds_cot_luy_ke_md_ml_null). target_khach_*_ml_luy_ke: CHƯA có nguồn → NULL giữ chỗ
-- ("Chưa có chỉ tiêu"). (2026-09-28) chi_phi_ads_luy_ke từ int_rtds_chi_phi_ads (4 brand; HCI Group =
-- KN + PR). ROAS = doanh_so_md_roas_luy_ke / chi_phi_ads_luy_ke — tử số là DS MD của đúng các brand và
-- các THÁNG có chi phí ads (HCI Group = DS MD KN + PR). ads_tu_thang: tháng bắt đầu tính ads.
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
    {{ rtds_cot_luy_ke_md_ml_null() }},
    -- (2026-09-28) Sản phẩm (KN/PR) tách riêng khỏi MD/ML: tổng = MD + ML + SP. Cột SP đặt CUỐI bảng.
    doanh_so_sp, so_khach_den_cua_sp, so_khach_thanh_cong_sp,
    null::numeric as doanh_so_sp_luy_ke, null::bigint as so_khach_den_cua_sp_luy_ke,
    null::bigint as so_khach_thanh_cong_sp_luy_ke,
    -- (2026-09-28) target chi tiết theo tháng (MD/ML/SP) + target SP lũy kế — cột CUỐI bảng
    target_md, target_ml, target_sp,
    null::numeric as target_sp_luy_ke,
    null::numeric as chi_phi_ads  -- (2026-09-29) ads chỉ ở dòng 'Tổng brand' / HCI Group
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
    {{ rtds_cot_luy_ke_md_ml_null() }},
    doanh_so_sp, so_khach_den_cua_sp, so_khach_thanh_cong_sp,
    null::numeric as doanh_so_sp_luy_ke, null::bigint as so_khach_den_cua_sp_luy_ke,
    null::bigint as so_khach_thanh_cong_sp_luy_ke,
    -- (2026-09-28) target chi tiết theo tháng (MD/ML/SP) + target SP lũy kế — cột CUỐI bảng
    target_md, target_ml, target_sp,
    null::numeric as target_sp_luy_ke,
    chi_phi_ads
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
    l.chi_phi_ads_luy_ke::numeric,
    l.doanh_so_md_roas_luy_ke::numeric,
    l.ads_tu_thang::int,
    null::numeric as doanh_so_sp, null::bigint as so_khach_den_cua_sp, null::bigint as so_khach_thanh_cong_sp,
    l.doanh_so_sp_luy_ke::numeric, l.so_khach_den_cua_sp_luy_ke::bigint, l.so_khach_thanh_cong_sp_luy_ke::bigint,
    null::numeric as target_md, null::numeric as target_ml, null::numeric as target_sp,
    l.target_sp_luy_ke::numeric,
    null::numeric as chi_phi_ads
from lk_all l
cross join ky k

union all

-- (2026-09-29) Dòng ads theo brand × tháng — chi_nhanh = 'Tổng brand', chỉ cột chi_phi_ads có giá trị
select
    a.brand, a.nam, a.thang, 'Tổng brand' as chi_nhanh,
    null::numeric as tong_so_tien, null::numeric as target,
    null::bigint as so_khach_den_cua, null::bigint as so_khach_thanh_cong,
    null::numeric as doanh_so_md, null::numeric as doanh_so_ml,
    null::bigint as so_khach_den_cua_md, null::bigint as so_khach_den_cua_ml,
    null::bigint as so_khach_thanh_cong_md, null::bigint as so_khach_thanh_cong_ml,
    null::numeric as doanh_so_luy_ke, null::numeric as doanh_so_luy_ke_cung_ky_nam_truoc,
    null::numeric as target_luy_ke,
    null::bigint as so_khach_den_cua_luy_ke, null::bigint as so_khach_den_cua_luy_ke_cung_ky_nam_truoc,
    null::bigint as so_khach_thanh_cong_luy_ke, null::bigint as so_khach_thanh_cong_luy_ke_cung_ky_nam_truoc,
    {{ rtds_cot_luy_ke_md_ml_null() }},
    null::numeric as doanh_so_sp, null::bigint as so_khach_den_cua_sp, null::bigint as so_khach_thanh_cong_sp,
    null::numeric as doanh_so_sp_luy_ke, null::bigint as so_khach_den_cua_sp_luy_ke,
    null::bigint as so_khach_thanh_cong_sp_luy_ke,
    null::numeric as target_md, null::numeric as target_ml, null::numeric as target_sp,
    null::numeric as target_sp_luy_ke,
    a.chi_phi_ads::numeric
from ads_thang a

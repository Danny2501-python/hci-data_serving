-- Chi phí chạy quảng cáo theo brand + tháng + kênh — cho scorecard "Chi phí ads" / "ROAS" (= DS MD /
-- chi phí ads) dashboard "Tổng quan TH - 2026" (user chốt 2026-09-28). Gồm CẢ tài khoản thương hiệu.
--
-- Kangnam — tự ghép (KHÔNG dùng report_marketing_ad_cost_kn_v2): report đó lấy legacy từ
-- stg_fb_insight_old_zero (không có dữ liệu 2026) + cs_facebook_insight (chỉ lưu từ 2026-04-07) → thiếu
-- trọn FB T1-T3/2026 (~12 tỷ). Ở đây:
--   - FB: legacy stg_fb_insight_old (trước ngày đầu tiên của nguồn mới) + cs_facebook_insight
--     brand_etl = 1 (từ 2026-04-07), loại 3 page như stg_frmack_fb_insight_v1/v2. Xem CTE kn_fb.
--   - Google: cp_google_kangnam, account IS NOT NULL, cost × 23.500 (USD → VND, như stg_frmack_google;
--     đã đối chiếu = cột vnd của bảng).
-- Paris — dùng lại output func_report_marketing_ad_cost_pr (report_marketing_ad_cost_pr_v2, đủ T1+ nhờ
-- legacy stg_fb_insight_old_pr): Cost_fb_cd + Cost_fb_th + google + tiktok, cột giá trị `dt` (text).
-- Hồng Hà / Tiêu Hóa Việt (2026-09-28) — Google Sheet ggs_target_ads_thv_hh (brand_etl 4 / 8): TỔNG chi
-- phí online ads theo ngày, không tách kênh → kenh = 'Online ads'. Chỉ có dữ liệu từ T9/2026.

{{ config(materialized='table') }}

with kn_fb_new as (
    select date::date as ngay_chi_phi, spend as chi_phi
    from {{ ref('stg_rtds_cs_facebook_insight') }}
    where brand_etl = 1
      and coalesce(facebook_page_id::text, '') not in ('805410602664141', '839493609256431', '948044848396128')
      -- [2026-10-07] Loại campaign Philippines 'sun_' – chi phí Sunwoo không tính cho Kangnam
      and coalesce(ad_campaign_name, '') not ilike 'sun\_%'
),

-- Cắt theo NGÀY (không anti-join theo khoá như stg_frmack_fb_insight_v3): legacy chỉ lấy TRƯỚC ngày đầu
-- tiên có dữ liệu mới. Đã đo 2026-09-28: 07→12/04/2026 cả 2 nguồn cùng có, legacy ghi THIẾU (VD 11/04
-- legacy 33,5 tr vs mới 143,5 tr) và khoá lệch nhau → anti-join vẫn cộng trùng ~31 tr trong T4.
kn_fb as (
    select ngay_chi_phi, chi_phi
    from {{ ref('stg_rtds_stg_fb_insight_old') }}
    where ngay_chi_phi >= '2025-01-01'
      and ngay_chi_phi < (select min(ngay_chi_phi) from kn_fb_new)
      and coalesce(page_id, '') not in ('805410602664141', '839493609256431', '948044848396128')
    union all
    select ngay_chi_phi, chi_phi from kn_fb_new
),

-- (2026-09-29) Paris Facebook CẮT THEO NGÀY giống Kangnam (user chốt, chỉ sửa trong báo cáo doanh số HCI):
-- report_marketing_ad_cost_pr_v2 CỘNG ĐÔI FB 07→12/04/2026 (legacy + nguồn mới, ≈ 2× raw, +156 tr T4) → lấy report
-- (Cost_fb_cd/th) cho ngày TRƯỚC ngày đầu có dữ liệu Paris trong cs_facebook_insight, từ ngày đó lấy raw
-- cs_facebook_insight brand_etl 3 (mọi page — đã đối chiếu = report từ 13/04 tới nay). Google/TikTok vẫn từ report.
pr_fb_new as (
    select date::date as ngay_chi_phi, spend as chi_phi
    from {{ ref('stg_rtds_cs_facebook_insight') }}
    where brand_etl = 3
),

pr_fb as (
    select "date"::date as ngay_chi_phi, dt::numeric as chi_phi
    from {{ ref('mart_report_marketing_ad_cost_pr') }}
    where type_data in ('Cost_fb_cd', 'Cost_fb_th')
      and "date" >= '2025-01-01'
      and "date"::date < (select min(ngay_chi_phi) from pr_fb_new)
      and dt ~ '^-?[0-9]+(\.[0-9]+)?([eE][-+]?[0-9]+)?$'
    union all
    select ngay_chi_phi, chi_phi::numeric from pr_fb_new
),

nguon as (
    select 'Kangnam' as brand, ngay_chi_phi as ngay, 'Facebook' as kenh, chi_phi::numeric as chi_phi
    from kn_fb

    union all

    select 'Kangnam', date::date, 'Google', (cost * 23500)::numeric
    from {{ ref('stg_rtds_cp_google_kangnam') }}
    where account is not null
      and date::date >= '2025-01-01'

    union all

    select 'Paris', ngay_chi_phi, 'Facebook', chi_phi from pr_fb

    union all

    select
        'Paris',
        "date"::date,
        case when type_data = 'google' then 'Google' else 'TikTok' end,
        dt::numeric
    from {{ ref('mart_report_marketing_ad_cost_pr') }}
    where type_data in ('google', 'tiktok')
      and "date" >= '2025-01-01'
      and dt ~ '^-?[0-9]+(\.[0-9]+)?([eE][-+]?[0-9]+)?$'

    union all

    select
        case brand_etl when 4 then 'Hồng Hà' when 8 then 'Tiêu Hóa Việt' end,
        ngay_chi_phi,
        'Online ads',
        chi_phi::numeric
    from {{ ref('stg_rtds_ggs_target_ads_thv_hh') }}
    where brand_etl in (4, 8)
      and ngay_chi_phi >= '2025-01-01'
)

select
    brand,
    extract(year from ngay)::int as nam,
    extract(month from ngay)::int as thang,
    kenh,
    sum(chi_phi) as chi_phi_ads
from nguon
group by 1, 2, 3, 4

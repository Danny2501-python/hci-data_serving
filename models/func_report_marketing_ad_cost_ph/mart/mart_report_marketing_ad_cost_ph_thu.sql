{{
  config(
    materialized = 'table',
    schema       = 'sandbox_ph',
    alias        = 'report_marketing_ad_cost_ph_thu',
    tags         = ['report_ph_thu', 'phi']
  )
}}
-- =============================================================================
-- mart_report_marketing_ad_cost_ph_thu — bảng chính + 4 cột tỷ giá ở dòng DS.
-- [2026-10-08] Bảng chính cũng đã dùng stg_frmacph_doanh_so_thu → doanh số 2 bảng như nhau.
-- Các type_data khác lấy nguyên từ bảng chính. 30 cột đầu giống bảng chính
-- (Tableau chỉ cần đổi bảng nguồn) + 4 cột tỷ giá ở cuối, chỉ có giá trị với dòng DS:
-- loai_tien, so_tien_goc, ngay_ty_gia, ty_gia.
-- Tag riêng 'report_ph_thu' → không chạy kèm khi build tag:report_ph.
-- =============================================================================
WITH crm AS (
    SELECT * FROM {{ ref('stg_frmacph_crm_base') }}
),
page_map AS (
    SELECT page_id, max(page_name) AS page_name FROM {{ ref('stg_frmacph_fb_cost') }} GROUP BY page_id
)

SELECT m.*,
    NULL::text    AS loai_tien,
    NULL::numeric AS so_tien_goc,
    NULL::date    AS ngay_ty_gia,
    NULL::numeric AS ty_gia
FROM {{ ref('mart_report_marketing_ad_cost_ph') }} m
WHERE m.type_data <> 'DS'

UNION ALL
-- ── DS – doanh số quy đổi VND (giống Stream 4 của bản chính) ────────────────
SELECT
    coalesce(c.vk, 'KXĐ'), coalesce(c.ten_dv, 'DV'), coalesce(c.nguon, 'KXĐ'), coalesce(c.nhom_nguon, 'KXĐ'),
    coalesce(c.kenh, 'Khác'),
    d.ngay,
    coalesce(c.nhom_dv, 'KXĐ'),
    coalesce(d.chi_nhanh, 'KXĐ'),
    coalesce(c.local_k, 'KXĐ'),
    coalesce(c.quoc_gia, 'KXĐ'),
    ccm.continent,
    d.doanh_so::text,
    'DS',
    coalesce(pc.page_name, pm.page_name, 'KXĐ'),
    coalesce(c.page_id, 'KXĐ'),
    coalesce(upper(ccm.continent), 'KXĐ'),
    coalesce(c.local_k, 'KXĐ'),
    coalesce(pc.campaign_name, 'KXĐ'),            -- campaign/account/actor/nhóm DV mục tiêu: từ quảng cáo
    coalesce(pc.account_fb, 'KXĐ'),               -- khách bấm vào (Pancake first_ad_id, 2026-10-08);
    coalesce(nullif(pc.actor_code, ''), 'KXĐ'),   -- không khớp Pancake → 'KXĐ' như trước
    coalesce(cnsp.nhom_dv, 'KXĐ'),
    'KXĐ', 'KXĐ', 'KXĐ',
    coalesce(c.nguon_moi_v2, 'KXĐ'),
    coalesce(c.nhom_nguon_moi_v2, 'KXĐ'),
    coalesce(tt.trang_thai_du_lieu, 'NGHI_TEST'),
    coalesce(tt.ly_do, 'Phiếu thu không gắn lead'),
    d.lead_id,
    'ERP PH brand 9',
    d.loai_tien,
    d.so_tien_goc,
    d.ngay_ty_gia,
    d.ty_gia
FROM {{ ref('stg_frmacph_doanh_so_thu') }} d
LEFT JOIN crm c                                     ON c.lead_id  = d.lead_id
LEFT JOIN {{ ref('stg_frmacph_trang_thai') }} tt    ON tt.lead_id = d.lead_id
LEFT JOIN page_map pm                               ON pm.page_id = c.page_id
LEFT JOIN {{ ref('stg_frmacph_pancake') }} pc          ON pc.conversation_id = c.conversation_id
LEFT JOIN LATERAL (     -- nhóm DV mục tiêu theo campaign khách bấm vào (giống Stream 1)
    SELECT nhom_dv FROM {{ ref('stg_frmacph_nhom_dv_map') }}   -- seed PH ưu tiên, rồi seed chung
    WHERE upper(campain_name_split) = upper(pc.nhom_dv_code) LIMIT 1
) cnsp ON TRUE
LEFT JOIN {{ ref('ucbt_country_continent') }} ccm   ON ccm.country = c.quoc_gia

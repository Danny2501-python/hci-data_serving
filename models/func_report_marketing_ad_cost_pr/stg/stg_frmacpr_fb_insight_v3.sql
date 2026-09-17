-- =============================================================================
-- stg_frmacpr_fb_insight_v3
-- Unified Facebook insight model for Paris using an Anti-join logic.
-- Logic:
--   1. Take ALL records from v1 (legacy source).
--   2. Take records from v2 (new source) ONLY if they don't exist in v1.
-- Keys: ad_account_id, fb_ad_ad_id, ngay, vung
-- =============================================================================
{{
  config(
    materialized = 'table',
    alias = 'stg_fb_insight_full_pr'
  )
}}

WITH v1 AS (
    SELECT * FROM {{ ref('stg_frmacpr_fb_insight_v1') }}
),
v2 AS (
    SELECT * FROM {{ ref('stg_frmacpr_fb_insight_v2') }}
),
v2_supplement AS (
    SELECT v2.*
    FROM v2
    WHERE NOT EXISTS (
        SELECT 1 
        FROM v1 
        WHERE v1.ad_account_id = v2.ad_account_id
          AND v1.fb_ad_ad_id   = v2.fb_ad_ad_id
          AND v1.ngay          = v2.ngay
          AND v1.vung          = v2.vung
    )
)

-- nguon_moi_v2/nhom_nguon_moi_v2: không có liên kết CRM để tra new_source_id,
-- nhưng cả nhánh này chỉ là chi phí quảng cáo Facebook -> mặc định cứng theo
-- catalog utm_source thật của Paris (id=731 'Facebook', category 'Online').
-- campaign/actor: v1 (nguồn stg_fb_insight_old_pr) không có cột campaign_name
-- nào (đã kiểm tra information_schema) -> luôn 'KXĐ'/NULL, giống cách
-- func_report_marketing_ad_cost_kn xử lý fb_insight_v1 legacy (README.md mục 7).
-- local_k_raw/page_id_raw/account_id_raw: thêm 2026-09-11, phục vụ cột
-- local_k/page/account_fb ở mart. v1 (nguồn legacy stg_fb_insight_old_pr) có
-- sẵn vung/ad_account_id (dùng làm key anti-join) nhưng KHÔNG có
-- facebook_page_id -> page_id_raw luôn NULL cho v1.
SELECT
    nguon, nhom_nguon, channel, ngay, metric, nhom_dv, chi_nhanh, type_data,
    'old' as data_origin,
    'Facebook'::text AS nguon_moi_v2, 'Online'::text AS nhom_nguon_moi_v2,
    'KXĐ'::text AS campaign, NULL::text AS actor_code,
    NULL::text AS nhom_dv_muc_tieu_code,
    NULL::text AS page_code_raw,
    vung AS local_k_raw, NULL::text AS page_id_raw, ad_account_id::text AS account_id_raw,
    -- vk/ten_dv/quoc_gia/nhom_dv_kh_quan_tam/nhom_dv_chinh_booking: FB Cost
    -- không có liên kết CRM -> luôn NULL.
    NULL::text AS vk, NULL::text AS ten_dv, NULL::text AS quoc_gia,
    NULL::text AS nhom_dv_kh_quan_tam, NULL::text AS nhom_dv_chinh_booking
FROM v1

UNION ALL

SELECT
    nguon, nhom_nguon, channel, ngay, metric, nhom_dv, chi_nhanh, type_data,
    'new' as data_origin,
    'Facebook'::text AS nguon_moi_v2, 'Online'::text AS nhom_nguon_moi_v2,
    campaign, actor_code,
    nhom_dv_muc_tieu_code,
    NULL::text AS page_code_raw,
    vung AS local_k_raw, page_id_raw, account_id_raw,
    NULL::text AS vk, NULL::text AS ten_dv, NULL::text AS quoc_gia,
    NULL::text AS nhom_dv_kh_quan_tam, NULL::text AS nhom_dv_chinh_booking
FROM v2_supplement

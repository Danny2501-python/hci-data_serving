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
SELECT
    nguon, nhom_nguon, channel, ngay, metric, nhom_dv, chi_nhanh, type_data,
    'old' as data_origin,
    'Facebook'::text AS nguon_moi_v2, 'Online'::text AS nhom_nguon_moi_v2
FROM v1

UNION ALL

SELECT
    nguon, nhom_nguon, channel, ngay, metric, nhom_dv, chi_nhanh, type_data,
    'new' as data_origin,
    'Facebook'::text AS nguon_moi_v2, 'Online'::text AS nhom_nguon_moi_v2
FROM v2_supplement

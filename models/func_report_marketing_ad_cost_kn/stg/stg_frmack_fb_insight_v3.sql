-- =============================================================================
-- stg_frmack_fb_insight_v3
-- Unified Facebook insight model using an Anti-join logic.
-- Logic: 
--   1. Take ALL records from v1 (the legacy, trusted source).
--   2. Take records from v2 (new source) ONLY if their key DOES NOT exist in v1.
-- Keys: ad_account_id, fb_ad_ad_id, ngay_chi_phi, vung
-- =============================================================================
WITH v1 AS (
    SELECT * FROM {{ ref('stg_frmack_fb_insight') }}
),
v2 AS (
    SELECT * FROM {{ ref('stg_frmack_fb_insight_v2') }}
),
v2_supplement AS (
    -- Get records from v2 that are NOT present in v1 based on the technical key
    SELECT v2.*
    FROM v2
    WHERE NOT EXISTS (
        SELECT 1 
        FROM v1 
        WHERE v1.ad_account_id = v2.ad_account_id
          AND v1.fb_ad_ad_id   = v2.fb_ad_ad_id
          AND v1.ngay_chi_phi = v2.ngay_chi_phi
          AND v1.vung         = v2.vung
    )
)
SELECT 
    chi_phi, ngay_chi_phi, vung, camp_name, cn, nhom_dv, nhom_dv2, 
    type_data, page_id, account_fb, chi_nhanh_no_camp
FROM v1

UNION ALL

SELECT 
    chi_phi, ngay_chi_phi, vung, camp_name, cn, nhom_dv, nhom_dv2, 
    type_data, page_id, account_fb, chi_nhanh_no_camp
FROM v2_supplement

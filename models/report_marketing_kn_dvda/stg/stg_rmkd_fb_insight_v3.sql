{{
  config(
    materialized = 'table'
  )
}}

-- stg_rmkd_fb_insight_v3: Hợp nhất v1 và v2 sử dụng Anti-join theo Key kỹ thuật
WITH v1 AS (
    SELECT * FROM {{ ref('stg_rmkd_fb_insight_v1') }}
),
v2 AS (
    SELECT * FROM {{ ref('stg_rmkd_fb_insight_v2') }}
),
v2_supplement AS (
    SELECT v2.*
    FROM v2
    WHERE NOT EXISTS (
        SELECT 1 FROM v1
        WHERE v1.ad_account_id = v2.ad_account_id
          AND v1.ad_id         = v2.ad_id
          AND v1.ngay_chi_phi  = v2.ngay_chi_phi
          AND v1.vung          = v2.vung
    )
)
SELECT *, 'legacy' AS source_version FROM v1
UNION ALL
SELECT *, 'cs_insight' AS source_version FROM v2_supplement


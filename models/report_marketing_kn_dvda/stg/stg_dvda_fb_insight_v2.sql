{{
  config(
    materialized = 'table'
  )
}}

-- stg_dvda_fb_insight_v2: Dữ liệu Facebook mới từ bảng cs_facebook_insight
SELECT
    f.spend                                                                       AS chi_phi,
    f.date                                                                        AS ngay_chi_phi,
    f.region                                                                      AS vung,
    f.ad_campaign_name                                                            AS camp_name,
    CASE WHEN f.ad_account_id NOT LIKE 'act_%' THEN 'act_' || f.ad_account_id 
         ELSE f.ad_account_id END                                                 AS ad_account_id,
    f.ad_id                                                                       AS ad_id,
    'Cost_fb_cd'                                                                  AS type_data
FROM {{ source('dvda', 'cs_facebook_insight') }} f
WHERE f.brand_etl = 1
  AND REPLACE(f.ad_account_id, 'act_', '') IN ('612830523394289', '4074283036142763')
  AND f.date >= '2025-01-01'
  AND TRIM(SPLIT_PART(f.ad_campaign_name, '_', 2)) IS NOT NULL

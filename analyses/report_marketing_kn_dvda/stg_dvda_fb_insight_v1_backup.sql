-- =============================================================================
-- stg_dvda_fb_insight_v1_backup
-- Backup of legacy Facebook insight logic for DVDA.
-- This logic was used to build the initial public.stg_dvda_fb_insight_v1 table.
-- =============================================================================

SELECT
    (CASE WHEN cfaai.fb_account_currency = 'USD'
          THEN cfaai.spend * tgt.bidrateck::double precision
          ELSE cfaai.spend end)                                                       AS chi_phi,
    cfaai."date"                                                                      AS ngay_chi_phi,
    cfaai.region                                                                      AS vung,
    cfac.name                                                                         AS camp_name,
    'act_' || cfaa2.ad_account_id                                                     AS ad_account_id,
    cfaai.fb_ad_ad_id                                                                 AS ad_id,
    'Cost_fb_cd'                                                                      AS type_data
FROM {{ source('rmkd', 'core_facebook_ad_ad_insight') }} cfaai
LEFT JOIN {{ source('rmkd', 'core_facebook_ad_ad') }}       cfaa  ON cfaa.fb_ad_ad_id       = cfaai.fb_ad_ad_id
LEFT JOIN {{ source('rmkd', 'core_facebook_ad_set') }}      cfas  ON cfas.fb_ad_set_id      = cfaa.fb_ad_set_id
LEFT JOIN {{ source('rmkd', 'core_facebook_ad_campaign') }} cfac  ON cfac.fb_ad_campaign_id = cfas.fb_ad_campaign_id
LEFT JOIN {{ source('rmkd', 'core_facebook_ad_account') }}  cfaa2 ON cfaa2.ad_account_id   = cfac.fb_ad_account_id
LEFT JOIN LATERAL (
    SELECT bidrateck
    FROM {{ source('rmkd', 'ty_gia_techcombank') }} t
    WHERE t."label" = 'USD (50,100)' AND cfaai."date" >= t."date"
    ORDER BY t.date DESC LIMIT 1
) tgt ON TRUE
WHERE REPLACE(cfaa2.ad_account_id, 'act_', '') IN ('612830523394289', '4074283036142763')
  AND cfaai."date" >= '2025-01-01'
  AND TRIM(SPLIT_PART(cfac.name, '_', 2)) IS NOT NULL

SELECT
    f.ad_id,
    f.spend::NUMERIC AS chi_phi,
    f.spend,
    f.date AS Ngay_chi_phi,
    f.region AS vung,
    f.ad_name AS ten_ad,
    f.adset_name AS ten_ad_set,
    f.ad_account_name AS account,
    f.ad_campaign_name AS ten_cd,
    f.adset_id AS fb_ad_set_id,
    f.ad_account_id,
    CASE WHEN lpa.branch IS NULL THEN 'Việt Kiều' ELSE lpa.branch END AS chi_nhanh,
    SPLIT_PART(f.adset_name, '_', 2) AS nhom_dv_raw
FROM {{ source('ptdbdspc_ads', 'cs_facebook_insight') }} f
LEFT JOIN {{ source('ptdbdspc_ads', 'local_paris_adnet') }} lpa ON lpa.province = f.region
WHERE f.brand_etl = 3
  AND f.ad_account_id IN ('act_503362870590760', 'act_6217684194909373')

{{
  config(
    materialized = 'table',
    alias = 'stg_fb_insight_old'
  )
}}

SELECT
    CASE WHEN cfaai.fb_account_currency = 'USD'
         THEN cfaai.spend * tgt.bidrateck::double precision
         ELSE cfaai.spend
    END                                                          AS chi_phi,
    cfaai.date                                                   AS ngay_chi_phi,
    cfaai.region                                                 AS vung,
    cfac2.name                                                   AS camp_name,
    split_part(cfac2.name, '_', 1)                               AS cn,
    UPPER(TRIM(split_part(cfac2.name, '_', 2)))                  AS nhom_dv,
    UPPER(TRIM(split_part(cfac2.name, '_', 3)))                  AS nhom_dv2,
    CASE WHEN cfaa2.ad_account_id = '651294956930454'
         THEN 'Cost_fb_th' ELSE 'Cost_fb_cd'
    END                                                          AS type_data,
    split_part(cac.fb_effective_object_story_id::text, '_', 1)   AS page_id,
    cfaa2.name                                                   AS account_fb,
    'act_' || cfaa2.ad_account_id                                AS ad_account_id,
    cfac2.fb_ad_campaign_id,
    cfas.fb_ad_set_id,
    cfaai.fb_ad_ad_id,
    lka."chi nhánh"                                              AS chi_nhanh_no_camp
FROM {{ source('kangnam', 'core_facebook_ad_ad_insight') }}  cfaai
LEFT JOIN {{ source('kangnam', 'core_facebook_ad_ad') }}      cfaa
       ON cfaa.fb_ad_ad_id       = cfaai.fb_ad_ad_id
LEFT JOIN {{ source('kangnam', 'core_facebook_ad_creative') }} cac
       ON cac.fb_ad_creative_id  = cfaa.fb_creative_id
LEFT JOIN {{ source('kangnam', 'core_facebook_ad_set') }}      cfas
       ON cfas.fb_ad_set_id      = cfaa.fb_ad_set_id
LEFT JOIN {{ source('kangnam', 'core_facebook_ad_campaign') }} cfac2
       ON cfac2.fb_ad_campaign_id = cfas.fb_ad_campaign_id
LEFT JOIN {{ source('kangnam', 'core_facebook_ad_account') }}  cfaa2
       ON cfaa2.ad_account_id    = cfac2.fb_ad_account_id
-- Exchange rate: latest USD rate on or before the ad date
LEFT JOIN LATERAL (
    SELECT bidrateck
    FROM {{ source('kangnam', 'ty_gia_techcombank') }}
    WHERE label = 'USD (50,100)' AND cfaai.date >= date
    ORDER BY date DESC LIMIT 1
) tgt ON TRUE
-- Chi nhánh: latest location config on or before the ad date
LEFT JOIN LATERAL (
    SELECT "chi nhánh"
    FROM {{ source('kangnam', 'location_kangnam_adnet') }}
    WHERE tinh = cfaai.region AND cfaai.date >= ngay_hh
    ORDER BY ngay_hh DESC LIMIT 1
) lka ON TRUE
WHERE cfaa2.current_brand_id = 1
  AND cfaai.date::date > '{{ var("start_date", "2025-08-01") }}'::date

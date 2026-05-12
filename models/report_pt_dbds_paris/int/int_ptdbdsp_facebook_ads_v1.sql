WITH b AS (
    SELECT
        cfaai.fb_ad_ad_id AS ad_id,
        CASE 
            WHEN cfaai.fb_account_currency = 'USD' THEN cfaai.spend::NUMERIC * tgt.askrate::NUMERIC 
            ELSE cfaai.spend::NUMERIC 
        END AS chi_phi,
        cfaai.spend,
        cfaai."date" AS Ngay_chi_phi,
        cfaai.region AS vung,
        cfaa.name AS ten_ad,
        cfas.name AS ten_ad_set,
        cfaa2.name AS account,
        cfac2.name AS ten_cd,
        cfas.fb_ad_set_id,
        cfaa2.ad_account_id,
        CASE WHEN lpa.branch IS NULL THEN 'Việt Kiều' ELSE lpa.branch END AS chi_nhanh
    FROM {{ source('ptdbdsp_ads', 'core_facebook_ad_ad_insight') }} cfaai 
    LEFT JOIN {{ source('ptdbdsp_ads', 'core_facebook_ad_ad') }} cfaa ON cfaa.fb_ad_ad_id = cfaai.fb_ad_ad_id 
    LEFT JOIN {{ source('ptdbdsp_ads', 'core_facebook_ad_set') }} cfas ON cfas.fb_ad_set_id = cfaa.fb_ad_set_id 
    LEFT JOIN {{ source('ptdbdsp_ads', 'core_facebook_ad_campaign') }} cfac2 ON cfac2.fb_ad_campaign_id = cfas.fb_ad_campaign_id 
    LEFT JOIN {{ source('ptdbdsp_ads', 'core_facebook_ad_account') }} cfaa2 ON cfaa2.ad_account_id = cfac2.fb_ad_account_id 
    LEFT JOIN LATERAL (
        SELECT * FROM {{ source('ptdbdsp_ads', 'ty_gia_techcombank') }} tgt 
        WHERE tgt.label = 'USD (50,100)' AND (cfaai."date") >= (tgt."date") 
        ORDER BY DATE(tgt.date) DESC LIMIT 1
    ) tgt ON TRUE
    LEFT JOIN {{ source('ptdbdsp_ads', 'local_paris_adnet') }} lpa ON lpa.province = cfaai.region  
    WHERE cfaa2.id IN (7,9)
)
SELECT 
    ad_id,
    chi_phi,
    spend,
    Ngay_chi_phi,
    vung,
    ten_ad,
    ten_ad_set,
    account,
    ten_cd,
    fb_ad_set_id,
    ad_account_id,
    chi_nhanh,
    split_part(ten_ad_set, '_', 2) AS nhom_dv_raw
FROM b

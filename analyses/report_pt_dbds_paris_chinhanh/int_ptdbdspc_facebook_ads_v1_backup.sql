WITH b AS (
    SELECT
        cfaai.fb_ad_ad_id AS Ad_id,
        cfaai.fb_account_currency,
        CASE 
            WHEN cfaai.fb_account_currency = 'USD' THEN (cfaai.spend::NUMERIC * tgt.askrate::NUMERIC) 
            ELSE cfaai.spend::NUMERIC 
        END AS chi_phi,
        cfaai.spend,
        cfaai.fb_account_currency AS fb_account_currency_dup,
        cfaai."date" AS Ngay_chi_phi,
        cfaai.region AS vung,
        cfaa.name AS ten_ad,
        cfas.name AS ten_ad_set,
        cfaa2.name AS account,
        cfac2.name AS ten_cd,
        cfas.fb_ad_set_id,
        cfaa2.ad_account_id,
        CASE 
            WHEN lpa.branch IS NULL THEN 'Việt Kiều' 
            ELSE lpa.branch 
        END AS chi_nhanh_f
    FROM {{ source('ptdbdspc_ads', 'core_facebook_ad_ad_insight') }} cfaai 
    LEFT JOIN {{ source('ptdbdspc_ads', 'core_facebook_ad_ad') }} cfaa ON cfaa.fb_ad_ad_id = cfaai.fb_ad_ad_id 
    LEFT JOIN {{ source('ptdbdspc_ads', 'core_facebook_ad_set') }} cfas ON cfas.fb_ad_set_id = cfaa.fb_ad_set_id 
    LEFT JOIN {{ source('ptdbdspc_ads', 'core_facebook_ad_campaign') }} cfac2 ON cfac2.fb_ad_campaign_id = cfas.fb_ad_campaign_id 
    LEFT JOIN (SELECT * FROM {{ source('ptdbdspc_ads', 'core_facebook_ad_account') }}) cfaa2 ON cfaa2.ad_account_id = cfac2.fb_ad_account_id 
    LEFT JOIN LATERAL (
        SELECT * FROM {{ source('ptdbdspc_ads', 'ty_gia_techcombank') }} tgt 
        WHERE tgt.label = 'USD (50,100)' AND (cfaai."date") >= (tgt."date") 
        ORDER BY DATE(tgt.date) DESC LIMIT 1
    ) tgt ON TRUE
    LEFT JOIN {{ source('ptdbdspc_ads', 'local_paris_adnet') }} lpa ON lpa.province = cfaai.region  
    WHERE cfaa2.id IN (7,9)
)

SELECT 
    b.account, 
    b.Ad_id, 
    b.Ngay_chi_phi, 
    b.ten_ad_set,
    SPLIT_PART(b.ten_ad_set, '_', 2) AS nhom_dv_raw,
    b.ten_ad,
    b.chi_phi,
    b.chi_nhanh_f AS chi_nhanh,
    b.vung,
    b.ad_account_id,
    b.fb_ad_set_id
FROM b

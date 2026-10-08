{{ config(materialized='ephemeral', tags=['phi']) }}
-- =============================================================================
-- stg_frmacph_fb_cost
-- Chi phí Facebook của Philippines = campaign tiền tố 'sun_' (TK "Kangnam Surgery -
-- Quốc tế 06 - Phil", act_27957337653894035). Dữ liệu nằm trong cs_facebook_insight
-- brand_etl = 1 vì chạy trên hạ tầng FB của Kangnam.
-- Tên campaign theo chuẩn tập đoàn: token 2 = page_code, 3 = cn, 5 = nhóm DV,
-- 8 = actor, 9 = thị trường.
-- =============================================================================
SELECT
    f."date"                                     AS ngay,
    f.ad_account_id,
    max(f.ad_account_name)                       AS account_fb,
    f.ad_campaign_id                             AS campaign_id,
    max(f.ad_campaign_name)                      AS camp_name,
    f.facebook_page_id                           AS page_id,
    max(f.page_name)                             AS page_name,
    f.country,
    f.region,
    split_part(max(f.ad_campaign_name), '_', 3)  AS cn,
    split_part(max(f.ad_campaign_name), '_', 5)  AS nhom_dv_code,
    split_part(max(f.ad_campaign_name), '_', 8)  AS actor_code,
    sum(f.spend)                                 AS chi_phi
FROM {{ source('kangnam', 'cs_facebook_insight') }} f
WHERE f.brand_etl = 1
  AND f.ad_campaign_name ILIKE 'sun\_%'
GROUP BY f."date", f.ad_account_id, f.ad_campaign_id, f.facebook_page_id, f.country, f.region

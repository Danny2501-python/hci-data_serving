-- =============================================================================
-- stg_frmack_fb_insight_v2
-- Simplified Facebook ad cost using the denormalized cs_facebook_insight table.
-- Currency is pre-converted and metadata is already flattened.
-- =============================================================================
{{
  config(
    materialized = 'table',
    alias = 'stg_fb_insight_new'
  )
}}

SELECT
    f.spend                                                      AS chi_phi,
    f.date                                                       AS ngay_chi_phi,
    f.region                                                     AS vung,
    f.ad_campaign_name                                           AS camp_name,
    CASE 
      WHEN cardinality(string_to_array(f.ad_campaign_name,'_' )) >= 9 
        and split_part(f.ad_campaign_name, '_', 1) NOT ILIKE 'MIEN%' THEN split_part(f.ad_campaign_name, '_', 3)
      ELSE split_part(f.ad_campaign_name, '_', 1)
    END                                                          AS cn,
    CASE 
      WHEN cardinality(string_to_array(f.ad_campaign_name,'_' )) >= 9 
        and split_part(f.ad_campaign_name, '_', 1) NOT ILIKE 'MIEN%' THEN split_part(f.ad_campaign_name, '_', 5)
      ELSE UPPER(TRIM(split_part(f.ad_campaign_name, '_', 2)))
    END                                                         AS nhom_dv,
    CASE 
      WHEN cardinality(string_to_array(f.ad_campaign_name,'_' )) >= 9 
        and split_part(f.ad_campaign_name, '_', 1) NOT ILIKE 'MIEN%' THEN split_part(f.ad_campaign_name, '_', 5)
      ELSE UPPER(TRIM(split_part(f.ad_campaign_name, '_', 3)))
    END                                                          AS nhom_dv2,
    CASE WHEN f.ad_account_id = 'act_651294956930454'
         THEN 'Cost_fb_th' ELSE 'Cost_fb_cd'
    END                                                          AS type_data,
    f.facebook_page_id                                           AS page_id,
    f.ad_account_name                                            AS account_fb,
    f.ad_account_id,
    f.ad_campaign_id                                            AS fb_ad_campaign_id,
    f.adset_id                                                  AS fb_ad_set_id,
    f.ad_id                                                     AS fb_ad_ad_id,
    lka."chi nhánh"                                              AS chi_nhanh_no_camp
FROM {{ source('kangnam', 'cs_facebook_insight') }} f
-- Chi nhánh: latest location config on or before the ad date
LEFT JOIN LATERAL (
    SELECT "chi nhánh"
    FROM {{ source('kangnam', 'location_kangnam_adnet') }}
    WHERE tinh = f.region AND f.date >= ngay_hh
    ORDER BY ngay_hh DESC LIMIT 1
) lka ON TRUE
WHERE f.brand_etl = 1
  AND f.date::date > '{{ var("start_date", "2025-08-01") }}'::date
  AND f.facebook_page_id not in ('805410602664141','839493609256431','948044848396128')

-- =============================================================================
-- stg_frmack_doanh_so  (Pass 8)
-- Revenue data with chi_nhanh remap and local_k same formula as CRM.
-- =============================================================================
WITH a AS (
    SELECT
        CASE 
              WHEN cl3.overseas_vietnamese = 'expat' THEN 'exp' 
              ELSE cl3.overseas_vietnamese 
        END                                            AS vk,
        sp.product                                     AS ten_dv,
        ss.source                                      AS nguon,
        ss.category_source                             AS nhom_nguon,
        CASE WHEN ss.source ~~ '%Facebook%' THEN 'FB'
             WHEN ss.source ~~ '%Seo%'      THEN 'Web'
             WHEN ss.source ~~ '%Google%'   THEN 'Web'
             WHEN ss.source ~~ '%Hotline%'  THEN 'Web'
             ELSE 'Khác'
        END                                            AS kenh,
        std.payment_date                               AS ngay,
        mrc.name                                       AS chi_nhanh_raw,
        std.payment                                    AS doanh_so,
        sp.product_category                            AS nhom_dv,
        CASE WHEN rcs.name = 'Thành phố Hồ Chí Minh' THEN 'SÀI GÒN'
             WHEN rcs.name = 'Thành phố Hà Nội'       THEN 'Hà Nội'
             WHEN rcs.name IS NULL                      THEN 'KXĐ'
             WHEN rcs.code NOT LIKE '%VN-%'             THEN 'VIỆT KIỀU'
             ELSE rcs.name
        END                                            AS local_k,
        rc.name                                        AS quoc_gia,
        cl3.ticket_id,
        substring(cta.ad_id_value FROM '\d+')        AS fb_ad_id
    FROM {{ source('kangnam', 'stag_payment_transfer') }} std
    LEFT JOIN {{ source('kangnam', 'crm_lead') }} cl3
           ON std.crm_id = cl3.id AND std.brand_etl = cl3.brand_etl
    LEFT JOIN {{ source('kangnam', 'res_country_state') }} rcs
           ON rcs.id = cl3.state_id  AND rcs.brand_etl = 1
    LEFT JOIN {{ source('kangnam', 'res_country') }} rc
           ON rc.id  = cl3.country_id AND rc.brand_etl = 1
    LEFT JOIN {{ source('kangnam', 'view_stag_products') }} sp
           ON sp.product_id = std.product_id AND sp.brand_etl = std.brand_etl
    LEFT JOIN {{ source('kangnam', 'stag_sources') }} ss
           ON ss.old_id = cl3.source_id::double precision
    LEFT JOIN {{ source('kangnam', 'm_res_company') }} mrc
           ON mrc.id = std.company_id AND mrc.brand_etl = 1
    LEFT JOIN {{ source('kangnam', 'cs_ticket_api') }} cta
           ON cta.ticket_id = cl3.ticket_id AND cta.brand_id = 1
    WHERE std.brand_etl = 1
      AND std.payment_date::date >= '{{ var("start_date", "2025-08-01") }}'::date
)
SELECT
    a.vk,
    a.ten_dv,
    a.nguon,
    a.nhom_nguon,
    a.kenh,
    a.ngay,
    a.nhom_dv,
    CASE WHEN a.vk = 'marketing'
             THEN 'VIỆT KIỀU'
         WHEN a.chi_nhanh_raw = 'VIỆN THẨM MỸ KANGNAM BẠCH MAI'
          AND a.vk NOT IN ('marketing','mkt_oversea')
             THEN 'BỆNH VIỆN KANGNAM HÀ NỘI'
         WHEN a.chi_nhanh_raw = 'BỆNH VIỆN KANGNAM NGUYỄN TRÃI'
          AND a.vk NOT IN ('marketing','mkt_oversea')
             THEN 'BỆNH VIỆN KANGNAM SÀI GÒN'
         WHEN a.chi_nhanh_raw = 'BỆNH VIỆN KANGNAM SÀI GÒN'
          AND a.vk NOT IN ('marketing','mkt_oversea')
             THEN 'BỆNH VIỆN KANGNAM SÀI GÒN'
         WHEN a.vk = 'mkt_oversea'
             THEN 'QUỐC TẾ'
         ELSE a.chi_nhanh_raw
    END                       AS chi_nhanh,
    a.local_k,
    a.quoc_gia,
    a.doanh_so::text          AS metric,
    'DS'::text                AS type_data,
    a.ticket_id,
    dc.campaign_name,
    CASE WHEN cardinality(string_to_array(dc.campaign_name,'_' )) >= 9 
            AND split_part(dc.campaign_name, '_', 1) IN {{var('all_brand_mkt_camp')}} THEN split_part(dc.campaign_name, '_', 8)
        ELSE NULL
    END                       AS camp_actor,
    da.account_name as account_fb
FROM a
       LEFT JOIN {{source('kangnam', 'dim_camp_adset_ad') }} dca 
              ON dca.ad_id = a.fb_ad_id 
       LEFT JOIN {{source('kangnam','dim_campaign')}} dc 
              ON dca.ad_campaign_id = dc.campaign_id
       LEFT JOIN {{source('kangnam', 'dim_account') }} da ON da.account_id = dca.account_id

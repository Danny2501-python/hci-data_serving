{{
  config(
    materialized = 'table',
    alias        = 'stg_fb_insight_old_pr'
  )
}}

WITH fb_base AS (
    SELECT
        CASE 
            WHEN cfaai.fb_account_currency = 'USD' THEN cfaai.spend * tgt.bidrateck::numeric
            ELSE cfaai.spend 
        END                                                         AS chi_phi_raw,
        cfaai.date::date                                            AS ngay_chi_phi,
        cfaai.region                                                AS vung,
        cfac2.name                                                  AS campaign_name,
        cfaa2.ad_account_id,
        cfaai.fb_ad_ad_id,
        -- Distinguish between Conversion (Pass 3) and Brand (Pass 4)
        CASE WHEN cfaa2.id = 8 THEN 'Cost_fb_th' ELSE 'Cost_fb_cd' END AS type_data_check,
        lpa.branch                                                  AS chi_nhanh_raw,
        SPLIT_PART(cfac2.name, '_', 2)                             AS nhom_dv_p2,
        SPLIT_PART(cfac2.name, '_', 3)                             AS nhom_dv_p3
    FROM {{ source('paris', 'core_facebook_ad_ad_insight') }}  cfaai
    LEFT JOIN {{ source('paris', 'core_facebook_ad_ad') }} cfaa ON cfaa.fb_ad_ad_id = cfaai.fb_ad_ad_id
    LEFT JOIN {{ source('paris', 'core_facebook_ad_set') }} cfas ON cfas.fb_ad_set_id = cfaa.fb_ad_set_id
    LEFT JOIN {{ source('paris', 'core_facebook_ad_campaign') }} cfac2 ON cfac2.fb_ad_campaign_id = cfas.fb_ad_campaign_id
    LEFT JOIN {{ source('paris', 'core_facebook_ad_account') }} cfaa2 ON cfaa2.ad_account_id = cfac2.fb_ad_account_id
    LEFT JOIN LATERAL (
        SELECT bidrateck FROM {{ source('paris', 'ty_gia_techcombank') }}
        WHERE label = 'USD (50,100)' AND cfaai.date >= date 
        ORDER BY date DESC LIMIT 1
    ) tgt ON TRUE
    LEFT JOIN {{ source('paris', 'local_paris_adnet') }} lpa ON lpa.province = cfaai.region
    WHERE (
            (cfaa2.id <> 8 AND cfaa2.current_brand_id = 3) -- Pass 3
            OR (cfaa2.id = 8)                              -- Pass 4
          )
      AND cfaai.date::date > '{{ var("start_date", "2025-08-01") }}'::date
)

SELECT
    -- EXACT MATCH for 'Nguon' from original SQL
    CASE 
        WHEN type_data_check = 'Cost_fb_th' THEN 'Chi phí thương hiệu' 
        ELSE 'MD - Facebook' 
    END::text                                                       AS nguon,
    'MD'::text                                                      AS nhom_nguon,
    'FB'::text                                                      AS channel,
    ngay_chi_phi                                                    AS ngay,
    chi_phi_raw::text                                               AS metric,
    -- EXACT MATCH for 'nhom_dv' logic from original SQL
    CASE
        WHEN type_data_check = 'Cost_fb_th' THEN 'THUONG HIEU'
        WHEN (nhom_dv_p2 = 'NRKT' OR nhom_dv_p3 = 'NRKT')        THEN 'Niềng răng khay trong'
        WHEN nhom_dv_p2 = 'SALE TONG'                               THEN 'NHA KHOA KHÁC'
        WHEN nhom_dv_p2 = 'PTHM'                                    THEN 'PTHM'
        WHEN nhom_dv_p2 ILIKE '%RANG SU%'                           THEN 'Răng sứ'
        WHEN nhom_dv_p2 ILIKE '%IMPLANT%' OR nhom_dv_p2 ILIKE '%IMPLAMT%' THEN 'Implant'
        WHEN nhom_dv_p2 ILIKE '%NIENG RANG%' AND nhom_dv_p3 <> 'NRKT' THEN 'Niềng răng mắc cài'
        WHEN nhom_dv_p2 ILIKE '%Brand%'                             THEN 'THUONG HIEU'
        ELSE UPPER(nhom_dv_p2)
    END::text                                                       AS nhom_dv,
    -- EXACT MATCH for branch categorization
    CASE
        WHEN chi_nhanh_raw IS NULL                                  THEN 'VIỆT KIỀU'
        WHEN UPPER(chi_nhanh_raw) = 'HÀ NỘI'                        THEN 'HÀ NỘI'
        WHEN UPPER(chi_nhanh_raw) = 'HỒ CHÍ MINH'                   THEN 'HỒ CHÍ MINH'
        WHEN UPPER(chi_nhanh_raw) = 'NHA KHOA PARIS BẮC NINH'       THEN 'BẮC NINH'
        WHEN UPPER(chi_nhanh_raw) = 'NHA KHOA PARIS HẢI PHÒNG'      THEN 'HẢI PHÒNG'
        WHEN UPPER(chi_nhanh_raw) = 'NHA KHOA PARIS BUÔN MÊ THUỘT'  THEN 'BUÔN MÊ THUỘT'
        WHEN UPPER(chi_nhanh_raw) = 'NHA KHOA PARIS ĐÀ NẴNG'        THEN 'ĐÀ NẴNG'
        WHEN UPPER(chi_nhanh_raw) = 'NHA KHOA PARIS VINH'            THEN 'VINH'
        WHEN UPPER(chi_nhanh_raw) = 'NHA KHOA PARIS THÁI NGUYÊN'    THEN 'THÁI NGUYÊN'
        WHEN UPPER(chi_nhanh_raw) = 'NHA KHOA PARIS THANH HÓA'      THEN 'THANH HÓA'
        WHEN UPPER(chi_nhanh_raw) = 'NHA KHOA PARIS BÌNH DƯƠNG'      THEN 'BÌNH DƯƠNG'
        WHEN UPPER(chi_nhanh_raw) = 'NHA KHOA PARIS QUẢNG NINH'     THEN 'QUẢNG NINH'
        ELSE UPPER(chi_nhanh_raw)
    END::text                                                       AS chi_nhanh,
    type_data_check                                                 AS type_data,
    -- Technical keys for V3 join
    ad_account_id,
    fb_ad_ad_id,
    vung
FROM fb_base

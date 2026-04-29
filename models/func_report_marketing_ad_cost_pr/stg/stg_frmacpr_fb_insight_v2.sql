-- =============================================================================
-- stg_frmacpr_fb_insight_v2
-- New Facebook ad cost using the denormalized cs_facebook_insight table.
-- Currency is pre-converted and metadata is already flattened.
-- =============================================================================
{{
  config(
    materialized = 'table',
    alias = 'stg_fb_insight_new_pr'
  )
}}

WITH fb_new AS (
    SELECT
        f.spend                                                      AS chi_phi_raw,
        f.date::date                                                 AS ngay_chi_phi,
        f.region                                                     AS vung,
        f.ad_account_id,
        f.ad_id                                                      AS fb_ad_ad_id,
        -- Identification of product vs brand accounts
        CASE 
            WHEN f.ad_account_id = 'act_1741025749489548' THEN 'Cost_fb_th' 
            ELSE 'Cost_fb_cd' 
        END                                                          AS type_data_check,
        lpa.branch                                                   AS chi_nhanh_raw,
        SPLIT_PART(f.ad_campaign_name, '_', 2)                       AS nhom_dv_p2,
        SPLIT_PART(f.ad_campaign_name, '_', 3)                       AS nhom_dv_p3
    FROM {{ source('paris', 'cs_facebook_insight') }} f
    LEFT JOIN {{ source('paris', 'local_paris_adnet') }} lpa
           ON lpa.province = f.region
    WHERE f.brand_etl = 3
      AND f.date::date > '{{ var("start_date", "2025-08-01") }}'::date
)

SELECT
    -- Consistent with V1 and original SQL
    CASE 
        WHEN type_data_check = 'Cost_fb_th' THEN 'Chi phí thương hiệu' 
        ELSE 'MD - Facebook' 
    END::text                                                       AS nguon,
    'MD'::text                                                      AS nhom_nguon,
    'FB'::text                                                      AS channel,
    ngay_chi_phi                                                    AS ngay,
    chi_phi_raw::text                                               AS metric,
    CASE
        WHEN type_data_check = 'Cost_fb_th' THEN 'THUONG HIEU'
        WHEN (UPPER(nhom_dv_p2) = 'NRKT' OR UPPER(nhom_dv_p3) = 'NRKT') THEN 'Niềng răng khay trong'
        WHEN UPPER(nhom_dv_p2) = 'SALE TONG'                     THEN 'NHA KHOA KHÁC'
        WHEN UPPER(nhom_dv_p2) = 'PTHM'                          THEN 'PTHM'
        WHEN UPPER(nhom_dv_p2) LIKE '%RANG SU%'                  
          OR UPPER(nhom_dv_p2) LIKE '%RANGSU%'                   THEN 'Răng sứ'
        WHEN UPPER(nhom_dv_p2) LIKE '%IMPLANT%'
          OR UPPER(nhom_dv_p2) LIKE '%IMPLAMT%'                  THEN 'Implant'
        WHEN (UPPER(nhom_dv_p2) LIKE '%NIENG%' OR UPPER(nhom_dv_p2) LIKE '%NR%')
         AND UPPER(nhom_dv_p3) <> 'NRKT'                        THEN 'Niềng răng mắc cài'
        WHEN UPPER(nhom_dv_p2) LIKE '%BRAND%'                    THEN 'THUONG HIEU'
        ELSE UPPER(nhom_dv_p2)
    END::text                                                       AS nhom_dv,
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
        WHEN UPPER(chi_nhanh_raw) = 'NHA KHOA PARIS BÌNH DƯƠNG'     THEN 'BÌNH DƯƠNG'
        WHEN UPPER(chi_nhanh_raw) = 'NHA KHOA PARIS QUẢNG NINH'     THEN 'QUẢNG NINH'
        ELSE UPPER(chi_nhanh_raw)
    END::text                                                       AS chi_nhanh,
    type_data_check                                                 AS type_data,
    ad_account_id,
    fb_ad_ad_id,
    vung
FROM fb_new

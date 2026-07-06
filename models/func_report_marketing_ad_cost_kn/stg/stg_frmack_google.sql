-- =============================================================================
-- stg_frmack_google  (Pass 10)
-- Google Ads: nhom_dv mapping (88888→VIỆT KIỀU, 99999/XLKH→THƯƠNG HIỆU)
-- chi_nhanh from campaign name segments.
-- =============================================================================
WITH base AS (
    SELECT
        cgk.campaign, cgk.account, cgk.cost, cgk.date::date          AS ngay,
        split_part(cgk.campaign, '_', 1)                              AS dv,
        split_part(cgk.campaign, '_', 2)                              AS cn1,
        split_part(cgk.campaign, '_', 3)                              AS cn2,
        split_part(cgk.campaign, ' - ', 1)                            AS cn_dash
    FROM {{ source('kangnam', 'cp_google_kangnam') }} cgk
    WHERE cgk.account IS NOT NULL
      AND cgk.date::date >= '{{ var("start_date", "2025-08-01") }}'::date
),
a AS (
    SELECT
        campaign, 'Web'::text AS channel, dv AS nhom_dv_raw, ngay,
        (cost::float8 * 23500)::text AS chi_phi, account,
        CASE WHEN cn1 IN ('VIỆT KIỀU','Viet')    THEN 'VIỆT KIỀU'
             WHEN campaign = 'XLKH'               THEN 'BỆNH VIỆN KANGNAM SÀI GÒN'
             WHEN cn1 = 'HN'                       THEN 'BỆNH VIỆN KANGNAM HÀ NỘI'
             WHEN cn1 = 'HCM'                      THEN 'BỆNH VIỆN KANGNAM SÀI GÒN'
             WHEN cn_dash = 'HCM'                  THEN 'BỆNH VIỆN KANGNAM SÀI GÒN'
             WHEN cn1||' '||cn2 = 'Can Tho'        THEN 'VIỆN THẨM MỸ KANGNAM CẦN THƠ'
             WHEN cn1||' '||cn2 = 'Da Nang'        THEN 'VIỆN THẨM MỸ KANGNAM ĐÀ NẴNG'
             WHEN cn1||' '||cn2 = 'Hai Phong'      THEN 'VIỆN THẨM MỸ KANGNAM HẢI PHÒNG'
             WHEN cn1||' '||cn2 = 'Nghe An'        THEN 'VIỆN THẨM MỸ KANGNAM NGHỆ AN'
             WHEN cn1||' '||cn2 = 'Quoc Te'        THEN 'QUỐC TẾ'
             ELSE NULL
        END AS chi_nhanh
    FROM base
)
SELECT
    a.campaign,
    CASE WHEN a.chi_nhanh ILIKE '%VIỆT KIỀU%' THEN 'VIỆT KIỀU'
         WHEN a.chi_nhanh ILIKE '%QUỐC TẾ%'  THEN 'QUỐC TẾ'
         ELSE 'no'
    END                                                              AS vk,
    'DV'::text                                                       AS ten_dv,
    'GG'::text                                                       AS nguon,
    'GG'::text                                                       AS nhom_nguon,
    a.channel                                                        AS kenh,
    a.ngay,
    CASE WHEN a.nhom_dv_raw = '88888'            THEN 'VIỆT KIỀU'
         WHEN a.nhom_dv_raw IN ('99999','XLKH')  THEN 'THƯƠNG HIỆU'
         ELSE pc.name
    END                                                              AS nhom_dv,
    a.chi_nhanh,
    CASE a.chi_nhanh
        WHEN 'BỆNH VIỆN KANGNAM SÀI GÒN'      THEN 'SÀI GÒN'
        WHEN 'BỆNH VIỆN KANGNAM HÀ NỘI'        THEN 'HÀ NỘI'
        WHEN 'VIỆN THẨM MỸ KANGNAM CẦN THƠ'   THEN 'Thành phố Cần Thơ'
        WHEN 'VIỆN THẨM MỸ KANGNAM ĐÀ NẴNG'   THEN 'Thành phố Đà Nẵng'
        WHEN 'VIỆN THẨM MỸ KANGNAM HẢI PHÒNG' THEN 'Thành phố Hải Phòng'
        WHEN 'VIỆN THẨM MỸ KANGNAM NGHỆ AN'    THEN 'Tỉnh Nghệ An'
        ELSE a.chi_nhanh
    END                                                              AS local_k,
    CASE WHEN a.chi_nhanh = 'VIỆT KIỀU' THEN 'VIỆT KIỀU'
         WHEN a.chi_nhanh = 'QUỐC TẾ'  THEN 'QUỐC TẾ'
         ELSE 'Việt Nam'
    END                                                              AS quoc_gia,
    a.chi_phi                                                        AS metric,
    CASE WHEN a.account <> 'Thương hiệu - Brand' THEN 'Google_cd'
         ELSE 'Google_th'
    END                                                              AS type_data,
    0                                                                AS ticket_id,
    a.account
FROM a
LEFT JOIN {{ source('kangnam', 'product_category') }} pc
       ON pc.id::text = a.nhom_dv_raw AND pc.brand_etl = 1

WITH v1 AS (
    SELECT * FROM {{ ref('int_ptdbdsp_facebook_ads_v1') }}
),

v2 AS (
    SELECT * FROM {{ ref('int_ptdbdsp_facebook_ads_v2') }}
),

v2_supplement AS (
    SELECT v2.*
    FROM v2
    WHERE NOT EXISTS (
        SELECT 1 FROM v1 
        WHERE v1.ad_account_id = v2.ad_account_id
          AND v1.ad_id = v2.ad_id
          AND v1.Ngay_chi_phi = v2.Ngay_chi_phi
          AND v1.vung = v2.vung
    )
),

fb_union AS (
    SELECT * FROM v1
    UNION ALL
    SELECT * FROM v2_supplement
)

SELECT 
    u.account, u.ad_id, u.Ngay_chi_phi, u.ten_ad_set,
    COALESCE(gda.nhom_dv_chuan_hoa,
        CASE 
            WHEN u.nhom_dv_raw = 'MESS' THEN regexp_replace(trim(split_part(u.ten_ad,'_',2)), '\s+', ' ', 'g')
            WHEN u.nhom_dv_raw = 'VIEW' THEN regexp_replace(trim(split_part(u.ten_ad,'_',2)), '\s+', ' ', 'g')
            WHEN u.nhom_dv_raw ='BANNER' THEN regexp_replace(trim(split_part(u.ten_ad,'_',2)), '\s+', ' ', 'g')
            ELSE regexp_replace(trim(u.nhom_dv_raw), '\s+', ' ', 'g')
        END
    ) AS nhom_dv,
    u.ten_ad,
    u.chi_phi,
    u.chi_nhanh
FROM fb_union u
LEFT JOIN {{ source('ptdbdsp_ads', 'ggs_paris_chuan_hoa_nhom_dv_quang_cao') }} gda ON gda.fb_ad_set_id = u.fb_ad_set_id

WITH a AS (
    SELECT *,
        gap."date" AS ngay_chi_phi,
        TEXT(gap."cost") AS chi_phi,
        split_part(gap."campaign", '_', 2) AS nhom_dv,
        split_part(gap."campaign", '_', 1) AS chi_nhanh
    FROM {{ source('ptdbdsp_ads', 'google_ad_paris') }} gap
)
SELECT 
    CASE 
        WHEN a.chi_nhanh = 'BD' THEN 'BÌNH DƯƠNG'
        WHEN a.chi_nhanh = 'QN' THEN 'QUẢNG NINH'
        WHEN a.chi_nhanh = 'BV' THEN 'HỒ CHÍ MINH'
        WHEN a.chi_nhanh = 'HN' THEN 'HÀ NỘI'
        WHEN a.chi_nhanh = 'HP' THEN 'QUẢNG NINH'
        WHEN a.chi_nhanh = 'TH' THEN 'THANH HÓA'
        WHEN a.chi_nhanh = 'TN' THEN 'THÁI NGUYÊN'
        WHEN a.chi_nhanh = 'VINH' THEN 'VINH'
        WHEN a.chi_nhanh = 'ĐN' THEN 'ĐÀ NẴNG'
        WHEN a.chi_nhanh = 'BMT' THEN 'BUÔN MÊ THUỘT'
        WHEN a.chi_nhanh = 'BN' THEN 'BẮC NINH'
        WHEN a.chi_nhanh = 'NTH' THEN 'HỒ CHÍ MINH'
        WHEN a.chi_nhanh = 'CH' THEN 'HỒ CHÍ MINH'
        WHEN a.chi_nhanh = 'BT' THEN 'HÀ NỘI'
        WHEN a.chi_nhanh = 'TT' THEN 'HÀ NỘI'
        ELSE a.chi_nhanh 
    END AS Chi_nhanh,
    CASE
        WHEN UPPER(a.nhom_dv) LIKE '%NIỀNG RĂNG%' AND UPPER(a."google ads: ad group"::TEXT) <> 'invisalign' THEN 'Niềng răng mắc cài'
        WHEN UPPER(a.nhom_dv) = 'IMPLANT' THEN 'Implant '
        WHEN UPPER(a.nhom_dv) = 'THƯƠNG HIỆU' THEN 'THUONG HIEU'
        WHEN UPPER(a.nhom_dv) LIKE '%RĂNG SỨ%' THEN 'Răng sứ '
        WHEN UPPER(a.nhom_dv) LIKE 'PHẪU THUẬT HÀM MẶT' THEN 'PTHM'
        WHEN UPPER(a.nhom_dv) = '20/6' THEN 'Implant '
        WHEN UPPER(a.nhom_dv) IN ('KHAY TRONG','NIỀNG TRONG SUỐT') THEN 'Niềng răng khay trong'
        ELSE a.nhom_dv
    END AS nhom_dv,
    a.ngay_chi_phi,
    '0' AS "inbox",
    a.chi_phi AS "cost",
    'Web' AS channel
FROM a

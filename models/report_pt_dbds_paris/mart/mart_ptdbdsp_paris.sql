WITH test AS (SELECT * FROM {{ ref('int_ptdbdsp_revenue') }}),
data_gg AS (SELECT * FROM {{ ref('int_ptdbdsp_google_ads') }}),
fb AS (SELECT * FROM {{ ref('int_ptdbdsp_facebook_ads') }}),
m_nhom_dv_adnet_paris AS (SELECT * FROM {{ source('ptdbdsp_ads', 'm_nhom_dv_adnet_paris') }})

SELECT  
    ngay_den_cua, 
    ngay_dc,
    ma_booking,
    vao_so, ten_dv, ma_phieu, clineid, chinhanhphanquyen_nu, thuonghieuphanquyen, id, code_dv, tien_phai_thu,
    ngay_tt,
    nguon_moi,
    nhom_nguon_moi,
    nhom_dv,
    chi_nhanh,
    doanh_so,
    'ds' AS type_data, -- dữ liệu doanh số	
    CASE 
        WHEN overseas_vietnamese = 'no' THEN (
            CASE 
                WHEN chinhanhphanquyen_nu IN (3,20,19) THEN 'HỒ CHÍ MINH'
                WHEN chinhanhphanquyen_nu IN (13,14) THEN 'HÀ NỘI'
                WHEN chinhanhphanquyen_nu = 15 THEN 'QUẢNG NINH'
                WHEN chinhanhphanquyen_nu = 16 THEN 'VINH'
                WHEN chinhanhphanquyen_nu = 17 THEN 'ĐÀ NẴNG'
                WHEN chinhanhphanquyen_nu = 21 THEN 'QUẢNG NINH'
                WHEN chinhanhphanquyen_nu = 22 THEN 'BÌNH DƯƠNG'
                WHEN chinhanhphanquyen_nu = 28 THEN 'THANH HÓA'
                WHEN chinhanhphanquyen_nu = 31 THEN 'BẮC NINH'
                WHEN chinhanhphanquyen_nu = 38 THEN 'BUÔN MÊ THUỘT'
                WHEN chinhanhphanquyen_nu = 41 THEN 'THÁI NGUYÊN'
            END
        )
        ELSE 'VIỆT KIỀU' 
    END AS khu_vuc,
    mndap.nhom_dv_cpo AS "Nhóm bán CPO",
    mndap.nhom_dv_trongtam AS "Trọng tâm" 
FROM test 
LEFT JOIN m_nhom_dv_adnet_paris mndap ON mndap.default_code = test.code_dv
WHERE thuong_hieu = 'Paris'

UNION ALL 

SELECT 
    NULL::DATE ngay_den_cua,
    NULL ngay_dc,
    NULL ma_booking,
    NULL vao_so, NULL ten_dv, NULL ma_phieu, NULL clineid, NULL chinhanhphanquyen_nu, 3 thuonghieuphanquyen, NULL id, NULL code_dv, 0 tien_phai_thu,
    b.ngay_chi_phi::DATE,
    'CP' AS nguon,
    'CP' AS nhom_nguon,
    NULL AS nhom_dv,
    NULL chi_nhanh,
    REPLACE(b."cost",',','')::NUMERIC AS "Metric",
    'google' AS type_data, --- dữ liệu Google
    b.chi_nhanh AS chi_nhanh,
    b.nhom_dv,
    NULL "Trọng tâm" 
FROM data_gg b

UNION ALL 

SELECT 
    NULL::DATE ngay_den_cua,
    NULL ngay_dc,
    NULL ma_booking,
    NULL vao_so, NULL ten_dv, NULL ma_phieu, NULL clineid, NULL chinhanhphanquyen_nu, 3 thuonghieuphanquyen, NULL id, NULL code_dv, 0 tien_phai_thu,
    fb.ngay_chi_phi::DATE AS ngay,
    'CP' AS "Nguon",
    'CP' AS "Nhom_nguon",
    NULL nhom_dv,
    NULL chi_nhanh,
    fb.chi_phi::NUMERIC AS "Metric", -- dữ liệu chi phí Facebook end
    'Cost_fb_cd' AS data_type, -- chi phi
    CASE 
        WHEN fb.chi_nhanh = 'Hà Nội' THEN 'HÀ NỘI'
        WHEN (fb.chi_nhanh) = 'Hồ Chí Minh' THEN 'HỒ CHÍ MINH'
        WHEN UPPER(fb.chi_nhanh) = 'NHA KHOA PARIS BẮC NINH' THEN 'VIỆT KIỀU'
        WHEN UPPER(fb.chi_nhanh) = 'NHA KHOA PARIS BẮC NINH' THEN 'BẮC NINH'
        WHEN UPPER(fb.chi_nhanh) = 'NHA KHOA PARIS HẢI PHÒNG' THEN 'HẢI PHÒNG'
        WHEN UPPER(fb.chi_nhanh) = 'NHA KHOA PARIS BUÔN MÊ THUỘT' THEN 'BUÔN MÊ THUỘT'
        WHEN UPPER(fb.chi_nhanh) = 'NHA KHOA PARIS ĐÀ NẴNG' THEN 'ĐÀ NẴNG'
        WHEN UPPER(fb.chi_nhanh) = 'NHA KHOA PARIS VINH' THEN 'VINH'
        WHEN UPPER(fb.chi_nhanh) = 'NHA KHOA PARIS THÁI NGUYÊN' THEN 'THÁI NGUYÊN'
        WHEN UPPER(fb.chi_nhanh) = 'NHA KHOA PARIS THANH HÓA' THEN 'THANH HÓA'
        WHEN UPPER(fb.chi_nhanh) = 'NHA KHOA PARIS BÌNH DƯƠNG' THEN 'BÌNH DƯƠNG'
        WHEN UPPER(fb.chi_nhanh) = 'NHA KHOA PARIS QUẢNG NINH' THEN 'QUẢNG NINH'
        ELSE UPPER(fb.chi_nhanh)
    END AS chi_nhanh,
    CASE 
        WHEN nhom_dv = 'NRKT' THEN 'Niềng răng khay trong'
        WHEN nhom_dv = 'PTHM' THEN 'PTHM'
        WHEN nhom_dv IN ('RANG SU','Răng sứ') THEN 'Răng sứ '
        WHEN nhom_dv IN ('IMPLANT','IMPLAN','Implant','IMPLAMT') THEN 'Implant '
        WHEN nhom_dv IN ('NIENG RĂNG','NIENG','NIENG RANG','NIENNG RANG','NIENG RANGLAL') THEN 'Niềng răng mắc cài'
        WHEN nhom_dv IN ('TAY TRANG RANG','TAY TRANG','TẨY TRẮNG RĂNG','NK TONG QUAT') THEN 'Nha khoa tổng quát'
        WHEN nhom_dv IN ('BỆNH LÝ','NHỔ RĂNG KHÔN','NHO RANG','NHO RANG KHON','BENH LY') THEN 'Nha khoa khác'
        ELSE nhom_dv 
    END AS nhom_dv,
    NULL "Trọng tâm" 
FROM fb

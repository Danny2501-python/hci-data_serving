WITH test AS (
    SELECT * FROM {{ ref('int_ptdbdspc_revenue') }}
),
data_gg AS (
    SELECT * FROM {{ ref('int_ptdbdspc_google_ads') }}
),
fb AS (
    SELECT * FROM {{ ref('int_ptdbdspc_facebook_ads') }}
),
fn AS (
    SELECT  
        ngay_den_cua::DATE, 
        ngay_dc::DATE,
        ma_booking,
        vao_so, ten_dv, ma_phieu, clineid, chinhanhphanquyen_nu, thuonghieuphanquyen, id, code_dv, tien_phai_thu,
        ngay_tt::DATE,
        nguon_moi,
        nhom_nguon_moi,
        nhom_dv,
        chi_nhanh,
        doanh_so,
        'ds' AS type_data, 
        CASE 
            WHEN overseas_vietnamese = 'no'
            THEN (
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
    LEFT JOIN (SELECT * FROM {{ source('ptdbdspc_ads', 'm_nhom_dv_adnet_paris') }}) mndap ON mndap.default_code = test.code_dv
    WHERE thuong_hieu = 'Paris'

    UNION ALL 

    SELECT 
        NULL::DATE, -- ngay_den_cua
        NULL::DATE, -- ngay_dc
        NULL, -- ma_booking
        NULL, NULL, NULL, NULL, 1, 3, NULL, NULL, 0,
        b.ngay_chi_phi::DATE, -- ngay_tt
        'CP' AS nguon,
        'CP' AS nhom_nguon,
        NULL AS nhom_dv,
        NULL AS chi_nhanh,
        REPLACE(b."cost",',','')::NUMERIC AS "Metric",
        'google' AS type_data, 
        b.chi_nhanh AS chi_nhanh,
        b.nhom_dv,
        NULL AS "Trọng tâm" 
    FROM data_gg b

    UNION ALL 

    SELECT 
        NULL::DATE, -- ngay_den_cua
        NULL::DATE, -- ngay_dc
        NULL, -- ma_booking
        NULL, NULL, NULL, NULL, 1, 3, NULL, NULL, 0,
        fb.Ngay_chi_phi::DATE AS ngay,
        'CP' AS "Nguon",
        'CP' AS "Nhom_nguon",
        NULL AS nhom_dv,
        NULL AS chi_nhanh,
        fb.chi_phi::NUMERIC AS "Metric", 
        'Cost_fb_cd' AS data_type, 
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
            WHEN fb.nhom_dv ='NRKT' THEN 'Niềng răng khay trong'
            WHEN fb.nhom_dv ='PTHM' THEN 'PTHM'
            WHEN fb.nhom_dv IN ('RANG SU','Răng sứ') THEN 'Răng sứ '
            WHEN fb.nhom_dv IN ('IMPLANT','IMPLAN','Implant','IMPLAMT') THEN 'Implant '
            WHEN fb.nhom_dv IN ('NIENG RĂNG','NIENG','NIENG RANG','NIENNG RANG','NIENG RANGLAL') THEN 'Niềng răng mắc cài'
            WHEN fb.nhom_dv IN ('TAY TRANG RANG','TAY TRANG','TẨY TRẮNG RĂNG','NK TONG QUAT') THEN 'Nha khoa tổng quát'
            WHEN fb.nhom_dv IN ('BỆNH LÝ','NHỔ RĂNG KHÔN','NHO RANG','NHO RANG KHON','BENH LY') THEN 'Nha khoa khác'
            ELSE fb.nhom_dv 
        END AS nhom_dv,
        NULL AS "Trọng tâm" 
    FROM fb
)
SELECT * FROM fn

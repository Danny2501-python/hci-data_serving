WITH ecl AS (
    SELECT * FROM {{ source('crm_base', 'crm_lead') }} WHERE brand_etl = 1
),
cline AS (
    SELECT * FROM {{ source('crm_base', 'crm_line') }} WHERE brand_etl = 1
),
a AS (
    SELECT   
        ROW_NUMBER() OVER (PARTITION BY ecl.id ORDER BY ecl2.id) AS thu_tu,
        ecl.type_data_partner AS kh_cu_moi,
        CASE 
            WHEN ecl.overseas_vietnamese = 'expat' THEN 'exp'
            ELSE ecl.overseas_vietnamese
        END AS vk,
        ecl.contact_name AS Ten_Khach,
        ecl2.id AS line_id,
        ecl.id AS id,
        ecl.code_customer AS Ma_KH,
        ecl.phone AS sdt,
        DATE(ecl.arrival_date + '07:00:00'::interval) AS Ngay_den_cua,
        ecl.type_crm_id AS Loai_ban_ghi, 
        DATE(ecl.create_on + '07:00:00'::interval) AS Ngay_tao,
        DATE(ecl.arrival_date + '07:00:00'::interval) AS Ngay_dc,
        DATE(ecl.booking_date + '07:00:00'::interval) AS Ngay_hl,
        DATE(spt.payment_date + '00:00:00'::interval) AS Ngay_tt,
        CASE 
            WHEN ecl.arrival_date IS NOT NULL THEN ecl.arrival_date::DATE 
            ELSE ecl.create_on::DATE 
        END AS Date_Time,
        ecl."name" AS Ma_Booking,
        se.employee AS Nhan_Vien,
        spt.payment AS doanh_so,
        ecl2.total_received AS Tong_tien,
        CASE WHEN spt.id IS NOT NULL THEN 'posted' ELSE 'no_money' END AS vao_so,
        ecs2.name AS Trang_Thai,
        CASE 
            WHEN spt.id LIKE '%to%' THEN 'Transfer'
            WHEN spt.id LIKE '%ti%' THEN 'Recieve'
            ELSE ecl2.stage
        END AS Line_tt,
        CASE
            WHEN ecl.arrival_date IS NOT NULL AND ecs2.name IN ('Won', 'Đặt cọc', 'Đang xử lý') THEN 'Thành Công'
            WHEN ecl.arrival_date IS NOT NULL AND ecs2.name NOT IN ('Won', 'Đặt cọc', 'Đang xử lý') THEN 'Đến Cửa'
            WHEN ecl.arrival_date IS NULL AND ecl.type_crm_id = '2' THEN 'Booking'
            WHEN ecl.arrival_date IS NULL AND ecl.type_crm_id = '1' THEN 'Lead'
        END AS Phan_Loai_Khach,
        ect.name AS Loai_BK,
        CASE 
            WHEN spt.payment = 0 OR spt.payment IS NULL THEN erb3."name" 
            ELSE erb."name" 
        END AS Thuong_hieu,
        sp.product_category AS Nhom_DV,
        sp.product AS Ten_DV,
        CASE 
            WHEN spt.payment = 0 OR spt.payment IS NULL THEN mrc3."name" 
            ELSE mrc."name" 
        END AS Chi_Nhanh,
        CASE 
            WHEN spt.payment = 0 OR spt.payment IS NULL THEN mrc3.id 
            ELSE mrc.id 
        END AS chinhanhphanquyen,
        ecl.create_by_department AS Phong_ban_nguoi_tao,
        ss.source AS Nguon_moi,
        ss.newcat_source AS Nhom_nguon_moi,
        ecl.source_id AS Nguon_bk_id,
        sp.default_code AS id_dv,
        spt.ma_phieu,
        CONCAT(ecl.id, ecl2.id, spt.id) AS fk,
        CAST(NULL AS FLOAT) AS tien_ap
    FROM ecl 
    LEFT JOIN {{ source('crm_base', 'res_brand') }} erb3 ON erb3.id = ecl.brand_id AND erb3.brand_etl = 1 
    LEFT JOIN {{ source('crm_base', 'm_res_company') }} mrc3 ON mrc3.id = ecl.company_id AND mrc3.brand_etl = 1
    LEFT JOIN cline ecl2 ON ecl2.crm_id = ecl.id
    LEFT JOIN {{ source('crm_base', 'stag_products') }} sp ON sp.product_id = ecl2.product_id  
    LEFT JOIN (SELECT * FROM {{ source('crm_base', 'stag_payment_transfer') }} spt WHERE spt.brand_etl IN (0,1)) spt 
        ON spt.clineid = ecl2.id AND spt.crm_id = ecl.id 
    LEFT JOIN (SELECT * FROM {{ source('crm_base', 'account_payment') }} eap WHERE eap.brand_etl IN (0,1)) eap 
        ON eap."name" = spt.ma_phieu  
    LEFT JOIN {{ source('crm_base', 'm_res_company') }} mrc ON mrc.id = spt.company_id AND mrc.brand_etl = 1
    LEFT JOIN {{ source('crm_base', 'res_brand') }} erb ON erb.id = mrc.brand_id AND erb.brand_etl = 1 
    LEFT JOIN {{ source('crm_base', 'stag_employees') }} se ON se.kn_user_id = ecl.create_by
    LEFT JOIN {{ source('crm_base', 'crm_stage') }} ecs2 ON ecs2.id = ecl.stage_id AND ecs2.brand_etl = 1
    LEFT JOIN {{ source('crm_base', 'crm_type') }} ect ON ect.id = ecl.type_crm_id AND ect.brand_etl = 1
    LEFT JOIN {{ source('crm_base', 'stag_sources') }} ss ON ss.old_id = ecl.source_id
    WHERE DATE(ecl.create_on) >= '2024-01-01'
        AND ecl.active = true 
        AND ecl.create_by <> 0
)
SELECT * FROM a

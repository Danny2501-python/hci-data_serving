WITH revenue_union AS (
    (SELECT 
        ecl.note, -- tiền dịch vụ SM 
        cw."result",
        epp.default_code AS code_dv, 
        ecl.contact_name AS Ten_Khach,
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
            WHEN ecl.arrival_date IS NULL THEN ecl.create_on::DATE 
        END AS Date_Time,
        ecl.name AS Ma_Booking,
        erp."name" AS Nhan_Vien,
        spt.payment AS doanh_so,
        ecl2.total_received AS Tong_tien,
        'posted' AS vao_so,
        ecs2.name AS Trang_Thai,
        CASE 
            WHEN spt.id LIKE '%to%' THEN 'Transfer'
            WHEN spt.id LIKE '%ti%' THEN 'Receive'
            ELSE ecl2.stage 
        END AS Line_tt,
        CASE
            WHEN ecl.arrival_date IS NOT NULL AND ecs2.name IN ('Won','Đặt cọc', 'Đang xử lý') THEN 'Thành Công'
            WHEN ecl.arrival_date IS NOT NULL AND ecs2.name NOT IN ('Won', 'Đặt cọc', 'Đang xử lý') THEN 'Đến Cửa'
            WHEN ecl.arrival_date IS NULL AND ecl.type_crm_id = '2' THEN 'Booking'
            WHEN ecl.arrival_date IS NULL AND ecl.type_crm_id = '1' THEN 'Lead'
        END AS Phan_Loai_Khach,  -- lead, BK, DC, TC 
        ect.name AS Loai_BK,
        CASE 
            WHEN spt.payment = 0 OR spt.payment IS NULL THEN erb3."name" 
            ELSE erb."name" 
        END AS Thuong_hieu,
        epc.name AS Nhom_DV,
        ept.name AS Ten_DV,
        CASE 
            WHEN spt.payment = 0 OR spt.payment IS NULL THEN mrc3."name" 
            ELSE mrc."name" 
        END AS Chi_Nhanh,
        CASE 
            WHEN spt.payment = 0 OR spt.payment IS NULL THEN mrc3.id 
            ELSE mrc.id 
        END AS chinhanhphanquyen_notuse,
        ecl.create_by_department AS Phong_ban_nguoi_tao,
        ss2."org_source" AS Nguon_moi,
        ss.category_source AS Nhom_nguon_moi,
        ect.name "LoaiKH",
        ecl.type_data_partner,
        CASE WHEN ss.old_id IS NOT NULL THEN (
            CASE 
                WHEN ss.old_id IN (128,70,71,134, 67,62,164,68,92,97,63,61,64,65,126,72,165,127,95,137,60,100,166,58,59,57,56,55,4,101,163,54,53,73) THEN 'DS MKT' 
                WHEN ss.old_id = 79 THEN 'DS khai thác chéo CNK'
                WHEN ss.old_id IN (86,85,125,91,96,123,94,138,129) THEN 'DS nguồn CN'
                WHEN ss.old_id IN (75,167,130,74,77,76,69) THEN 'DS nguồn CTV'
                WHEN ss.old_id IN (87,89,90) THEN 'DS thuê phòng mổ'
                WHEN ss.old_id IN (81,124,82,80) THEN 'DS Khác' 
            END)
        END AS nguon_moi_new,
        CASE WHEN ss.old_id IS NOT NULL THEN (
            CASE 
                WHEN ss.old_id IN (128,70,71,134, 67,62,164,68,92,97,63,61,64,65,126,72,165,127,95,137,60,100,166,58,59,57,56,55,4,101,163,54,53,73) THEN 2
                WHEN ss.old_id = 79 THEN 4
                WHEN ss.old_id IN (86,85,125,91,96,123,94,138,129) THEN 3
                WHEN ss.old_id IN (75,167,130,74,77,76,69) THEN 1 
            END)
        END AS ma_nguon_moi_new,
        ss.old_id AS nguon_ds_id,
        ecl2.total_received AS tien_da_thu,
        ecl2.cancel_user,
        se1.company_id AS cty_cancel,
        se.employee,
        cic.role,
        se.company_id AS cty_tv,
        spt.ma_phieu AS ma_phieu,
        ecl2.id AS clineid,
        spt.payment_type,
        ecl2.total AS tien_phai_thu,
        ecl.overseas_vietnamese 
    FROM (SELECT * FROM {{ source('ptdbdsp_erp', 'crm_lead') }} WHERE brand_etl = 3) ecl 
    LEFT JOIN (SELECT * FROM {{ source('ptdbdsp_erp', 'res_brand') }} WHERE brand_etl = 3) erb3 ON erb3.id = ecl.brand_id  
    LEFT JOIN (SELECT * FROM {{ source('ptdbdsp_erp', 'm_res_company') }} WHERE brand_etl = 3) mrc3 ON mrc3.id = ecl.company_id 
    LEFT JOIN (SELECT * FROM {{ source('ptdbdsp_erp', 'crm_line') }} WHERE brand_etl = 3) ecl2 ON ecl2.crm_id = ecl.id
    LEFT JOIN (
        WITH sub_cic AS (
            SELECT cic.user_id, cic."role", cic.crm_line_id, ROW_NUMBER() OVER(PARTITION BY crm_line_id ORDER BY write_date DESC) AS r 
            FROM (SELECT * FROM {{ source('ptdbdsp_erp', 'crm_information_consultant') }} WHERE brand_etl = 3) cic
        )
        SELECT * FROM sub_cic WHERE r = 1
    ) cic ON cic.crm_line_id = ecl2.id
    LEFT JOIN (SELECT * FROM {{ source('ptdbdsp_erp', 'view_stag_employees_user') }} WHERE brand_etl = 3) se ON se.user_id = cic.user_id 
    LEFT JOIN (SELECT * FROM {{ source('ptdbdsp_erp', 'view_stag_employees_user') }} WHERE brand_etl = 3) se1 ON se1.user_id = ecl2.cancel_user 
    LEFT JOIN (SELECT * FROM {{ source('ptdbdsp_erp', 'crm_stage') }} WHERE brand_etl = 3) ecs ON ecs.id = ecl.stage_id
    LEFT JOIN (SELECT * FROM {{ source('ptdbdsp_erp', 'hr_department') }} WHERE brand_etl = 3) ehd ON ecl.department_id = ehd.id 
    LEFT JOIN (SELECT * FROM {{ source('ptdbdsp_erp', 'crm_stage') }} WHERE brand_etl = 3) ecs2 ON ecs2.id = ecl.stage_id
    LEFT JOIN (SELECT * FROM {{ source('ptdbdsp_erp', 'crm_type') }} WHERE brand_etl = 3) ect ON ect.id = ecl.type_crm_id
    LEFT JOIN (SELECT * FROM {{ source('ptdbdsp_erp', 'sh_medical_health_center_service') }} WHERE brand_etl = 3) esmhcs ON esmhcs.product_id = ecl2.product_id
    LEFT JOIN (SELECT * FROM {{ source('ptdbdsp_erp', 'sh_medical_health_center_service_category') }} WHERE brand_etl = 3) esmhcsc ON esmhcsc.id = esmhcs.service_category
    LEFT JOIN (SELECT * FROM {{ source('ptdbdsp_erp', 'utm_source') }} WHERE brand_etl = 3) eus ON eus.id = ecl.source_id
    LEFT JOIN (SELECT * FROM {{ source('ptdbdsp_erp', 'product_category') }} WHERE brand_etl = 3) epc ON epc.id = esmhcsc.product_cat_id
    LEFT JOIN (SELECT * FROM {{ source('ptdbdsp_erp', 'res_users') }} WHERE brand_etl = 3) eru ON eru.id = ecl.create_by
    LEFT JOIN (SELECT * FROM {{ source('ptdbdsp_erp', 'utm_source') }} WHERE brand_etl = 3) eus2 ON eus2.id = ecl.source_id
    LEFT JOIN (SELECT * FROM {{ source('ptdbdsp_erp', 'product_product') }} WHERE brand_etl = 3) epp ON epp.id = ecl2.product_id 
    LEFT JOIN (SELECT * FROM {{ source('ptdbdsp_erp', 'product_template') }} WHERE brand_etl = 3) ept ON ept.id = epp.product_tmpl_id 
    LEFT JOIN (SELECT * FROM {{ source('ptdbdsp_erp', 'res_partner') }} WHERE brand_etl = 3) erp ON erp.id = eru.partner_id
    LEFT JOIN (SELECT * FROM {{ source('ptdbdsp_erp', 'stag_payment_transfer') }} WHERE brand_etl = 3) spt ON spt.clineid = ecl2.id AND ecl2.product_id = spt.product_id 
    LEFT JOIN (SELECT * FROM {{ source('ptdbdsp_erp', 'm_res_company') }} WHERE brand_etl = 3) mrc ON spt.company_id = mrc.id
    LEFT JOIN (SELECT * FROM {{ source('ptdbdsp_erp', 'res_brand') }} WHERE brand_etl = 3) erb ON erb.id = mrc.brand_id 
    LEFT JOIN (SELECT * FROM {{ source('ptdbdsp_erp', 'stag_sources') }} WHERE brand_etl = 3) ss ON ss.old_id = ecl.source_id
    LEFT JOIN (SELECT * FROM {{ source('ptdbdsp_erp', 'stag_sources') }} WHERE brand_etl = 3) ss2 ON ss2.old_id = ss.id_pr
    LEFT JOIN (SELECT * FROM {{ source('ptdbdsp_erp', 'dm_convert_case_when') }} WHERE brand_etl = 3) cw ON cw.value_case_when = ecl.reason_out_sold AND cw.column_name = 'reason_out_sold'
    WHERE ecl2.product_id IS NOT NULL)

    UNION ALL	

    (SELECT -- tiền sản phẩm SM
        ecl.note, 
        cw."result",
        'SP' AS code_dv,
        ecl.contact_name AS Ten_Khach,
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
            WHEN ecl.arrival_date IS NULL THEN ecl.create_on::DATE 
        END AS Date_Time,
        ecl.name AS Ma_Booking,
        erp."name" AS Nhan_Vien,
        spt.payment AS doanh_so,
        eclp.total_received AS Tong_tien,
        'posted' AS vao_so,
        ecs2.name AS Trang_Thai,
        CASE 
            WHEN spt.id LIKE '%to%' THEN 'Transfer'
            WHEN spt.id LIKE '%ti%' THEN 'Receive'
            ELSE eclp.stage_line_product 
        END AS Line_tt,
        CASE
            WHEN ecl.arrival_date IS NOT NULL AND ecs2.name IN ('Won','Đặt cọc', 'Đang xử lý') THEN 'Thành Công'
            WHEN ecl.arrival_date IS NOT NULL AND ecs2.name NOT IN ('Won', 'Đặt cọc', 'Đang xử lý') THEN 'Đến Cửa'
            WHEN ecl.arrival_date IS NULL AND ecl.type_crm_id = '2' THEN 'Booking'
            WHEN ecl.arrival_date IS NULL AND ecl.type_crm_id = '1' THEN 'Lead'
        END AS Phan_Loai_Khach,  -- lead, BK, DC, TC 
        ect.name AS Loai_BK,
        CASE 
            WHEN spt.payment = 0 OR spt.payment IS NULL THEN erb4."name" 
            ELSE erb."name" 
        END AS Thuong_hieu,
        CASE 
            WHEN ept.name IS NOT NULL THEN 'Sản Phẩm'
            ELSE NULL 
        END AS Nhom_DV,
        ept.name AS Ten_DV,
        CASE 
            WHEN spt.payment = 0 OR spt.payment IS NULL THEN mrc4."name" 
            ELSE mrc."name"  
        END AS Chi_Nhanh,
        CASE 
            WHEN spt.payment = 0 OR spt.payment IS NULL THEN mrc4.id
            ELSE mrc.id 
        END AS chinhanhphanquyen_notuse,
        ecl.create_by_department AS Phong_ban_nguoi_tao,
        ss2."org_source" AS Nguon_moi,
        ss.category_source AS Nhom_nguon_moi,
        ect.name "LoaiKH",
        ecl.type_data_partner,
        CASE WHEN ss.old_id IS NOT NULL THEN (
            CASE 
                WHEN ss.old_id IN (128,70,71,134, 67,62,164,68,92,97,63,61,64,65,126,72,165,127,95,137,60,100,166,58,59,57,56,55,4,101,163,54,53,73) THEN 'DS MKT' 
                WHEN ss.old_id = 79 THEN 'DS khai thác chéo CNK'
                WHEN ss.old_id IN (86,85,125,91,96,123,94,138,129) THEN 'DS nguồn CN'
                WHEN ss.old_id IN (75,167,130,74,77,76,69) THEN 'DS nguồn CTV'
                WHEN ss.old_id IN (87,89,90) THEN 'DS thuê phòng mổ'
                WHEN ss.old_id IN (81,124,82,80) THEN 'DS Khác' 
            END)
        END AS nguon_moi_new,
        CASE WHEN ss.old_id IS NOT NULL THEN (
            CASE 
                WHEN ss.old_id IN (128,70,71,134, 67,62,164,68,92,97,63,61,64,65,126,72,165,127,95,137,60,100,166,58,59,57,56,55,4,101,163,54,53,73) THEN 2
                WHEN ss.old_id = 79 THEN 4
                WHEN ss.old_id IN (86,85,125,91,96,123,94,138,129) THEN 3
                WHEN ss.old_id IN (75,167,130,74,77,76,69) THEN 1 
            END)
        END AS ma_nguon_moi_new,
        ss.old_id AS nguon_ds_id,
        eclp.total_received AS tien_da_thu,
        100 AS cancel_user,
        100 AS cty_cancel,
        se.employee,
        cic.role,
        se.company_id AS cty_tv,
        spt.ma_phieu AS ma_phieu,
        eclp.id AS clineid,
        spt.payment_type,
        eclp.total AS tien_phai_thu,
        ecl.overseas_vietnamese 
    FROM (SELECT * FROM {{ source('ptdbdsp_erp', 'crm_lead') }} WHERE brand_etl = 3) ecl 
    LEFT JOIN (SELECT * FROM {{ source('ptdbdsp_erp', 'm_res_company') }} WHERE brand_etl = 3) mrc4 ON mrc4.id = ecl.company_id
    LEFT JOIN (SELECT * FROM {{ source('ptdbdsp_erp', 'res_brand') }} WHERE brand_etl = 3) erb4 ON erb4.id = ecl.brand_id 
    LEFT JOIN (SELECT * FROM {{ source('ptdbdsp_erp', 'crm_line_product') }} WHERE brand_etl = 3) eclp ON eclp.booking_id = ecl.id
    LEFT JOIN (
        WITH sub_cic AS (
            SELECT cic.user_id, cic."role", cic.crm_line_product_id, ROW_NUMBER() OVER(PARTITION BY crm_line_id ORDER BY write_date DESC) AS r 
            FROM (SELECT * FROM {{ source('ptdbdsp_erp', 'crm_information_consultant') }} WHERE brand_etl = 3) cic
        )
        SELECT * FROM sub_cic WHERE r = 1
    ) cic ON cic.crm_line_product_id = eclp.id 
    LEFT JOIN (SELECT * FROM {{ source('ptdbdsp_erp', 'view_stag_employees_user') }} WHERE brand_etl = 3) se ON se.user_id = cic.user_id 
    LEFT JOIN (SELECT * FROM {{ source('ptdbdsp_erp', 'crm_stage') }} WHERE brand_etl = 3) ecs ON ecs.id = ecl.stage_id
    LEFT JOIN (SELECT * FROM {{ source('ptdbdsp_erp', 'hr_department') }} WHERE brand_etl = 3) ehd ON ecl.department_id = ehd.id 
    LEFT JOIN (SELECT * FROM {{ source('ptdbdsp_erp', 'crm_stage') }} WHERE brand_etl = 3) ecs2 ON ecs2.id = ecl.stage_id
    LEFT JOIN (SELECT * FROM {{ source('ptdbdsp_erp', 'crm_type') }} WHERE brand_etl = 3) ect ON ect.id = ecl.type_crm_id
    LEFT JOIN (SELECT * FROM {{ source('ptdbdsp_erp', 'sh_medical_health_center_service') }} WHERE brand_etl = 3) esmhcs ON esmhcs.product_id = eclp.product_id
    LEFT JOIN (SELECT * FROM {{ source('ptdbdsp_erp', 'sh_medical_health_center_service_category') }} WHERE brand_etl = 3) esmhcsc ON esmhcsc.id = esmhcs.service_category
    LEFT JOIN (SELECT * FROM {{ source('ptdbdsp_erp', 'utm_source') }} WHERE brand_etl = 3) eus ON eus.id = ecl.source_id
    LEFT JOIN (SELECT * FROM {{ source('ptdbdsp_erp', 'product_category') }} WHERE brand_etl = 3) epc ON epc.id = esmhcsc.product_cat_id
    LEFT JOIN (SELECT * FROM {{ source('ptdbdsp_erp', 'res_users') }} WHERE brand_etl = 3) eru ON eru.id = ecl.create_by
    LEFT JOIN (SELECT * FROM {{ source('ptdbdsp_erp', 'utm_source') }} WHERE brand_etl = 3) eus2 ON eus2.id = ecl.source_id
    LEFT JOIN (SELECT * FROM {{ source('ptdbdsp_erp', 'product_product') }} WHERE brand_etl = 3) epp ON epp.id = eclp.product_id 
    LEFT JOIN (SELECT * FROM {{ source('ptdbdsp_erp', 'product_template') }} WHERE brand_etl = 3) ept ON ept.id = epp.product_tmpl_id 
    LEFT JOIN (SELECT * FROM {{ source('ptdbdsp_erp', 'res_partner') }} WHERE brand_etl = 3) erp ON erp.id = eru.partner_id
    LEFT JOIN (SELECT * FROM {{ source('ptdbdsp_erp', 'stag_payment_transfer') }} WHERE brand_etl = 3) spt ON spt.clineid = eclp.id AND spt.product_id = eclp.product_id  
    LEFT JOIN (SELECT * FROM {{ source('ptdbdsp_erp', 'm_res_company') }} WHERE brand_etl = 3) mrc ON spt.company_id = mrc.id
    LEFT JOIN (SELECT * FROM {{ source('ptdbdsp_erp', 'res_brand') }} WHERE brand_etl = 3) erb ON erb.id = mrc.brand_id
    LEFT JOIN (SELECT * FROM {{ source('ptdbdsp_erp', 'stag_sources') }} WHERE brand_etl = 3) ss ON ss.old_id = ecl.source_id
    LEFT JOIN (SELECT * FROM {{ source('ptdbdsp_erp', 'stag_sources') }} WHERE brand_etl = 3) ss2 ON ss2.old_id = ss.id_pr
    LEFT JOIN (SELECT * FROM {{ source('ptdbdsp_erp', 'dm_convert_case_when') }} WHERE brand_etl = 3) cw ON cw.value_case_when = ecl.reason_out_sold AND cw.column_name = 'reason_out_sold'
    WHERE eclp.stage_line_product IS NOT NULL)

    UNION ALL 

    (SELECT 
        cl.note,
        cw."result",
        NULL AS code_dv, 
        rp."name" AS kh,
        ap.crm_id,
        rp.code_customer,
        cl.phone AS dien_thoai,
        DATE(cl.arrival_date + '7:00:00'::interval) AS arrival_date, 
        cl.type_crm_id,
        DATE(cl.create_on + '7:00:00'::interval) AS create_on,
        DATE(cl.arrival_date + '7:00:00'::interval) AS arrival_date_dup,
        DATE(cl.booking_date + '7:00:00'::interval) AS booking_date,
        DATE(ap.payment_date + '7:00:00'::interval) AS payment_date, 
        CASE 
            WHEN cl.arrival_date IS NOT NULL THEN DATE(cl.arrival_date + '7:00:00'::interval)
            ELSE DATE(cl.create_on + '7:00:00'::interval)
        END,
        cl."name" AS bk,
        NULL AS nhan_vien,
        ap.amount,
        NULL::integer AS tong_tien,
        'posted' AS vao_so,
        cs."name" AS tt_book,
        NULL AS line_tt,
        CASE
            WHEN cl.arrival_date IS NOT NULL AND cs."name" IN ('Won','Đặt cọc', 'Đang xử lý') THEN 'Thành Công'
            WHEN cl.arrival_date IS NOT NULL AND cs."name" NOT IN ('Won', 'Đặt cọc', 'Đang xử lý') THEN 'Đến Cửa'
            WHEN cl.arrival_date IS NULL AND cl.type_crm_id = '2' THEN 'Booking'
            WHEN cl.arrival_date IS NULL AND cl.type_crm_id = '1' THEN 'Lead'
        END AS Phan_Loai_Khach,  -- lead, BK, DC, TC 
        ct."name" AS loai_bk,
        rb."name" AS thuong_hieu, 
        NULL AS nhom_dv,
        NULL AS ten_dv,
        CASE WHEN rc2."name" IS NULL THEN rc."name" ELSE rc2."name" END AS "Chi_nhanh",
        CASE WHEN ap.x_receive_company_id IS NULL THEN ap.company_id ELSE ap.x_receive_company_id END AS cnpq_nuse,
        cl.create_by_department,
        ss2."org_source" AS nguon_moi,
        ss.category_source AS nhom_nguon_moi,
        ct."name" AS loai_bk_dup,
        cl.type_data_partner,
        CASE WHEN ss.old_id IS NOT NULL THEN (
            CASE 
                WHEN ss.old_id IN (128,70,71,134, 67,62,164,68,92,97,63,61,64,65,126,72,165,127,95,137,60,100,166,58,59,57,56,55,4,101,163,54,53,73) THEN 'DS MKT' 
                WHEN ss.old_id = 79 THEN 'DS khai thác chéo CNK'
                WHEN ss.old_id IN (86,85,125,91,96,123,94,138,129) THEN 'DS nguồn CN'
                WHEN ss.old_id IN (75,167,130,74,77,76,69) THEN 'DS nguồn CTV'
                WHEN ss.old_id IN (87,89,90) THEN 'DS thuê phòng mổ'
                WHEN ss.old_id IN (81,124,82,80) THEN 'DS Khác' 
            END)
        END AS nguon_moi_new,
        CASE WHEN ss.old_id IS NOT NULL THEN (
            CASE 
                WHEN ss.old_id IN (128,70,71,134, 67,62,164,68,92,97,63,61,64,65,126,72,165,127,95,137,60,100,166,58,59,57,56,55,4,101,163,54,53,73) THEN 2
                WHEN ss.old_id = 79 THEN 4
                WHEN ss.old_id IN (86,85,125,91,96,123,94,138,129) THEN 3
                WHEN ss.old_id IN (75,167,130,74,77,76,69) THEN 1 
            END)
        END AS ma_nguon_moi_new,
        ss.old_id,
        0 AS tien_da_thu,
        100 AS cancel_user,
        100 AS cty_cancel,
        '' AS employee,
        '' AS role,
        100 AS cty_tv,
        ap.name AS ma_phieu,
        0 AS clineid,
        ap.payment_type,
        0 AS tien_phai_thu,
        cl.overseas_vietnamese 
    FROM (SELECT * FROM {{ source('ptdbdsp_erp', 'account_payment') }} WHERE brand_etl = 3) ap
    LEFT JOIN (SELECT * FROM {{ source('ptdbdsp_erp', 'crm_lead') }} WHERE brand_etl = 3) cl ON cl.id = ap.crm_id 
    LEFT JOIN (SELECT * FROM {{ source('ptdbdsp_erp', 'res_partner') }} WHERE brand_etl = 3) rp ON rp.id = ap.partner_id
    LEFT JOIN (SELECT * FROM {{ source('ptdbdsp_erp', 'res_brand') }} WHERE brand_etl = 3) rb ON rb.id = ap.brand_id 
    LEFT JOIN (SELECT * FROM {{ source('ptdbdsp_erp', 'm_res_company') }} WHERE brand_etl = 3) rc ON rc.id = ap.company_id 
    LEFT JOIN (SELECT * FROM {{ source('ptdbdsp_erp', 'm_res_company') }} WHERE brand_etl = 3) rc2 ON rc2.id = ap.x_receive_company_id 
    LEFT JOIN (SELECT * FROM {{ source('ptdbdsp_erp', 'stag_sources') }} WHERE brand_etl = 3) ss ON cl.source_id = ss.old_id 
    LEFT JOIN (SELECT * FROM {{ source('ptdbdsp_erp', 'stag_sources') }} WHERE brand_etl = 3) ss2 ON ss2.old_id = ss.id_pr
    LEFT JOIN (SELECT * FROM {{ source('ptdbdsp_erp', 'crm_stage') }} WHERE brand_etl = 3) cs ON cs.id = cl.stage_id
    LEFT JOIN (SELECT * FROM {{ source('ptdbdsp_erp', 'crm_type') }} WHERE brand_etl = 3) ct ON ct.id = cl.type_crm_id
    LEFT JOIN (SELECT * FROM {{ source('ptdbdsp_erp', 'dm_convert_case_when') }} WHERE brand_etl = 3) cw ON cw.value_case_when = cl.reason_out_sold AND cw.column_name = 'reason_out_sold'
    WHERE ap.state = 'posted'
      AND DATE(ap.payment_date + '7:00:00'::interval) > '20211231' AND DATE(ap.payment_date + '7:00:00'::interval) < '20230101'
      AND ap.brand_id = 3 AND ap."name" LIKE 'CUST%'
      AND NOT EXISTS (SELECT 1 FROM (SELECT * FROM {{ source('ptdbdsp_erp', 'crm_account_payment_detail') }} WHERE brand_etl = 3) cappd WHERE cappd.account_payment_id = ap.id)
      AND NOT EXISTS (SELECT 1 FROM (SELECT * FROM {{ source('ptdbdsp_erp', 'crm_account_payment_product_detail') }} WHERE brand_etl = 3) cappd WHERE cappd.account_payment_id = ap.id)
) ),

processed_th AS (
    SELECT *, 
        CASE 
            WHEN role = 'recept' THEN 1
            WHEN role = 'doctor' THEN 2
            WHEN role = 'support' THEN 3
        END AS role1,
        CASE 
            WHEN cancel_user IS NULL THEN 'G'
            WHEN cancel_user = 100 THEN 'K'
            ELSE 'G'
        END AS loai_line_dv,
        CASE 
            WHEN code_dv = 'SP' THEN chinhanhphanquyen_notuse 
            ELSE (
                CASE 
                    WHEN cancel_user IS NOT NULL AND cty_cancel <> 1 AND cty_tv IS NULL THEN cty_cancel 
                    WHEN cty_tv = chinhanhphanquyen_notuse THEN chinhanhphanquyen_notuse 
                    WHEN cty_tv IN (1,2,4,5,6,7,8,10,11,12,27,29,30,34,37,40,50) AND cty_tv <> chinhanhphanquyen_notuse THEN chinhanhphanquyen_notuse 
                    WHEN cty_tv IS NOT NULL AND cty_tv NOT IN (1,2,4,5,6,7,8,10,11,12,27,29,30,34,37,40,50) THEN cty_tv
                    WHEN cty_tv <> chinhanhphanquyen_notuse THEN chinhanhphanquyen_notuse  
                    WHEN cty_tv IS NULL AND chinhanhphanquyen_notuse IS NOT NULL THEN chinhanhphanquyen_notuse 
                    WHEN cty_tv IS NULL AND (cty_cancel IS NULL OR cty_cancel = 100) AND chinhanhphanquyen_notuse IS NOT NULL THEN chinhanhphanquyen_notuse 
                END  
            )
        END AS chinhanhphanquyen_nu
    FROM revenue_union
)

SELECT processed_th.*, 
    ROW_NUMBER() OVER(PARTITION BY ngay_tt, ma_phieu, payment_type, doanh_so, clineid ORDER BY ngay_tt, role1) AS no_clined,
    mrc.name AS n_chinhanh, rb.id AS thuonghieuphanquyen, rb.name AS thuonghieu
FROM processed_th
LEFT JOIN (SELECT * FROM {{ source('ptdbdsp_erp', 'm_res_company') }} WHERE brand_etl = 3) mrc ON processed_th.chinhanhphanquyen_nu = mrc.id 
LEFT JOIN (SELECT * FROM {{ source('ptdbdsp_erp', 'res_brand') }} WHERE brand_etl = 3) rb ON rb.id = mrc.brand_id

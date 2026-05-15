-- Bang stg_pts_all_payment: bang phieu thanh toan phat sinh
SELECT concat('ps-', capd.id) AS id, 'service' as product_type, 
    ap.name AS ma_phieu, ap.crm_id, ap.payment_date, ap.payment_method, ap.communication, 
    cline.id AS clineid, cline.product_id, cline.quantity, cline.uom_price, cline.number_used,
    CASE WHEN cline.gia_truoc_huy > 0 THEN cline.gia_truoc_huy ELSE cline.total END AS total,
    capd.total_received, cline.total_received total_received_cline, 
    CASE WHEN ap.payment_type = 'outbound' THEN - capd.prepayment_amount ELSE capd.prepayment_amount END AS payment,
    ap.payment_type,
    cline.stage AS stage_product, cline.consultants_1, cline.consulting_role_1, cline.consultants_2, cline.consulting_role_2, cline.ho_tro,
    cline.price_list_id,
    ap.company_id AS orgcompany_id,
        CASE
            WHEN capd.company_id IS NOT NULL THEN capd.company_id
            WHEN ap.x_receive_company_id IS NULL OR ap.x_receive_company_id = 0 THEN ap.company_id
            ELSE ap.x_receive_company_id
        END AS company_id,
    (ap.write_date + interval '7 hours') write_date, 
    ap.brand_id, ap.brand_etl
FROM {{source('pre_tns', 'crm_account_payment_detail')}} capd
    LEFT JOIN {{source('pre_tns', 'account_payment')}} ap ON capd.account_payment_id = ap.id AND ap.brand_etl = capd.brand_etl
    LEFT JOIN {{source('pre_tns', 'crm_line')}} cline ON capd.crm_line_id = cline.id AND cline.brand_etl = capd.brand_etl
WHERE capd.brand_etl IN {{var('all_brand_etl')}} AND 
    ap.state = 'posted' AND capd.prepayment_amount <> 0 
    AND ap.crm_id IN (SELECT crm_id FROM {{ ref('stg_pts_stag_payment_transfer_crm_id_update') }} WHERE brand_etl IN {{var('all_brand_etl')}})
UNION ALL
SELECT concat('pc-', cappd.id) AS id, 'cosmetic' as product_type, 
    ap.name AS ma_phieu, ap.crm_id, ap.payment_date, ap.payment_method, ap.communication, 
    clinep.id AS clineid, clinep.product_id, clinep.product_uom_qty AS quantity, 1 AS uom_price,
    CASE WHEN clinep.stage_line_product = 'sold' THEN clinep.product_uom_qty ELSE 0 END AS number_used,
    clinep.total,
    cappd.total_received, clinep.total_received total_received_cline, 
    CASE WHEN ap.payment_type = 'outbound' THEN - cappd.prepayment_amount ELSE cappd.prepayment_amount END AS payment,
    ap.payment_type,
    clinep.stage_line_product AS stage_product, clinep.consultants_1, clinep.consulting_role_1, clinep.consultants_2, clinep.consulting_role_2,
    NULL::integer AS ho_tro,
    clinep.product_pricelist_id AS price_list_id,
    ap.company_id AS orgcompany_id,
        CASE
            WHEN cappd.company_id IS NOT NULL THEN cappd.company_id
            WHEN ap.x_receive_company_id IS NULL OR ap.x_receive_company_id = 0 THEN ap.company_id
            ELSE ap.x_receive_company_id
        END AS company_id,
    (ap.write_date + interval '7 hours') write_date,
    ap.brand_id, ap.brand_etl
FROM {{source('pre_tns','crm_account_payment_product_detail')}} cappd
    LEFT JOIN {{source('pre_tns','account_payment')}} ap ON cappd.account_payment_id = ap.id AND ap.brand_etl = cappd.brand_etl
    LEFT JOIN {{source('pre_tns','crm_line_product')}} clinep ON cappd.crm_line_product_id = clinep.id AND clinep.brand_etl = cappd.brand_etl
WHERE cappd.brand_etl IN {{var('all_brand_etl')}} AND 
    ap.state = 'posted' AND cappd.prepayment_amount <> 0 
    AND ap.crm_id IN (SELECT crm_id FROM {{ ref('stg_pts_stag_payment_transfer_crm_id_update') }} WHERE brand_etl IN {{var('all_brand_etl')}})
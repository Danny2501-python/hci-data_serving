-- Bảng stg_pts_stag_crm_line_sync:
WITH cline_old AS  
(
SELECT hl.brand_etl, clineo.crm_id crm_id_old, cline.crm_id, hl.id_old, hl.crm_line_id clineid, cline.product_id, --sp.product, 
	clineo.quantity quantity_old, clineo.uom_price uom_price_old, clineo.number_used number_used_old, 
    clineo.total_before_discount total_before_discount_old, clineo.total total_old, clineo.total_received total_received_old, clineo.stage stage_old, 
	cline.quantity, cline.number_used, cline.total_before_discount, cline.total, cline.total_received, cline.total_discount, 
	hl.create_date 
FROM {{source('pre_tns','crm_sync_crm_line')}} hl 
    LEFT JOIN {{source('pre_tns','crm_line')}} cline on hl.crm_line_id = cline.id AND hl.brand_etl = cline.brand_etl 
    LEFT JOIN {{source('pre_tns','crm_line')}} clineo on hl.id_old = clineo.id AND clineo.brand_etl = 0
--LEFT JOIN view_stag_products sp on cline.product_id = sp.product_id AND cline.brand_etl = sp.brand_etl 
)
SELECT csb.brand_etl, csb.id_old crm_id_old, csb.crm_id, 
	cline.id clineid, cline.product_id, sp.product_category, sp.product, 
	co.quantity_old, co.uom_price_old, co.number_used_old, co.total_before_discount_old, co.total_old, co.total_received_old, co.stage_old, 
	cline.quantity, cline.uom_price, cline.number_used, cline.total_before_discount, cline.total, cline.total_received, cline.stage, 
	capd.crm_line_id capd_clineid,  
	csb.create_date, cline.create_date AS cline_create_date, cline.create_uid cline_create_uid 
FROM {{source('pre_tns','crm_sync_brand')}} csb
    LEFT JOIN {{source('pre_tns','crm_line')}} cline on csb.crm_id = cline.crm_id AND csb.brand_etl = cline.brand_etl 
    LEFT JOIN {{source('pre_tns','view_stag_products')}} sp on cline.product_id = sp.product_id AND cline.brand_etl = sp.brand_etl 
    LEFT JOIN {{source('pre_tns','cline_old')}} co on cline.id = co.clineid AND co.brand_etl = cline.brand_etl 
    LEFT JOIN (SELECT crm_line_id, brand_etl FROM {{source('pre_tns','crm_account_payment_detail')}} capd WHERE prepayment_amount <> 0 AND brand_etl <> 0 GROUP BY crm_line_id, brand_etl) 
        capd ON cline.id = capd.crm_line_id AND capd.brand_etl = cline.brand_etl
WHERE cline.id IS NOT NULL AND cline.stage <> 'cancel'
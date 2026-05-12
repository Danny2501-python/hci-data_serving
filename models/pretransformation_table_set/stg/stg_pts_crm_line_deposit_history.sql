-- Bảng stg_pts_crm_line_deposit_history
SELECT 
    csb.brand_etl, 
    csb.id_old AS crm_id_old, 
    csb.crm_id, 
	sp.product, 
	clineo.quantity, 
	clineo.uom_price, 
	clineo.number_used, 
	clineo.total_before_discount, 
	clineo.total, 
	clineo.total_received, 
	clineo.stage, 
	clineo.product_id, 
	csb.create_date, 
	count(*) OVER (PARTITION BY csb.id_old, clineo.product_id) AS count_line_samep 
FROM {{source('pre_tns','crm_sync_brand')}} csb  
    LEFT JOIN {{source('pre_tns','crm_line')}} clineo on csb.id_old = clineo.crm_id and clineo.brand_etl = 0
    LEFT JOIN {{source('pre_tns','view_stag_products')}} sp on clineo.product_id = sp.product_id and sp.brand_etl = 0
    LEFT JOIN {{source('pre_tns','crm_sync_crm_line')}} cscl on clineo.id = cscl.id_old and clineo.brand_etl = 0
WHERE cscl.id_old IS NULL AND clineo.total_received > 0 
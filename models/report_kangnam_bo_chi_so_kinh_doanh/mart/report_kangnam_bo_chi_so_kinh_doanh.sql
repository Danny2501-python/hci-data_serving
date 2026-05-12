SELECT d.*, 
	l.crm_id_lag1, l.date_diff, l.date_diff_arrival, l.date_diff_service, l.crm_id_old,  
	g.loyalty_discount, g.type_gift, 
	--sp.product_ctg_id, sp.his_service_type, sp.surgery_type, 
	--COALESCE(sp.product_category, 'SAN PHAM') AS product_category, sp.product, sp.is_no_kpi, 
	--cgc.booking_guarantee_id, 
    UPPER(rb.name) AS brand, 
    d.company_id AS chinhanhphanquyen, 
    d.brand_id AS thuonghieuphanquyen, 
    TO_CHAR(d.report_date, 'yyyymm') || d.company_id::text AS id_target_company
FROM {{ref('int_union_data')}} d
LEFT JOIN {{ref('stag_knbcskd_loyalty')}} l ON (d.crm_id, d.code_customer, d.brand_etl) = (l.crm_id, l.code_customer, l.brand_etl)
LEFT JOIN {{ref('int_knbcskd_giftd')}} g ON (d.crm_id, d.brand_etl) = (g.crm_id, g.brand_etl)
LEFT JOIN res_brand rb ON d.brand_id = rb.id AND rb.brand_etl = 7
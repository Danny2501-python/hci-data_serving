WITH limit_date AS 
	(SELECT '2025-08-01'::date AS ld)
--- Dữ liệu thanh toán (Doanh số bán)
SELECT 'payment' AS data_union, crm_id, type_crm_id, booking, code_customer, contact_name, 
        pm.type_data_partner, 
	payment_date AS "report_date", pm.ma_phieu AS form_name, pm.product_id, 
	--pm.product_ctg_id, pm.his_service_type, pm.surgery_type, pm.product_category, pm.product, 
	pm.uom_price, pm.quantity, 
	pm.payment amount, pm.total, pm.total_received, 0 as stage_id, pm.stage_product stage, 
	pm.rnk_clineid_pmdate,  
	pm.first_date_payment AS first_date, null::timestamp AS booking_date, pm.arrival_date, 
	NULL AS customer_come, pm.type_data_partner AS type_customer_arrived, 
	pm.category_source_id, pm.source_id, pm.category_source, pm."source", 
	null::text as reason_close_booking, 
        pm.price_list_id, pm.price_list, 
	pm.creator_employee_code, pm.creator_employee, pm.creator_department, 
	pm.orgcompany_id, pm.company_id, pm.company, pm.brand_id, pm.brand_etl
FROM {{source('kangnam_chi_so_kinh_doanh', 'report_kpi_bonus_commission')}} pm
WHERE pm.payment_date >= (SELECT ld FROM limit_date) AND pm.brand_id in (1,3)
UNION ALL
--- Dữ liệu Booking hẹn lịch (crm_lead)
SELECT DISTINCT ON (crm_id, brand_etl) 
        'crm_lead' AS data_union, crm_id, type_crm_id, booking, code_customer, contact_name, 
        bk.type_data_partner, 
	report_date, bk.booking AS form_name, bk.product_id, 
	--bk.product_ctg_id, bk.his_service_type, bk.surgery_type, bk.product_category, bk.product, 
	bk.uom_price, bk.quantity, 
	bk.amount_paid amount, bk.amount_total AS total, bk.amount_paid AS total_received, bk.stage_id, bk.stage, 
	bk.rn_consult_crm AS rnk_clineid_pmdate, 
	bk.services_date AS first_date, bk.booking_date, bk.arrival_date, 
	bk.customer_come, bk.type_customer_arrived, 
	bk.category_source_id, bk.source_id, bk.category_source, bk."source", 
	bk.reason_close_booking,  
        NULL::INT AS price_list_id, NULL AS price_list, 
	bk.creator_employee_code, bk.creator_employee, bk.creator_department, 
	bk.company_id orgcompany_id, bk.report_company_id AS company_id, 
	bk.report_company AS company, bk.report_brand_id AS brand_id, bk.brand_etl 
FROM {{source('kangnam_chi_so_kinh_doanh', 'report_crm_lead_customer_out_sold')}} bk
WHERE report_date >= (SELECT ld FROM limit_date) AND report_date < now() 
	AND brand_id in (1,3)
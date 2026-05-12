SELECT 
    scbwl.crm_id, 
    scbwl.code_customer, 
    scbwl.brand_etl, 
    scbwl.crm_id_lag1,  
    scbwl.date_diff, 
    scbwl.date_diff_arrival, 
    scbwl.date_diff_service, 
    scbwl.crm_id_old 
FROM {{source('kangnam_chi_so_kinh_doanh', 'stag_crm_booking_walkin_loyalty')}} scbwl 
WHERE type = 'opportunity'
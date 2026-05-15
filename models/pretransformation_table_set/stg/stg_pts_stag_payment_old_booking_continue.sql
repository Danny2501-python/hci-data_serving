SELECT DISTINCT ON (spt.crm_id, spt.clineid, spt.product_type)  
	spt.crm_id::int AS crm_id_old, 
    spt.clineid::int AS clineid,
    spt.product_id::int AS product_id,    --- spt.clineid AS clineid_old
    spt.crm_id::int AS crm_id, 
    first_date_payment, rnk_clineid_pmdate, 
    rnk_crm_pmdate, 
    total, 
    total_received_recal AS total_received_old, 
    quantity, 
    number_used, 
    stage_product AS stage, 
    spt.brand_etl::int,
    ROW_NUMBER() OVER (PARTITION BY spt.crm_id, spt.product_id, spt.brand_etl ORDER BY spt.first_date_payment DESC) as rn,
    MAX(rnk_crm_pmdate) OVER (PARTITION BY spt.crm_id) as max_rnk_crm_date
FROM {{source('pre_tns','stag_payment_transfer')}} spt 
--LEFT JOIN crm_sync_brand csb ON spt.crm_id = csb.id_old AND spt.brand_etl = 0
    INNER JOIN (
        SELECT DISTINCT crm_id 
        FROM {{source('pre_tns','stag_payment_transfer')}} 
        WHERE crm_id < 2174165 
            AND payment_date >= date_trunc('month', current_date - interval '1 month')::date
    ) new_transaction ON spt.crm_id = new_transaction.crm_id 
WHERE spt.brand_etl = 0 AND spt.product_type = 'service' 
ORDER BY spt.crm_id, spt.clineid, spt.product_type, spt.rnk_clineid_pmdate DESC
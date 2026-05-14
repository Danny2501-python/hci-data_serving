-- Bảng stg_pts_stag_payment_1st_date
WITH prep_data AS (
    SELECT 
        spt.crm_id AS crm_id_old, 
        spt.clineid AS clineid_old, 
        MAX(spt.product_id) AS product_id, 
        csb.crm_id, 
        MIN(spt.first_date_payment) AS first_date_payment, 
        MAX(spt.rnk_clineid_pmdate) AS last_rnk_clineid_pmdate, 
        MIN(csb.brand_etl) AS brand_etl
    FROM {{source('pre_tns','stag_payment_transfer')}} spt 
        LEFT JOIN {{source('pre_tns','crm_sync_brand')}} csb ON spt.crm_id = csb.id_old AND spt.brand_etl = 0
    WHERE csb.id IS NOT NULL AND spt.brand_etl = 0 AND spt.product_type = 'service' 
    GROUP BY 
        spt.crm_id, 
        csb.crm_id, 
        spt.clineid
)
SELECT 
    t.crm_id,
    t.crm_id_old,
    t.clineid_old,
    t.product_id,
    t.first_date_payment,
    t.last_rnk_clineid_pmdate,
    t.brand_etl,
    ROW_NUMBER() OVER (PARTITION BY t.crm_id,t.product_id,t.brand_etl ORDER BY t.first_date_payment ASC) AS rn
FROM prep_data t 
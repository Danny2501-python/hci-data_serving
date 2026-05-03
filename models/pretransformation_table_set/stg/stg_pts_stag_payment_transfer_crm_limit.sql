-- stag_payment_transfer_crm_limit
WITH crm_limit AS (
    SELECT 
        crm_id
        , payment_date
        , brand_etl
    FROM {{ source ('pre_tns','account_payment')}}
    WHERE GREATEST(payment_date,write_date) >= date_trunc('month', current_date - interval '1 month')::date
    UNION ALL
    SELECT 
        crm_id
        , payment_date
        , brand_etl
    FROM {{ source ('pre_tns','crm_transfer_payment')}}
    WHERE GREATEST(payment_date,write_date) >= date_trunc('month', current_date - interval '1 month')::date
)
SELECT 
    crm_id::int AS crm_id
    , MAX(payment_date)::date AS payment_date
    , brand_etl::int AS brand_etl
FROM crm_limit 
WHERE COALESCE(crm_id, 0) <> 0 AND brand_etl <> 0 GROUP BY crm_id, brand_etl
SELECT 
    crm_id,
    brand_etl,
    SUM(payment) AS total_payment
FROM 
    {{ source('bao_cao_sua_xoa_du_lieu', 'stag_payment_transfer') }}
GROUP BY
    crm_id,
    brand_etl
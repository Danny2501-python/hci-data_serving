SELECT spt.crm_id,
    spt.clineid,
    spt.ma_phieu,
    spt.payment,
    spt.payment_date,
    spt.brand_etl,
    row_number() OVER (PARTITION BY spt.crm_id, spt.clineid ORDER BY spt.payment_date) AS rnk
FROM {{ source('bao_cao_sua_xoa_du_lieu', 'stag_payment_transfer') }} spt
-- Bảng fix product_id cho all_payment và all_payment_transfer, Vá các product_id null hoặc lỗi
SELECT 
    spt.clineid, 
    spt.brand_id, 
    MAX(spt.product_id) AS product_id
FROM {{source('pre_tns','stag_payment_transfer')}} spt
WHERE GREATEST(spt.payment_date, spt.write_date) >= date_trunc('month', current_date - interval '1 month')::date
GROUP BY 
    spt.clineid, 
    spt.brand_id
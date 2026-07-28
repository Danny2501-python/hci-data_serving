select
        id,
        payment_date,
        payment,
        ma_phieu, --lấy mã phiếu nhưng code đang để vao_so
        company_id,
        brand_etl,
        brand_id,
        crm_id,
        clineid,
        product_id
 from {{source('thv','stag_payment_transfer')}} spt
 where brand_etl =8
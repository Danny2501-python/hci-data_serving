select
        payment_date as ngay_tt,
        payment AS doanh_so,
        ma_phieu AS vao_so, --lấy mã phiếu nhưng code đang để vao_so
        company_id,
        brand_etl,
        brand_id,
        crm_id,
        clineid,
        product_id
from {{source ('kso_crm_base','stag_payment_transfer')}} 
where payment_date >='2025-08-01' and brand_etl =1
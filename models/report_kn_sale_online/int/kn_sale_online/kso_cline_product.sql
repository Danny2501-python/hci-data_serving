select id as line_id,
        total_received as tong_tien,
        product_id,
        booking_id,
        brand_etl
from {{source('kso_crm_base','crm_line_product')}}
where brand_etl =1

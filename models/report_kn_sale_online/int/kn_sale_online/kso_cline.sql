select 
        ecl2.id AS line_id,
        ecl2.total_received AS tong_tien,
        ecl2.product_id,
        ecl2.crm_id,
        ecl2.brand_etl
from {{ source('kso_crm_base','crm_line') }} ecl2
where brand_etl =1
union all 
select id as line_id,
        total_received as tong_tien,
        product_id,
        booking_id,
        brand_etl
from {{source('kso_crm_base','crm_line_product')}}
where brand_etl =1

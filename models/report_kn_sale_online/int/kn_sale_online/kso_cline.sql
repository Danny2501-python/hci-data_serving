select 
        ecl2.id AS line_id,
        ecl2.total_received AS tong_tien,
        ecl2.product_id,
        ecl2.crm_id,
        ecl2.product_id
from {{ source('crm_base','crm_line') }} ecl
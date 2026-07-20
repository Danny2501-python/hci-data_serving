select
        ecl2.id,
        ecl2.total_received,
        ecl2.product_id,
        ecl2.crm_id,
        ecl2.brand_etl,
        ecl2.stage
from {{ source('data', 'crm_line') }} ecl2
where ecl2.brand_etl = 1

union all

select
        clp.id,
        clp.total_received,
        clp.product_id,
        clp.booking_id as crm_id,
        clp.brand_etl,
        clp.stage_line_product as stage
from {{ source('data', 'crm_line_product') }} clp
where clp.brand_etl = 1
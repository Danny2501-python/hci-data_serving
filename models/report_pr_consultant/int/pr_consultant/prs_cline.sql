select 
        cl.id clineid,
        cl.product_id,
        cl.stage,
        cl.reason_line_cancel,
        cl.cancel_user,
        cl.crm_id
from {{ source('prs_raw_data', 'crm_line') }} cl
where brand_etl=3
union all
select 
        cl.id clineid,
        cl.product_id,
        cl.stage_line_product,
        '' reason_line_cancel,
        null cancel_user,
        cl.booking_id
from {{ source('prs_raw_data', 'crm_line_product') }} cl
where brand_etl=3
